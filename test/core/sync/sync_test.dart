import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/sync/auth_service.dart';
import 'package:pockt/core/sync/sync_controller.dart';
import 'package:pockt/core/sync/sync_owner.dart';
import 'package:powersync/powersync.dart' as ps;
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Fakes y Mocks para pruebas sin red ---

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class FakeGoogleSignInDelegate implements GoogleSignInDelegate {
  String? initializedServerClientId;
  String? initializedNonce;
  bool authenticateCalled = false;
  bool signOutCalled = false;
  GoogleSignInAccountData? accountToReturn;

  @override
  Future<void> initialize({required String serverClientId, String? nonce}) async {
    initializedServerClientId = serverClientId;
    initializedNonce = nonce;
  }

  @override
  Future<GoogleSignInAccountData?> authenticate() async {
    authenticateCalled = true;
    return accountToReturn;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

// ignore: invalid_use_of_internal_member
ps.SyncStatus makeSyncStatus({
  bool connected = false,
  bool connecting = false,
  bool downloading = false,
  bool uploading = false,
  DateTime? lastSyncedAt,
  Object? downloadError,
  Object? uploadError,
}) {
  // ignore: invalid_use_of_internal_member
  return ps.SyncStatus(
    connected: connected,
    connecting: connecting,
    downloading: downloading,
    uploading: uploading,
    lastSyncedAt: lastSyncedAt,
    downloadProgress: null,
    downloadError: downloadError,
    uploadError: uploadError,
    priorityStatusEntries: const [],
    streamSubscriptions: null,
    lastAppliedCheckpoint: null,
  );
}

class FakeSyncDatabaseClient implements SyncDatabaseClient {
  bool connectCalled = false;
  bool disconnectCalled = false;
  int connectCallCount = 0;
  int disconnectCallCount = 0;
  ps.PowerSyncBackendConnector? lastConnector;

  final statusController = StreamController<ps.SyncStatus>.broadcast();
  final pendingCountController = StreamController<int>.broadcast();

  ps.SyncStatus _currentStatus = makeSyncStatus();

  @override
  ps.SyncStatus get currentStatus => _currentStatus;

  void emitStatus(ps.SyncStatus status) {
    _currentStatus = status;
    statusController.add(status);
  }

  void emitPendingCount(int count) {
    pendingCountController.add(count);
  }

  @override
  Future<void> connect({required ps.PowerSyncBackendConnector connector}) async {
    connectCallCount++;
    connectCalled = true;
    disconnectCalled = false;
    lastConnector = connector;
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
    disconnectCalled = true;
    connectCalled = false;
  }

  @override
  Stream<ps.SyncStatus> get statusStream => statusController.stream;

  @override
  Stream<int> watchPendingCount() => pendingCountController.stream;

  String? ownerUserId;
  String? legacyOwnerUserId;
  Object? resolveError;
  Completer<void>? resolveCompleter;
  String? pauseOnUserId;

  @override
  Future<String?> getSyncOwner() async => ownerUserId;

  @override
  Future<void> setSyncOwner(String userId) async {
    ownerUserId = userId;
  }

  @override
  Future<String> resolveOrMigrateSyncOwner(String currentUserId) async {
    final err = resolveError;
    if (err != null) throw err;
    if (pauseOnUserId == null || pauseOnUserId == currentUserId) {
      final comp = resolveCompleter;
      if (comp != null) {
        await comp.future;
      }
    }
    if (ownerUserId != null) {
      if (ownerUserId != currentUserId) {
        throw CrossAccountSyncException(
          message: 'Base vinculada a otro usuario',
          expectedUserId: ownerUserId!,
          actualUserId: currentUserId,
        );
      }
      return ownerUserId!;
    }
    if (legacyOwnerUserId != null) {
      if (legacyOwnerUserId != currentUserId) {
        throw CrossAccountSyncException(
          message: 'Base legacy vinculada a otro usuario',
          expectedUserId: legacyOwnerUserId!,
          actualUserId: currentUserId,
        );
      }
      ownerUserId = currentUserId;
      legacyOwnerUserId = null;
      return currentUserId;
    }
    ownerUserId = currentUserId;
    return currentUserId;
  }

  void dispose() {
    statusController.close();
    pendingCountController.close();
  }
}

class FakeBackendConnector extends ps.PowerSyncBackendConnector {
  @override
  Future<ps.PowerSyncCredentials?> fetchCredentials() async => null;

  @override
  Future<void> uploadData(ps.PowerSyncDatabase database) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SettingsRepository settingsRepo;
  late FakeSyncDatabaseClient fakeSyncDb;
  late FakeBackendConnector fakeConnector;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late FakeGoogleSignInDelegate fakeGoogleSignIn;
  late StreamController<AuthState> authStateController;

  final testUser = User(
    id: 'user-123',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  );

  final testSession = Session(
    accessToken: 'test-access-token',
    tokenType: 'bearer',
    user: testUser,
  );

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    settingsRepo = SettingsRepository(db);
    fakeSyncDb = FakeSyncDatabaseClient();
    fakeConnector = FakeBackendConnector();

    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    fakeGoogleSignIn = FakeGoogleSignInDelegate();
    authStateController = StreamController<AuthState>.broadcast();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.onAuthStateChange).thenAnswer((_) => authStateController.stream);
    when(() => mockAuth.currentSession).thenReturn(null);
  });

  tearDown(() async {
    await db.close();
    fakeSyncDb.dispose();
    await authStateController.close();
  });

  group('Tarea 2.5: AuthService', () {
    test('signInWithGoogle passes hashed nonce to Google and raw nonce to Supabase', () async {
      when(() => mockAuth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: any(named: 'idToken'),
            accessToken: any(named: 'accessToken'),
            nonce: any(named: 'nonce'),
          )).thenAnswer((_) async => AuthResponse(session: testSession, user: testUser));

      fakeGoogleSignIn.accountToReturn = const GoogleSignInAccountData(
        idToken: 'google-id-token',
        accessToken: null,
      );

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
        webClientId: 'test-web-client-id.apps.googleusercontent.com',
      );

      final response = await authService.signInWithGoogle();

      expect(fakeGoogleSignIn.initializedServerClientId, 'test-web-client-id.apps.googleusercontent.com');
      expect(response.session, equals(testSession));

      final capturedNonce = verify(() => mockAuth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: 'google-id-token',
            accessToken: any(named: 'accessToken'),
            nonce: captureAny(named: 'nonce'),
          )).captured.single as String;

      expect(capturedNonce.isNotEmpty, isTrue);
      final expectedHashedNonce = sha256.convert(utf8.encode(capturedNonce)).toString();
      expect(fakeGoogleSignIn.initializedNonce, equals(expectedHashedNonce));
    });

    test('signOut cierra sesión en Supabase y en Google', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
        webClientId: 'test-client-id',
      );

      await authService.signOut();

      verify(() => mockAuth.signOut()).called(1);
      expect(fakeGoogleSignIn.signOutCalled, isTrue);
    });
  });

  group('Tarea 2.5: SyncController', () {
    test('1) sin sesión no conecta', () async {
      when(() => mockAuth.currentSession).thenReturn(null);
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      final controller = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: 'https://test.supabase.co',
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fakeSyncDb.connectCalled, isFalse);
      expect(controller.currentSyncState, equals(const SyncState.off()));
    });

    test('2) con sesión y sync.enabled conecta', () async {
      when(() => mockAuth.currentSession).thenReturn(testSession);
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      final controller = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: 'https://test.supabase.co',
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fakeSyncDb.connectCalled, isTrue);
      expect(fakeSyncDb.lastConnector, equals(fakeConnector));
    });

    test('3) apagar desconecta', () async {
      when(() => mockAuth.currentSession).thenReturn(testSession);
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      final controller = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: 'https://test.supabase.co',
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fakeSyncDb.connectCalled, isTrue);

      // Apagar interruptor de sincronización
      await settingsRepo.set(SettingsKeys.syncEnabled, 'false');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fakeSyncDb.disconnectCalled, isTrue);
      expect(controller.currentSyncState, equals(const SyncState.off()));
    });

    test('4) cerrar sesión desconecta y conserva datos locales', () async {
      when(() => mockAuth.currentSession).thenReturn(testSession);
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      // Insertar movimiento local en la base antes de cerrar sesión
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-local-1',
              type: TxType.expense,
              amount: 50000,
              currency: const Value('PYG'),
              categoryId: 'cat-1',
              occurredAt: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              source: TxSource.manual,
            ),
          );

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      final controller = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: 'https://test.supabase.co',
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fakeSyncDb.connectCalled, isTrue);

      // Simular cierre de sesión
      when(() => mockAuth.currentSession).thenReturn(null);
      authStateController.add(const AuthState(AuthChangeEvent.signedOut, null));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fakeSyncDb.disconnectCalled, isTrue);
      expect(controller.currentSyncState, equals(const SyncState.off()));

      // Verificar que los datos locales siguen intactos
      final remainingTx = await (db.select(db.transactions)..where((t) => t.id.equals('tx-local-1'))).getSingleOrNull();
      expect(remainingTx, isNotNull);
      expect(remainingTx!.amount, equals(50000));
    });

    test('5) sin SUPABASE_URL la sync queda no disponible', () async {
      when(() => mockAuth.currentSession).thenReturn(testSession);
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      final controller = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: '', // URL vacía
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fakeSyncDb.connectCalled, isFalse);
      expect(controller.currentSyncState, equals(const SyncState.off()));
    });

    test('6) Demo sin URL explícita nunca conecta (y con URL sí conecta)', () async {
      when(() => mockAuth.currentSession).thenReturn(testSession);
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      // Demo con URL vacía
      final demoControllerNoUrl = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: '',
      );
      addTearDown(demoControllerNoUrl.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fakeSyncDb.connectCalled, isFalse);
      expect(demoControllerNoUrl.currentSyncState, equals(const SyncState.off()));

      // Demo con URL explícita (backend local)
      final demoControllerWithUrl = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: 'http://localhost:54321',
      );
      addTearDown(demoControllerWithUrl.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fakeSyncDb.connectCalled, isTrue);
    });

    test('7) los estados de SyncState se emiten en orden ante cambios simulados de la cola', () async {
      when(() => mockAuth.currentSession).thenReturn(testSession);
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      final controller = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: 'https://test.supabase.co',
      );
      addTearDown(controller.dispose);

      final emittedStates = <SyncState>[];
      final sub = controller.syncStateStream.listen(emittedStates.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 1. Conectando
      fakeSyncDb.emitStatus(makeSyncStatus(connecting: true));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 2. Sincronizado (conectado, sin pendientes)
      final now = DateTime.utc(2026, 10, 29, 15, 0);
      fakeSyncDb.emitPendingCount(0);
      fakeSyncDb.emitStatus(makeSyncStatus(
        connected: true,
        lastSyncedAt: now,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 3. Subiendo (hay 3 cambios en cola)
      fakeSyncDb.emitPendingCount(3);
      fakeSyncDb.emitStatus(makeSyncStatus(
        connected: true,
        uploading: true,
        lastSyncedAt: now,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 4. Cola completada, vuelve a sincronizado
      final nextSyncedAt = DateTime.utc(2026, 10, 29, 15, 5);
      fakeSyncDb.emitPendingCount(0);
      fakeSyncDb.emitStatus(makeSyncStatus(
        connected: true,
        lastSyncedAt: nextSyncedAt,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 5. Sin conexión (offline con 2 pendientes)
      fakeSyncDb.emitPendingCount(2);
      fakeSyncDb.emitStatus(makeSyncStatus(
        connected: false,
        lastSyncedAt: nextSyncedAt,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 6. Error de sincronización (estando conectado)
      fakeSyncDb.emitStatus(makeSyncStatus(
        connected: true,
        downloadError: 'Conexión rechazada por el servidor',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(emittedStates, containsAllInOrder([
        const SyncState.connecting(),
        SyncState.synced(lastSyncedAt: now),
        const SyncState.uploading(3),
        SyncState.synced(lastSyncedAt: nextSyncedAt),
        const SyncState.offline(2),
        const SyncState.error('Conexión rechazada por el servidor'),
      ]));
    });

    test('8) si no está conectado, emite offline(pending) aunque haya downloadError o uploadError', () async {
      when(() => mockAuth.currentSession).thenReturn(testSession);
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      final controller = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: 'https://test.supabase.co',
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      fakeSyncDb.emitPendingCount(3);
      fakeSyncDb.emitStatus(makeSyncStatus(
        connected: false,
        connecting: false,
        downloadError: 'SocketException: Failed host lookup',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.currentSyncState, equals(const SyncState.offline(3)));

      fakeSyncDb.emitStatus(makeSyncStatus(
        connected: false,
        connecting: false,
        uploadError: 'SocketException: Network is unreachable',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.currentSyncState, equals(const SyncState.offline(3)));
    });

    test('9) emite error solo cuando está conectado y hay uploadError o downloadError', () async {
      when(() => mockAuth.currentSession).thenReturn(testSession);
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      final controller = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: 'https://test.supabase.co',
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Conectado con downloadError
      fakeSyncDb.emitStatus(makeSyncStatus(
        connected: true,
        downloadError: 'HTTP 500 Internal Server Error',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        controller.currentSyncState,
        equals(const SyncState.error('HTTP 500 Internal Server Error')),
      );

      // Conectado con uploadError
      fakeSyncDb.emitStatus(makeSyncStatus(
        connected: true,
        uploadError: 'Validation failed on server',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        controller.currentSyncState,
        equals(const SyncState.error('Validation failed on server')),
      );
    });

    test('10) retry() desconecta y vuelve a conectar si corresponde', () async {
      when(() => mockAuth.currentSession).thenReturn(testSession);
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      final controller = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: 'https://test.supabase.co',
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fakeSyncDb.connectCalled, isTrue);

      final disconnectsBefore = fakeSyncDb.disconnectCallCount;
      final connectsBefore = fakeSyncDb.connectCallCount;

      await controller.retry();

      expect(fakeSyncDb.disconnectCallCount, equals(disconnectsBefore + 1));
      expect(fakeSyncDb.connectCallCount, equals(connectsBefore + 1));
    });

    test('11) protección conservadora: cambio a otro usuario impide conectar y emite error', () async {
      // Simular que la base ya estaba vinculada localmente a user-123
      fakeSyncDb.ownerUserId = 'user-123';
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      // Nueva sesión con otro usuario diferente
      final otherUser = User(
        id: 'attacker-or-other-user-456',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      final otherSession = Session(
        accessToken: 'other-token',
        tokenType: 'bearer',
        user: otherUser,
      );

      when(() => mockAuth.currentSession).thenReturn(otherSession);

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      final controller = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: 'https://test.supabase.co',
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // No debe conectar con la cuenta del otro usuario y debe reportar error
      expect(fakeSyncDb.connectCalled, isFalse);
      expect(controller.currentSyncState, isA<SyncError>());
    });

    test('12) flujo normal de primera cuenta local vincula la base y conecta exitosamente', () async {
      fakeSyncDb.ownerUserId = null;
      fakeSyncDb.legacyOwnerUserId = null;
      when(() => mockAuth.currentSession).thenReturn(testSession);
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      final controller = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: 'https://test.supabase.co',
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fakeSyncDb.connectCalled, isTrue);
      expect(fakeSyncDb.ownerUserId, equals('user-123'));
    });

    test('13) instalación legacy (c0ffd70): owner local vacío con sync.userId previo; cuenta distinta bloquea conexión', () async {
      // Base legacy configurada para user-legacy-999, owner local nuevo vacío
      fakeSyncDb.ownerUserId = null;
      fakeSyncDb.legacyOwnerUserId = 'user-legacy-999';
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      // Sesión activa con cuenta distinta
      when(() => mockAuth.currentSession).thenReturn(testSession); // user-123

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      final controller = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: 'https://test.supabase.co',
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // No debe enlazar ni conectar con user-123
      expect(fakeSyncDb.connectCalled, isFalse);
      expect(fakeSyncDb.ownerUserId, isNull);
      expect(controller.currentSyncState, isA<SyncError>());
    });

    test('14) instalación legacy (c0ffd70): owner local vacío con sync.userId coincidente; migra y conecta exitosamente', () async {
      // Base legacy configurada para user-123, owner local nuevo vacío
      fakeSyncDb.ownerUserId = null;
      fakeSyncDb.legacyOwnerUserId = 'user-123';
      when(() => mockAuth.currentSession).thenReturn(testSession); // user-123
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      final controller = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: 'https://test.supabase.co',
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fakeSyncDb.connectCalled, isTrue);
      expect(fakeSyncDb.ownerUserId, equals('user-123'));
      expect(fakeSyncDb.legacyOwnerUserId, isNull);
    });

    test('15) error al resolver/migrar propietario falla cerrado, no conecta y emite error', () async {
      fakeSyncDb.resolveError = const FormatException('Error de base corrupta');
      when(() => mockAuth.currentSession).thenReturn(testSession);
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      final controller = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: 'https://test.supabase.co',
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fakeSyncDb.connectCalled, isFalse);
      expect(fakeSyncDb.ownerUserId, isNull);
      expect(controller.currentSyncState, isA<SyncError>());
    });

    test('16) carrera al reevaluar: si cambia la cuenta mientras espera resolveOrMigrateSyncOwner, la ejecución obsoleta no conecta con sesión desactualizada', () async {
      final user1Completer = Completer<void>();
      fakeSyncDb.resolveCompleter = user1Completer;
      fakeSyncDb.pauseOnUserId = 'user-123';
      fakeSyncDb.ownerUserId = 'user-123';

      when(() => mockAuth.currentSession).thenReturn(testSession); // user-123
      await settingsRepo.set(SettingsKeys.syncEnabled, 'true');

      final authService = AuthService(
        client: mockSupabase,
        googleSignIn: fakeGoogleSignIn,
      );

      final controller = SyncController(
        database: fakeSyncDb,
        connector: fakeConnector,
        settingsRepository: settingsRepo,
        authService: authService,
        supabaseUrl: 'https://test.supabase.co',
      );
      addTearDown(controller.dispose);

      // Esperar a que la primera reevaluación empiece y se pause en resolveOrMigrateSyncOwner
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(fakeSyncDb.connectCalled, isFalse);

      // Cambiar de cuenta a user-other mientras la resolución de user-123 está en vuelo
      final otherUser = User(
        id: 'user-other',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      final otherSession = Session(
        accessToken: 'other-token',
        tokenType: 'bearer',
        user: otherUser,
      );

      when(() => mockAuth.currentSession).thenReturn(otherSession);
      authStateController.add(AuthState(AuthChangeEvent.signedIn, otherSession));

      // Esperar brevemente a que el stream de auth procese y genere una nueva generación
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Ahora permitir que la resolución demorada de user-123 continúe
      user1Completer.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // La ejecución de user-123 quedó invalidada por cambio de generación/sesión
      // Y la de user-other no se conectó porque la base es de user-123
      expect(fakeSyncDb.connectCalled, isFalse);
      expect(controller.currentSyncState, isA<SyncError>());
    });
  });
}
