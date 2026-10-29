import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/sync/auth_service.dart';
import 'package:pockt/core/sync/pockt_powersync.dart';
import 'package:pockt/core/sync/supabase_connector.dart';
import 'package:powersync/powersync.dart' as ps;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Estados de sincronización posibles.
sealed class SyncState {
  const SyncState();

  const factory SyncState.off() = SyncOff;
  const factory SyncState.connecting() = SyncConnecting;
  const factory SyncState.synced({DateTime? lastSyncedAt}) = SyncSynced;
  const factory SyncState.uploading(int pending) = SyncUploading;
  const factory SyncState.offline(int pending) = SyncOffline;
  const factory SyncState.error(String message) = SyncError;
}

class SyncOff extends SyncState {
  const SyncOff();

  @override
  bool operator ==(Object other) => identical(this, other) || other is SyncOff;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'SyncState.off';
}

class SyncConnecting extends SyncState {
  const SyncConnecting();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SyncConnecting;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'SyncState.connecting';
}

class SyncSynced extends SyncState {
  final DateTime? lastSyncedAt;

  const SyncSynced({this.lastSyncedAt});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncSynced && other.lastSyncedAt == lastSyncedAt);

  @override
  int get hashCode => lastSyncedAt.hashCode;

  @override
  String toString() => 'SyncState.synced(lastSyncedAt: $lastSyncedAt)';
}

class SyncUploading extends SyncState {
  final int pending;

  const SyncUploading(this.pending);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncUploading && other.pending == pending);

  @override
  int get hashCode => pending.hashCode;

  @override
  String toString() => 'SyncState.uploading(pending: $pending)';
}

class SyncOffline extends SyncState {
  final int pending;

  const SyncOffline(this.pending);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOffline && other.pending == pending);

  @override
  int get hashCode => pending.hashCode;

  @override
  String toString() => 'SyncState.offline(pending: $pending)';
}

class SyncError extends SyncState {
  final String message;

  const SyncError(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SyncError && other.message == message);

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'SyncState.error(message: $message)';
}

/// Contrato para interactuar con la base de datos PowerSync en el controlador.
abstract interface class SyncDatabaseClient {
  Future<void> connect({required ps.PowerSyncBackendConnector connector});
  Future<void> disconnect();
  Stream<ps.SyncStatus> get statusStream;
  ps.SyncStatus get currentStatus;
  Stream<int> watchPendingCount();
}

/// Adaptador para una instancia de [PowerSyncDatabase].
class PowerSyncDatabaseClient implements SyncDatabaseClient {
  final ps.PowerSyncDatabase db;

  PowerSyncDatabaseClient(this.db);

  @override
  Future<void> connect({required ps.PowerSyncBackendConnector connector}) {
    return db.connect(connector: connector);
  }

  @override
  Future<void> disconnect() {
    return db.disconnect();
  }

  @override
  Stream<ps.SyncStatus> get statusStream => db.statusStream;

  @override
  ps.SyncStatus get currentStatus => db.currentStatus;

  @override
  Stream<int> watchPendingCount() {
    return db
        .watch('SELECT count(*) as count FROM ps_crud')
        .map((rs) => (rs.firstOrNull?['count'] as num?)?.toInt() ?? 0);
  }
}

/// Adaptador perezoso que resuelve [openPocktPowerSync] bajo demanda.
class LazyPowerSyncDatabaseClient implements SyncDatabaseClient {
  final Future<ps.PowerSyncDatabase> Function() _getDb;
  ps.PowerSyncDatabase? _resolvedDb;

  LazyPowerSyncDatabaseClient([Future<ps.PowerSyncDatabase> Function()? getDb])
      : _getDb = getDb ?? openPocktPowerSync;

  Future<ps.PowerSyncDatabase> _db() async {
    return _resolvedDb ??= await _getDb();
  }

  @override
  Future<void> connect({required ps.PowerSyncBackendConnector connector}) async {
    final db = await _db();
    await db.connect(connector: connector);
  }

  @override
  Future<void> disconnect() async {
    final db = await _db();
    await db.disconnect();
  }

  @override
  Stream<ps.SyncStatus> get statusStream async* {
    final db = await _db();
    yield db.currentStatus;
    yield* db.statusStream;
  }

  @override
  ps.SyncStatus get currentStatus {
    final db = _resolvedDb;
    if (db != null) {
      return db.currentStatus;
    }
    // ignore: invalid_use_of_internal_member
    return const ps.SyncStatus.uninitialized();
  }

  @override
  Stream<int> watchPendingCount() async* {
    final db = await _db();
    yield* db
        .watch('SELECT count(*) as count FROM ps_crud')
        .map((rs) => (rs.firstOrNull?['count'] as num?)?.toInt() ?? 0);
  }
}

/// Controlador central de sincronización.
class SyncController {
  final SyncDatabaseClient _database;
  final ps.PowerSyncBackendConnector? connector;
  final SettingsRepository settingsRepository;
  final AuthService authService;
  final String supabaseUrl;

  final _syncStateController = StreamController<SyncState>.broadcast();
  StreamSubscription<String?>? _settingsSub;
  StreamSubscription<Session?>? _authSub;
  StreamSubscription<ps.SyncStatus>? _statusSub;
  StreamSubscription<int>? _pendingSub;

