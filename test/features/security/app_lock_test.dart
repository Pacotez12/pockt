import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/security/app_lock.dart';
import 'package:pockt/features/settings/ui/settings_screen.dart';

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  late AppDatabase db;
  late SettingsRepository settings;
  late MockLocalAuthentication mockAuth;
  late DateTime currentTime;
  late List<bool> secureFlagCalls;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    currentTime = DateTime(2026, 10, 10, 12, 0, 0);
    secureFlagCalls = [];
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    settings = SettingsRepository(db);
    mockAuth = MockLocalAuthentication();

    when(() => mockAuth.isDeviceSupported()).thenAnswer((_) async => true);
    when(() => mockAuth.canCheckBiometrics).thenAnswer((_) async => true);
    when(() => mockAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
        )).thenAnswer((_) async => true);
  });

  tearDown(() async {
    await db.close();
  });

  AppLockController createController({
    bool lockActiveInSettings = false,
  }) {
    if (lockActiveInSettings) {
      settings.set(SettingsKeys.securityLock, 'on');
    }
    return AppLockController(
      auth: mockAuth,
      settings: settings,
      clock: () => currentTime,
      onSecurityChanged: (enabled) async {
        secureFlagCalls.add(enabled);
      },
    );
  }

  group('AppLockController unit tests', () {
    test('con bloqueo activo, arrancar muestra la pantalla de bloqueo y activa FLAG_SECURE', () async {
      final controller = createController(lockActiveInSettings: true);
      await controller.init();

      expect(controller.locked, isTrue);
      expect(controller.isLockEnabled, isTrue);
      expect(secureFlagCalls, contains(true));
    });

    test('sin bloqueo activo, arrancar no bloquea', () async {
      final controller = createController(lockActiveInSettings: false);
      await controller.init();

      expect(controller.locked, isFalse);
      expect(controller.isLockEnabled, isFalse);
    });

    test('unlock exitoso cambia locked a false', () async {
      when(() => mockAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            biometricOnly: any(named: 'biometricOnly'),
          )).thenAnswer((_) async => true);

      final controller = createController(lockActiveInSettings: true);
      await controller.init();
      expect(controller.locked, isTrue);

      final result = await controller.unlock();
      expect(result, isTrue);
      expect(controller.locked, isFalse);
    });

    test('unlock cancelado mantiene locked en true', () async {
      when(() => mockAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            biometricOnly: any(named: 'biometricOnly'),
          )).thenAnswer((_) async => false);

      final controller = createController(lockActiveInSettings: true);
      await controller.init();
      expect(controller.locked, isTrue);

      final result = await controller.unlock();
      expect(result, isFalse);
      expect(controller.locked, isTrue);
    });

    test('volver a los 30 s no bloquea, a los 61 s sí', () async {
      final controller = createController(lockActiveInSettings: true);
      await controller.init();
      await controller.unlock();
      expect(controller.locked, isFalse);

      // Pasa a segundo plano
      controller.onPaused();

      // Vuelve a los 30 segundos
      currentTime = currentTime.add(const Duration(seconds: 30));
      controller.onResumed();
      expect(controller.locked, isFalse);

      // Pasa a segundo plano de nuevo
      controller.onPaused();

      // Vuelve a los 61 segundos (>= 1 min)
      currentTime = currentTime.add(const Duration(seconds: 61));
      controller.onResumed();
      expect(controller.locked, isTrue);
    });

    test('availability devuelve ready cuando hay soporte y bloqueo configurado', () async {
      when(() => mockAuth.isDeviceSupported()).thenAnswer((_) async => true);
      when(() => mockAuth.canCheckBiometrics).thenAnswer((_) async => true);

      final controller = createController();
      final status = await controller.availability();
      expect(status, equals(AppLockAvailability.ready));
    });

    test('availability devuelve noDeviceLock cuando tiene hardware pero no bloqueo configurado', () async {
      when(() => mockAuth.isDeviceSupported()).thenAnswer((_) async => false);
      when(() => mockAuth.canCheckBiometrics).thenAnswer((_) async => true);

      final controller = createController();
      final status = await controller.availability();
      expect(status, equals(AppLockAvailability.noDeviceLock));
    });

    test('availability devuelve unsupported cuando no soporta biometría ni bloqueo', () async {
      when(() => mockAuth.isDeviceSupported()).thenAnswer((_) async => false);
      when(() => mockAuth.canCheckBiometrics).thenAnswer((_) async => false);

      final controller = createController();
      final status = await controller.availability();
      expect(status, equals(AppLockAvailability.unsupported));
    });
  });

  group('AppLockGate & UI tests', () {
    testWidgets('con bloqueo activo muestra pantalla de bloqueo con orbe, logotipo y botón Desbloquear', (tester) async {
      final controller = createController(lockActiveInSettings: true);
      await controller.init();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLockControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(
            home: AppLockGate(
              child: Scaffold(
                body: Text('Contenido Principal'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('pockt'), findsOneWidget);
      expect(find.text('Desbloquear'), findsOneWidget);
      expect(find.text('Contenido Principal'), findsNothing);

      // Tocar Desbloquear
      await tester.tap(find.text('Desbloquear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Contenido Principal'), findsOneWidget);
    });

    testWidgets('en Ajustes: sin bloqueo de dispositivo, el interruptor queda deshabilitado con explicación', (tester) async {
      when(() => mockAuth.isDeviceSupported()).thenAnswer((_) async => false);
      when(() => mockAuth.canCheckBiometrics).thenAnswer((_) async => true);

      final controller = createController(lockActiveInSettings: false);
      await controller.init();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            settingsRepositoryProvider.overrideWithValue(settings),
            appLockControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Bloqueo con huella'), findsOneWidget);
      expect(
        find.textContaining('bloqueo configurado'),
        findsOneWidget,
      );

      final switchWidget = tester.widget<Switch>(find.byKey(const ValueKey('settings-lock-switch')));
      expect(switchWidget.onChanged, isNull);
    });
  });
}
