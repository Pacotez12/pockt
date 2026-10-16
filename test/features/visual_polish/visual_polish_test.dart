import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/backup/data/backup_store.dart';
import 'package:pockt/features/backup/data/key_storage.dart';
import 'package:pockt/features/backup/domain/backup_service.dart';
import 'package:pockt/features/backup/ui/backup_screen.dart';
import 'package:pockt/features/budgets/data/budgets_repository.dart';
import 'package:pockt/features/budgets/ui/budgets_screen.dart';
import 'package:pockt/features/events/data/events_repository.dart';
import 'package:pockt/features/events/ui/events_screen.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/goals/ui/goal_detail_screen.dart';
import 'package:pockt/features/goals/ui/goals_screen.dart';
import 'package:pockt/features/income/ui/carry_over_card.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/loans/ui/loans_screen.dart';
import 'package:pockt/features/onboarding/ui/onboarding_flow.dart';
import 'package:pockt/features/safe_to_spend/domain/safe_to_spend.dart';
import 'package:pockt/features/safe_to_spend/ui/buy_simulator_sheet.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/transactions/ui/tx_row.dart';

void main() {
  late AppDatabase db;
  late GoalsRepository goalsRepo;
  late EventsRepository eventsRepo;
  late LoansRepository loansRepo;
  late SettingsRepository settingsRepo;
  late FakeNotifier notifier;
  late BudgetsRepository budgetsRepo;
  late TransactionsRepository txRepo;
  late MemoryBackupStore backupStore;
  late KeyStorage keyStorage;
  late BackupService backupService;

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    goalsRepo = GoalsRepository(db);
    eventsRepo = EventsRepository(db);
    loansRepo = LoansRepository(db);
    settingsRepo = SettingsRepository(db);
    notifier = FakeNotifier();
    budgetsRepo = BudgetsRepository(db, notifier: notifier);
    txRepo = TransactionsRepository(db, notifier: notifier);
    backupStore = MemoryBackupStore();
    keyStorage = KeyStorage.inMemory();
    backupService = BackupService(
      db: db,
      store: backupStore,
      keys: keyStorage,
      settings: settingsRepo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp({
    required Widget child,
    ThemeData? theme,
    double textScale = 1.0,
    Size size = const Size(360, 740),
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        goalsRepositoryProvider.overrideWithValue(goalsRepo),
        eventsRepositoryProvider.overrideWithValue(eventsRepo),
        loansRepositoryProvider.overrideWithValue(loansRepo),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        notifierProvider.overrideWithValue(notifier),
        budgetsRepositoryProvider.overrideWithValue(budgetsRepo),
        transactionsRepositoryProvider.overrideWithValue(txRepo),
        backupStoreProvider.overrideWithValue(backupStore),
        keyStorageProvider.overrideWithValue(keyStorage),
        backupServiceProvider.overrideWithValue(backupService),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(theme: theme ?? buildDarkTheme(), home: child),
      ),
    );
  }

  testWidgets(
    'Metas: GoalsScreen en 360 px con textScaler 1.3 no desborda y usa Gs.',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final g1 = await goalsRepo.createGoal(
        name: 'Meta con nombre bastante largo para prueba',
        icon: 'target',
        targetAmount: 15000000,
        targetDate: DateTime(2027, 6, 30),
      );
      await goalsRepo.addContribution(
        goalId: g1,
        amount: 3500000,
        date: DateTime.now(),
      );

      await tester.pumpWidget(
        buildApp(
          child: const GoalsScreen(),
          textScale: 1.3,
          size: const Size(360, 740),
        ),
      );
      await tester.pump();

      // Debe formatear con Gs. y no con ₲
      expect(find.textContaining('₲'), findsNothing);
      expect(find.textContaining('Gs.'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Metas: GoalDetailScreen en 360 px con textScaler 1.3 no desborda y usa Gs.',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final g1 = await goalsRepo.createGoal(
        name: 'Viaje familiar a Florianópolis',
        icon: 'airplane-tilt',
        targetAmount: 20000000,
        targetDate: DateTime(2027, 1, 15),
      );
      await goalsRepo.addContribution(
        goalId: g1,
        amount: 5000000,
        date: DateTime.now(),
        note: 'Primer aporte',
      );

      await tester.pumpWidget(
        buildApp(
          child: GoalDetailScreen(goalId: g1),
          textScale: 1.3,
          size: const Size(360, 740),
        ),
      );
      await tester.pump();

      expect(find.textContaining('₲'), findsNothing);
      expect(find.textContaining('Gs.'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Saldo arrastrado: botones de CarryOverCard tienen altura al menos 44 px',
    (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Scaffold(
            body: CarryOverCard(
              amount: 500000,
              periodStart: DateTime(2026, 10, 1),
            ),
          ),
        ),
      );
      await tester.pump();

      final cardButton = find.byType(Pressable);
      expect(cardButton, findsWidgets);

      for (final element in tester.elementList(cardButton)) {
        final renderBox = element.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          expect(renderBox.size.height, greaterThanOrEqualTo(44.0));
        }
      }
    },
  );

  testWidgets(
    'Primer uso: OnboardingFlow funciona en modo claro y no desborda en 360 px',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildApp(
          theme: buildLightTheme(),
          child: OnboardingFlow(onFinish: () {}),
          textScale: 1.3,
          size: const Size(360, 740),
        ),
      );
      await tester.pump();

      // Debe mostrar el primer paso sin errores de overflow
      expect(find.text('¿Cómo cobrás?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Eventos: EventsScreen en 360 px con textScaler 1.3 no desborda',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await eventsRepo.createEvent(
        name: 'Cumpleaños número treinta con festejo largo',
        icon: 'confetti',
        startDate: DateTime.now(),
        isActive: true,
      );

      await tester.pumpWidget(
        buildApp(
          child: const EventsScreen(),
          textScale: 1.3,
          size: const Size(360, 740),
        ),
      );
      await tester.pump();

      expect(find.text('Eventos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '¿Lo compro?: buy_simulator_sheet en 360 px con textScaler 1.3 no desborda',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildApp(
          textScale: 1.3,
          size: const Size(360, 740),
          child: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => showBuySimulatorSheet(
                    ctx,
                    initialSafeToSpend: SafeToSpend(
                      amount: 150000,
                      quedan: 1500000,
                      pendingRecurring: 200000,
                      proratedGoals: 100000,
                      daysUntilPay: 10,
                      targetDate: DateTime.now().add(const Duration(days: 10)),
                      hasIncomeSchedule: true,
                    ),
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Préstamos: LoansScreen muestra estado vacío con botón de acción',
    (tester) async {
      await tester.pumpWidget(buildApp(child: const LoansScreen()));
      await tester.pump();

      expect(find.byKey(const ValueKey('add-loan-empty-btn')), findsOneWidget);
    },
  );

  testWidgets('Presupuestos: detalle agrupa movimientos en TxGroupCard', (
    tester,
  ) async {
    const catId = '018f0000-0000-7000-8000-000000000001';
    await tester.runAsync(() async {
      await budgetsRepo.setLimit(catId, 1000000);
      await txRepo.add(
        type: TxType.expense,
        amount: 150000,
        categoryId: catId,
        occurredAt: DateTime(2026, 10, 10),
      );
      await txRepo.add(
        type: TxType.expense,
        amount: 80000,
        categoryId: catId,
        occurredAt: DateTime(2026, 10, 12),
      );
    });

    await tester.pumpWidget(
      buildApp(
        child: BudgetsScreen(
          initialYear: 2026,
          initialMonth: 10,
          nowLocal: DateTime(2026, 10, 15, 12, 0),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Abrir detalle tocando la tarjeta
    await tester.tap(find.text('Comida'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TxGroupCard), findsOneWidget);
    expect(find.text('Movimientos del mes'), findsOneWidget);
  });

  testWidgets('Copia de seguridad: terminología copia y botón exportar copia', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(child: const BackupScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Copia de seguridad'), findsOneWidget);
    expect(find.text('Última copia: Sin copias aún'), findsOneWidget);
    expect(find.text('Exportar copia'), findsOneWidget);
    expect(find.text('Copia automática y cifrada'), findsOneWidget);
  });
}