  bool _isConnectingOrConnected = false;
  bool _syncEnabled = false;
  Session? _currentSession;
  ps.SyncStatus _lastStatus;
  int _lastPendingCount = 0;
  SyncState _currentState = const SyncState.off();

  SyncController({
    required SyncDatabaseClient database,
    this.connector,
    required this.settingsRepository,
    required this.authService,
    this.supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
  })  : _database = database,
        _lastStatus = database.currentStatus {
    _init();
  }

  /// Indica si la sincronización está disponible en la configuración actual.
  ///
  /// Requiere que SUPABASE_URL esté definido.
  bool get isSyncAvailable => supabaseUrl.isNotEmpty;

  /// Estado actual sincrónico.
  SyncState get currentSyncState => _currentState;

  /// Stream reactivo de cambios de estado.
  Stream<SyncState> get syncStateStream => _syncStateController.stream;

  void _init() {
    _currentSession = authService.currentSession;
    _statusSub = _database.statusStream.listen(_onStatusUpdate);
    _pendingSub = _database.watchPendingCount().listen(_onPendingUpdate);

    _settingsSub = settingsRepository.watch(SettingsKeys.syncEnabled).listen((val) {
      _syncEnabled = val == 'true';
      _reevaluateConnection();
    });

    _authSub = authService.authStateChanges.listen((session) {
      _currentSession = session;
      _reevaluateConnection();
    });

    settingsRepository.get(SettingsKeys.syncEnabled).then((val) {
      _syncEnabled = val == 'true';
      _reevaluateConnection();
    });
  }

  Future<void> _reevaluateConnection() async {
    final conn = connector;
    final shouldConnect = isSyncAvailable &&
        _syncEnabled &&
        _currentSession != null &&
        conn != null;

    if (shouldConnect) {
      if (!_isConnectingOrConnected) {
        _isConnectingOrConnected = true;
        try {
          await _database.connect(connector: conn);
        } catch (e) {
          debugPrint('Error al conectar PowerSync: $e');
        }
      }
    } else {
      if (_isConnectingOrConnected) {
        _isConnectingOrConnected = false;
        try {
          await _database.disconnect();
        } catch (e) {
          debugPrint('Error al desconectar PowerSync: $e');
        }
      }
      _emitState(const SyncState.off());
      return;
    }

    _calculateAndEmitState();
  }

  void _onStatusUpdate(ps.SyncStatus status) {
    _lastStatus = status;
    _calculateAndEmitState();
  }

  void _onPendingUpdate(int count) {
    _lastPendingCount = count;
    _calculateAndEmitState();
  }

  void _calculateAndEmitState() {
    if (!_isConnectingOrConnected || !isSyncAvailable || _currentSession == null || !_syncEnabled) {
      _emitState(const SyncState.off());
      return;
    }

    if (_lastStatus.connecting) {
      _emitState(const SyncState.connecting());
      return;
    }

    if (_lastStatus.connected) {
      if (_lastStatus.uploadError != null) {
        _emitState(SyncState.error(_lastStatus.uploadError.toString()));
        return;
      }
      if (_lastStatus.downloadError != null) {
        _emitState(SyncState.error(_lastStatus.downloadError.toString()));
        return;
      }
      if (_lastStatus.uploading || _lastPendingCount > 0) {
        _emitState(SyncState.uploading(_lastPendingCount));
      } else {
        _emitState(SyncState.synced(lastSyncedAt: _lastStatus.lastSyncedAt));
      }
      return;
    }

    // Desconectado pero activo (sin conexión): tranquilo aunque haya error de red
    _emitState(SyncState.offline(_lastPendingCount));
  }

  void _emitState(SyncState state) {
    if (_currentState != state) {
      _currentState = state;
      if (!_syncStateController.isClosed) {
        _syncStateController.add(state);
      }
    }
  }

  void dispose() {
    _settingsSub?.cancel();
    _authSub?.cancel();
    _statusSub?.cancel();
    _pendingSub?.cancel();
    _syncStateController.close();
  }
}

/// Provider de [SyncDatabaseClient].
final syncDatabaseClientProvider = Provider<SyncDatabaseClient>((ref) {
  return LazyPowerSyncDatabaseClient();
});

/// Provider de [SyncController].
final syncControllerProvider = Provider<SyncController>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final authService = ref.watch(authServiceProvider);
  final syncClient = ref.watch(syncDatabaseClientProvider);

  ps.PowerSyncBackendConnector? connector;
  if (const String.fromEnvironment('SUPABASE_URL').isNotEmpty) {
    try {
      final backend =
          PocktSupabaseBackend.fromSupabase(Supabase.instance.client);
      connector = PocktSupabaseConnector(backend: backend);
    } catch (_) {}
  }

  final controller = SyncController(
    database: syncClient,
    connector: connector,
    settingsRepository: settingsRepo,
    authService: authService,
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// Provider que expone el Stream de [SyncState].
final syncStateProvider = StreamProvider<SyncState>((ref) {
  final controller = ref.watch(syncControllerProvider);
  return controller.syncStateStream;
});
