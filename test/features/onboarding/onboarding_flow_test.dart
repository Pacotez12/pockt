import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/app.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/backup/data/backup_store.dart';
import 'package:pockt/features/backup/data/key_storage.dart';
import 'package:pockt/features/backup/domain/backup_service.dart';
import 'package:pockt/features/onboarding/domain/onboarding_check.dart';
import 'package:pockt/features/onboarding/ui/onboarding_flow.dart';
import 'package:pockt/features/shell/ui/app_shell.dart';
import 'package:pockt/features/splash/ui/pockt_splash.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  late AppDatabase db;
  late SettingsRepository settingsRepo;
  late FakeNotifier fakeNotifier;

  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() async {
    setLocalZone('America/Asuncion');
    PocktSplash.resetForTesting();
    fakeNotifier = FakeNotifier();
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    settingsRepo = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('checkShouldShowOnboarding rules (Plan 4 Task 7)', () {
    test(
      'base limpia sin datos, sin demo, sin onboarding.done -> devuelve true',
      () async {
        final shouldShow = await checkShouldShowOnboarding(
          db: db,
          settings: settingsRepo,
          isDemo: false,
        );
        expect(shouldShow, isTrue);
      },
    );

    test('si corre en modo demo (isDemo: true) -> devuelve false', () async {
      final shouldShow = await checkShouldShowOnboarding(
        db: db,
        settings: settingsRepo,
        isDemo: true,
      );
      expect(shouldShow, isFalse);
    });

    test('si onboarding.done ya es true -> devuelve false', () async {
      await settingsRepo.set(SettingsKeys.onboardingDone, 'true');
      final shouldShow = await checkShouldShowOnboarding(
        db: db,
        settings: settingsRepo,
        isDemo: false,
      );
      expect(shouldShow, isFalse);
    });

    test('si existe al menos un movimiento -> devuelve false y fija onboarding.done = true', () async {
      final cat = await (db.select(db.categories)..limit(1)).getSingle();
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: 'tx-real',
              type: TxType.expense,
              amount: 50000,
              categoryId: cat.id,
              occurredAt: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              source: TxSource.manual,
            ),
          );

      final shouldShow = await checkShouldShowOnboarding(
        db: db,
        settings: settingsRepo,
        isDemo: false,
      );
      expect(shouldShow, isFalse);
      expect(
        await settingsRepo.get(SettingsKeys.onboardingDone),
        equals('true'),
      );
    });

    test('si existe al menos una meta -> devuelve false y fija onboarding.done = true', () async {
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              id: 'g-real',
              name: 'Meta existente',
              icon: 'target',
              targetAmount: 1000000,
              createdAt: DateTime.now(),
            ),
          );

      final shouldShow = await checkShouldShowOnboarding(
        db: db,
        settings: settingsRepo,
        isDemo: false,
      );
      expect(shouldShow, isFalse);
      expect(
        await settingsRepo.get(SettingsKeys.onboardingDone),
        equals('true'),
      );
    });

    test('si existe al menos un préstamo -> devuelve false y fija onboarding.done = true', () async {
      await db
          .into(db.loans)
          .insert(
            LoansCompanion.insert(
              id: 'loan-real',
              name: 'Préstamo existente',
              kind: LoanKind.loan,
              totalAmount: 500000,
              direction: LoanDirection.owe,
              startDate: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final shouldShow = await checkShouldShowOnboarding(
        db: db,
        settings: settingsRepo,
        isDemo: false,
      );
      expect(shouldShow, isFalse);
      expect(
        await settingsRepo.get(SettingsKeys.onboardingDone),
        equals('true'),
      );
    });

    test('si existe al menos un esquema de cobro -> devuelve false y fija onboarding.done = true', () async {
      final cat = await (db.select(db.categories)..limit(1)).getSingle();
      await db
          .into(db.incomeSchedules)
          .insert(
            IncomeSchedulesCompanion.insert(
              id: 'sched-real',
              mode: 'monthly',
              payDays: '[-1]',
              payDayRules: '["previous"]',
              paySplitPercents: '[100]',
              categoryId: cat.id,
              effectiveFrom: DateTime.now(),
            ),
          );

      final shouldShow = await checkShouldShowOnboarding(
        db: db,
        settings: settingsRepo,
        isDemo: false,
      );
      expect(shouldShow, isFalse);
      expect(
        await settingsRepo.get(SettingsKeys.onboardingDone),
        equals('true'),
      );
    });
  });

  group('OnboardingFlow widget (Plan 4 Task 7)', () {
    testWidgets(
      'base limpia muestra el flujo con logotipo pockt y 3 pasos salteables',
      (t) async {
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              settingsRepositoryProvider.overrideWithValue(settingsRepo),
              notifierProvider.overrideWithValue(fakeNotifier),
            ],
            child: MaterialApp(home: OnboardingFlow(onFinish: () {})),
          ),
        );
        await t.pumpAndSettle();

        // Logotipo pockt arriba
        expect(
          find.byKey(const ValueKey('onboarding-wordmark')),
          findsOneWidget,
        );

        // Paso 1: Esquema de cobro
        expect(find.text('¿Cómo cobrás?'), findsOneWidget);
        expect(find.text('Saltear'), findsOneWidget);

        // Avanzar al paso 2
        await t.tap(find.text('Continuar'));
        await t.pumpAndSettle();

        // Paso 2: Presupuestos
        expect(find.text('Límites para tus gastos'), findsOneWidget);
        expect(find.text('Saltear'), findsOneWidget);

        // Avanzar al paso 3
        await t.tap(find.text('Continuar'));
        await t.pumpAndSettle();

        // Paso 3: Copia de seguridad local
        expect(find.text('Copia de seguridad local'), findsOneWidget);
        expect(find.textContaining('Documentos/Pockt'), findsOneWidget);
        expect(find.text('Empezar a usar Pockt'), findsOneWidget);
      },
    );

    testWidgets(
      'saltear en el paso 1 guarda onboarding.done y llama a onFinish',
      (t) async {
        bool finished = false;
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              settingsRepositoryProvider.overrideWithValue(settingsRepo),
              notifierProvider.overrideWithValue(fakeNotifier),
            ],
            child: MaterialApp(
              home: OnboardingFlow(onFinish: () => finished = true),
            ),
          ),
        );
        await t.pumpAndSettle();

        await t.tap(find.text('Saltear'));
        await t.pumpAndSettle();

        expect(finished, isTrue);
        expect(
          await settingsRepo.get(SettingsKeys.onboardingDone),
          equals('true'),
        );
      },
    );

    testWidgets('en PocktApp con datos reales NO se muestra OnboardingFlow', (
      t,
    ) async {
      final cat = await (db.select(db.categories)..limit(1)).getSingle();
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: 'tx-existing',
              type: TxType.expense,
              amount: 25000,
              categoryId: cat.id,
              occurredAt: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              source: TxSource.manual,
            ),
          );

      await t.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
            notifierProvider.overrideWithValue(fakeNotifier),
          ],
          child: const PocktApp(),
        ),
      );
      await t.pumpAndSettle();

      // Debe ir directo a AppShell y NO mostrar OnboardingFlow
      expect(find.byType(OnboardingFlow), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('en PocktApp con POCKT_DEMO NO se muestra OnboardingFlow', (
      t,
    ) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
            notifierProvider.overrideWithValue(fakeNotifier),
            isDemoModeProvider.overrideWithValue(true),
          ],
          child: const PocktApp(),
        ),
      );
      await t.pumpAndSettle();

      expect(find.byType(OnboardingFlow), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets(
      'completar los 3 pasos guarda esquema, presupuestos, contraseña y va a AppShell',
      (t) async {
        final keys = KeyStorage.inMemory();
        final store = MemoryBackupStore();
        final backupService = BackupService(
          db: db,
          store: store,
          keys: keys,
          settings: settingsRepo,
          argonIterations: 1,
          argonMemoryInKiB: 1024,
        );

        bool finished = false;
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              settingsRepositoryProvider.overrideWithValue(settingsRepo),
              notifierProvider.overrideWithValue(fakeNotifier),
              backupServiceProvider.overrideWithValue(backupService),
            ],
            child: MaterialApp(
              home: OnboardingFlow(onFinish: () => finished = true),
            ),
          ),
        );
        await t.pumpAndSettle();

        // Paso 1: Esquema de cobro -> Continuar
        await t.tap(find.text('Continuar'));
        await t.pumpAndSettle();

        // Paso 2: Presupuestos -> Continuar
        await t.tap(find.text('Continuar'));
        await t.pumpAndSettle();

        // Paso 3: Copia de seguridad -> ingresar contraseña
        await t.enterText(find.byType(TextField).first, '1234');
        await t.enterText(find.byType(TextField).last, '1234');
        await t.runAsync(() async {
          await t.tap(find.text('Empezar a usar Pockt'));
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));

        expect(finished, isTrue);
        expect(
          await settingsRepo.get(SettingsKeys.onboardingDone),
          equals('true'),
        );

        // Verificamos que se guardó el esquema
        final schedules = await db.select(db.incomeSchedules).get();
        expect(schedules, isNotEmpty);

        // Verificamos que se guardaron presupuestos
        final budgets = await db.select(db.budgets).get();
        expect(budgets, isNotEmpty);

        // Verificamos que la clave de backup se guardó
        final keyData = await keys.load();
        expect(keyData, isNotNull);
      },
    );
  });
}
