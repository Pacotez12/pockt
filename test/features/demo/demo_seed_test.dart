import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/budgets/data/budgets_repository.dart';
import 'package:pockt/features/demo/demo_seed.dart';
import 'package:pockt/features/income/data/income_schedule_repository.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase testDb;
  final nowLocal = DateTime(2026, 10, 9, 12, 0);

  setUp(() {
    setLocalZone('America/Asuncion');
    testDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
  });

  tearDown(() async {
    await testDb.close();
  });

  test('seedDemoData con base vacía deja movimientos en el mes actual, 2 sugerencias pendientes y 3 presupuestos',
      () async {
    await seedDemoData(testDb, nowLocal: nowLocal);

    final txRepo = TransactionsRepository(testDb, clock: () => nowLocal);
    final suggestionsRepo =
        SuggestionsRepository(testDb, clock: () => nowLocal);
    final budgetsRepo = BudgetsRepository(testDb);
    final incomeRepo =
        IncomeScheduleRepository(testDb, clock: () => nowLocal);

    // 1. Movimientos en el mes actual
    final currentMonthExpense =
        await txRepo.watchMonthTotal(2026, 10, TxType.expense).first;
    expect(currentMonthExpense, greaterThan(0));

    // 2. Exactamente 2 sugerencias pendientes
    final pendingCount = await suggestionsRepo.watchPendingCount().first;
    expect(pendingCount, equals(2));

    final pendingViews = await suggestionsRepo.watchPending().first;
    final pendingMerchants =
        pendingViews.map((s) => s.suggestion.merchant).toSet();
    expect(pendingMerchants, containsAll({'Netflix', 'ANDE'}));

    // 3. Exactamente 3 presupuestos con porcentajes correctos
    final budgets = await budgetsRepo.watchAll().first;
    expect(budgets.length, equals(3));

    final budgetMap = {for (final b in budgets) b.category.name: b.budget};
    expect(budgetMap.containsKey('Comida'), isTrue);
    expect(budgetMap.containsKey('Transporte'), isTrue);
    expect(budgetMap.containsKey('Ocio'), isTrue);

    expect(budgetMap['Comida']!.monthlyLimit, equals(1500000));
    expect(budgetMap['Transporte']!.monthlyLimit, equals(500000));
    expect(budgetMap['Ocio']!.monthlyLimit, equals(400000));

    final totals = await txRepo.watchMonthCategoryTotals(2026, 10).first;
    final catTotals = {for (final ct in totals) ct.category.name: ct.total};

    // Comida: ~85% (1.275.000 de 1.500.000)
    final comidaTotal = catTotals['Comida'] ?? 0;
    final comidaPercent = comidaTotal / 1500000;
    expect(comidaPercent, closeTo(0.85, 0.05));

    // Transporte: ~50% (250.000 de 500.000)
    final transporteTotal = catTotals['Transporte'] ?? 0;
    final transportePercent = transporteTotal / 500000;
    expect(transportePercent, closeTo(0.50, 0.05));

    // Ocio: pasado del 100% (> 400.000)
    final ocioTotal = catTotals['Ocio'] ?? 0;
    expect(ocioTotal, greaterThan(400000));

    // 4. Esquema de cobro quincenal [15, -1] con expectedAmount 3.500.000
    final schedule = await incomeRepo.watchCurrent().first;
    expect(schedule, isNotNull);
    expect(schedule!.mode, equals('biweekly'));
    expect(schedule.expectedAmount, equals(3500000));

    // 5. Sueldos registrados (mes anterior: 15/09 y 30/09)
    final allTxs = await testDb.select(testDb.transactions).get();
    final incomeTxs =
        allTxs.where((t) => t.type == TxType.income).toList();
    expect(incomeTxs.length, greaterThanOrEqualTo(2));

    final payDates = incomeTxs
        .map((t) => '${t.occurredAt.year}-${t.occurredAt.month.toString().padLeft(2, '0')}-${t.occurredAt.day.toString().padLeft(2, '0')}')
        .toSet();
    expect(payDates, containsAll({'2026-09-15', '2026-09-30'}));

    // 6. Comercios paraguayos presentes en gastos
    final merchants =
        allTxs.map((t) => t.merchant).whereType<String>().toSet();
    expect(
      merchants,
      containsAll({
        'Superseis',
        'Biggie',
        'Stock',
        'Bolt',
        'Uber',
        'Café Martínez',
        'Lomitería',
        'Farmacia Catedral',
        'Petrobras',
        'Netflix',
        'Spotify',
        'ANDE',
        'Tigo',
      }),
    );
  });

  test('seedDemoData dos veces no duplica', () async {
    await seedDemoData(testDb, nowLocal: nowLocal);

    final txCountInitial =
        (await testDb.select(testDb.transactions).get()).length;
    final budgetCountInitial =
        (await testDb.select(testDb.budgets).get()).length;
    final recurringCountInitial =
        (await testDb.select(testDb.recurringRules).get()).length;
    final sugCountInitial =
        (await testDb.select(testDb.suggestedTransactions).get()).length;
    final scheduleCountInitial =
        (await testDb.select(testDb.incomeSchedules).get()).length;

    expect(txCountInitial, greaterThan(0));
    expect(budgetCountInitial, equals(3));
    expect(recurringCountInitial, equals(2));
    expect(sugCountInitial, equals(2));
    expect(scheduleCountInitial, equals(1));

    // Segunda llamada: debe ser idempotente
    await seedDemoData(testDb, nowLocal: nowLocal);

    final txCountSecond =
        (await testDb.select(testDb.transactions).get()).length;
    final budgetCountSecond =
        (await testDb.select(testDb.budgets).get()).length;
    final recurringCountSecond =
        (await testDb.select(testDb.recurringRules).get()).length;
    final sugCountSecond =
        (await testDb.select(testDb.suggestedTransactions).get()).length;
    final scheduleCountSecond =
        (await testDb.select(testDb.incomeSchedules).get()).length;

    expect(txCountSecond, equals(txCountInitial));
    expect(budgetCountSecond, equals(budgetCountInitial));
    expect(recurringCountSecond, equals(recurringCountInitial));
    expect(sugCountSecond, equals(sugCountInitial));
    expect(scheduleCountSecond, equals(scheduleCountInitial));
  });
}
