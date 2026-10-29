import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/sync/auth_service.dart';
import 'package:pockt/core/sync/sync_controller.dart';
import 'package:pockt/features/settings/ui/settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuthService implements AuthService {
  Session? _session;
  final _sessionController = StreamController<Session?>.broadcast();
  bool signInThrows = false;
  bool signInCancelled = false;
  int signOutCallCount = 0;

  FakeAuthService([this._session]);

  void setSession(Session? session) {
    _session = session;
    _sessionController.add(session);
  }

  @override
  Session? get currentSession => _session;

  @override
  bool get isSignedIn => _session != null;

  @override
  bool get isConfigured => true;

  @override
  Stream<Session?> get authStateChanges => _sessionController.stream;

  @override
  Future<AuthResponse> signInWithGoogle() async {
    if (signInThrows) {
      throw Exception('Network error');
    }
    if (signInCancelled) {
      throw const AuthException('Inicio de sesión cancelado por el usuario.');
    }
    final session = Session(
      accessToken: 'test-token',
      tokenType: 'bearer',
      user: const User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-10-29T00:00:00Z',
        email: 'tu.cuenta@gmail.com',
      ),
    );
    setSession(session);
    return AuthResponse(session: session, user: session.user);
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    setSession(null);
  }

  void dispose() {
    _sessionController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeSyncController implements SyncController {
  @override
  bool isSyncAvailable;

  @override
  SyncState currentSyncState;

  final _stateController = StreamController<SyncState>.broadcast();
  int retryCallCount = 0;

  FakeSyncController({
    this.isSyncAvailable = true,
    this.currentSyncState = const SyncState.off(),
  });

  void emitState(SyncState state) {
    currentSyncState = state;
    _stateController.add(state);
  }

  void setSyncAvailable(bool available) {
    isSyncAvailable = available;
  }

  @override
  Stream<SyncState> get syncStateStream => _stateController.stream;

  @override
  Future<void> retry() async {
    retryCallCount++;
  }

  @override
  void dispose() {
    _stateController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late AppDatabase db;
  late SettingsRepository repo;
  late FakeAuthService fakeAuthService;
  late FakeSyncController fakeSyncController;

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    repo = SettingsRepository(db);
    fakeAuthService = FakeAuthService();
    fakeSyncController = FakeSyncController();
  });

  tearDown(() async {
    fakeAuthService.dispose();
    fakeSyncController.dispose();
    await db.close();
  });

  Widget buildTestApp({Widget? child}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWithValue(repo),
        authServiceProvider.overrideWithValue(fakeAuthService),
        syncControllerProvider.overrideWithValue(fakeSyncController),
        syncStateProvider.overrideWith((ref) => fakeSyncController.syncStateStream),
      ],
      child: MaterialApp(
        theme: buildDarkTheme(),
        home: child ?? const Scaffold(body: SettingsScreen()),
      ),
    );
  }

  Future<void> openPrivacySection(WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final privacyEntry = find.byKey(const ValueKey('settings-section-privacy'));
    expect(privacyEntry, findsOneWidget);
    await tester.tap(privacyEntry);
    await tester.pumpAndSettle();
  }

  group('Tarea 2.6: Sincronizar con la web UI', () {
    testWidgets('1. Si isSyncAvailable es false, la fila no se muestra', (tester) async {
      fakeSyncController.setSyncAvailable(false);

      await openPrivacySection(tester);
      expect(find.text('Sincronizar con la web'), findsNothing);
    });

    testWidgets('2. Apagado: muestra título, subtítulo e interruptor apagado', (tester) async {
      await openPrivacySection(tester);

      expect(find.text('Sincronizar con la web'), findsOneWidget);
      expect(find.text('Ver y editar tus datos desde la compu'), findsOneWidget);

      final switchFinder = find.byKey(const ValueKey('settings-sync-switch'));
      expect(switchFinder, findsOneWidget);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isFalse);
    });

    testWidgets('3. Encender sin sesión abre hoja inferior "Tus datos en la web"', (tester) async {
      await openPrivacySection(tester);

      final switchFinder = find.byKey(const ValueKey('settings-sync-switch'));
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.text('Tus datos en la web'), findsOneWidget);
      expect(
        find.text(
          'Entrá con Google para ver, cargar y editar movimientos desde la compu. Los cambios se ven al instante en los dos lados.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Solo vos ves tus datos. Se guardan en tu cuenta privada en la nube y también siguen en este teléfono.',
        ),
        findsOneWidget,
      );
      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(find.text('Ahora no'), findsOneWidget);
    });

    testWidgets('4. Tocar "Ahora no" cierra la hoja y deja el interruptor apagado', (tester) async {
      await openPrivacySection(tester);

      await tester.tap(find.byKey(const ValueKey('settings-sync-switch')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();

      expect(find.text('Tus datos en la web'), findsNothing);
      final switchWidget = tester.widget<Switch>(find.byKey(const ValueKey('settings-sync-switch')));
      expect(switchWidget.value, isFalse);
      expect(await repo.get(SettingsKeys.syncEnabled), isNot('true'));
    });

    testWidgets('5. Continuar con Google exitoso guarda syncEnabled=true y cierra la hoja', (tester) async {
      await openPrivacySection(tester);

      await tester.tap(find.byKey(const ValueKey('settings-sync-switch')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(find.text('Tus datos en la web'), findsNothing);
      expect(await repo.get(SettingsKeys.syncEnabled), equals('true'));
    });

    testWidgets('6. Error o cancelación con Google muestra aviso SnackBar y deja apagado', (tester) async {
      fakeAuthService.signInCancelled = true;

      await openPrivacySection(tester);

      await tester.tap(find.byKey(const ValueKey('settings-sync-switch')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(find.text('Tus datos en la web'), findsNothing);
      expect(await repo.get(SettingsKeys.syncEnabled), isNot('true'));
      expect(find.text('Inicio de sesión cancelado'), findsOneWidget);
    });

    testWidgets('7. Encender con sesión ya iniciada guarda true directo sin hoja', (tester) async {
      fakeAuthService.setSession(
        Session(
          accessToken: 'tok',
          tokenType: 'bearer',
          user: const User(
            id: 'uid',
            appMetadata: {},
            userMetadata: {},
            aud: 'aud',
            createdAt: '2026-10-29',
            email: 'user@example.com',
          ),
        ),
      );

      await openPrivacySection(tester);

      await tester.tap(find.byKey(const ValueKey('settings-sync-switch')));
      await tester.pumpAndSettle();

      expect(find.text('Tus datos en la web'), findsNothing);
      expect(await repo.get(SettingsKeys.syncEnabled), equals('true'));
    });

    testWidgets('8. Apagar el interruptor con sesión guarda false y conserva la sesión', (tester) async {
      fakeAuthService.setSession(
        Session(
          accessToken: 'tok',
          tokenType: 'bearer',
          user: const User(
            id: 'uid',
            appMetadata: {},
            userMetadata: {},
            aud: 'aud',
            createdAt: '2026-10-29',
            email: 'user@example.com',
          ),
        ),
      );
      await repo.set(SettingsKeys.syncEnabled, 'true');

      await openPrivacySection(tester);

      final switchFinder = find.byKey(const ValueKey('settings-sync-switch'));
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(await repo.get(SettingsKeys.syncEnabled), equals('false'));
      expect(fakeAuthService.currentSession, isNotNull);
    });

    testWidgets('9. Estados de sincronización: connecting, uploading, synced, offline, error', (tester) async {
      fakeAuthService.setSession(
        Session(
          accessToken: 'tok',
          tokenType: 'bearer',
          user: const User(
            id: 'uid',
            appMetadata: {},
            userMetadata: {},
            aud: 'aud',
            createdAt: '2026-10-29',
            email: 'tu.cuenta@gmail.com',
          ),
        ),
      );
      await repo.set(SettingsKeys.syncEnabled, 'true');

      await openPrivacySection(tester);

      // Subtítulo muestra el correo del usuario
      expect(find.text('tu.cuenta@gmail.com'), findsOneWidget);

      // Estado connecting
      fakeSyncController.emitState(const SyncState.connecting());
      await tester.pumpAndSettle();
      expect(find.text('Conectando…'), findsOneWidget);

      // Estado uploading
      fakeSyncController.emitState(const SyncState.uploading(380)); // suponiendo total 1000 => 620 de 1.000
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Estado synced
      final now = DateTime.now().toUtc();
      fakeSyncController.emitState(SyncState.synced(lastSyncedAt: now));
      await tester.pumpAndSettle();
      expect(find.text('Sincronizado · hace 1 s'), findsOneWidget);

      // Estado offline con pendientes
      fakeSyncController.emitState(const SyncState.offline(3));
      await tester.pumpAndSettle();
      expect(find.text('Sin conexión · 3 cambios esperando'), findsOneWidget);
      expect(find.text('Se suben solos cuando vuelva la señal.'), findsOneWidget);

      // Estado offline sin pendientes (n=0)
      fakeSyncController.emitState(const SyncState.offline(0));
      await tester.pumpAndSettle();
      expect(find.text('Sin conexión'), findsOneWidget);

      // Estado error
      fakeSyncController.emitState(const SyncState.error('Falla de conexión en el servidor'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo sincronizar'), findsOneWidget);
      expect(find.text('Ver detalle'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('10. Botón Reintentar llama a SyncController.retry()', (tester) async {
      fakeAuthService.setSession(
        Session(
          accessToken: 'tok',
          tokenType: 'bearer',
          user: const User(
            id: 'uid',
            appMetadata: {},
            userMetadata: {},
            aud: 'aud',
            createdAt: '2026-10-29',
            email: 'tu.cuenta@gmail.com',
          ),
        ),
      );
      await repo.set(SettingsKeys.syncEnabled, 'true');

      await openPrivacySection(tester);
      fakeSyncController.emitState(const SyncState.error('Falla 500'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(fakeSyncController.retryCallCount, equals(1));
    });

    testWidgets('11. Botón Ver detalle muestra hoja con mensaje de error', (tester) async {
      fakeAuthService.setSession(
        Session(
          accessToken: 'tok',
          tokenType: 'bearer',
          user: const User(
            id: 'uid',
            appMetadata: {},
            userMetadata: {},
            aud: 'aud',
            createdAt: '2026-10-29',
            email: 'tu.cuenta@gmail.com',
          ),
        ),
      );
      await repo.set(SettingsKeys.syncEnabled, 'true');

      await openPrivacySection(tester);
      fakeSyncController.emitState(const SyncState.error('Error detallado de timeout'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver detalle'));
      await tester.pumpAndSettle();

      expect(find.text('Detalle del error'), findsOneWidget);
      expect(find.text('Error detallado de timeout'), findsOneWidget);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle del error'), findsNothing);
    });

    testWidgets('12. Cerrar sesión pide confirmación y al confirmar llama signOut y guarda false', (tester) async {
      fakeAuthService.setSession(
        Session(
          accessToken: 'tok',
          tokenType: 'bearer',
          user: const User(
            id: 'uid',
            appMetadata: {},
            userMetadata: {},
            aud: 'aud',
            createdAt: '2026-10-29',
            email: 'tu.cuenta@gmail.com',
          ),
        ),
      );
      await repo.set(SettingsKeys.syncEnabled, 'true');

      await openPrivacySection(tester);
      fakeSyncController.emitState(const SyncState.synced());
      await tester.pumpAndSettle();

      final signOutBtn = find.text('Cerrar sesión');
      expect(signOutBtn, findsOneWidget);

      await tester.tap(signOutBtn);
      await tester.pumpAndSettle();

      expect(find.text('¿Cerrar sesión?'), findsOneWidget);
      expect(
        find.text('Dejás de sincronizar con la web. Tus datos siguen en este teléfono.'),
        findsOneWidget,
      );

      // Cancelar no cierra sesión
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(fakeAuthService.signOutCallCount, equals(0));

      // Abrir de nuevo y confirmar
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      // En la hoja hay un botón rojo "Cerrar sesión"
      final confirmBtn = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Cerrar sesión'),
      );
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(fakeAuthService.signOutCallCount, equals(1));
      expect(await repo.get(SettingsKeys.syncEnabled), equals('false'));
    });
  });
}
