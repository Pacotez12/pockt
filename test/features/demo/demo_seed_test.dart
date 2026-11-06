import 'dart:io';

import 'package:drift/drift.dart'
    show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/sync/migrate_legacy_db.dart';
import 'package:pockt/core/sync/powersync_schema.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/budgets/data/budgets_repository.dart';
import 'package:pockt/features/demo/demo_seed.dart';
import 'package:pockt/features/income/data/income_schedule_repository.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:powersync/powersync.dart' as ps;

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

    // 4. Esquema de cobro quincenal [15, -1] con monthlyAmount 7.000.000 y reparto [50, 50]
    final schedule = await incomeRepo.watchCurrent().first;
    expect(schedule, isNotNull);
    expect(schedule!.mode, equals('biweekly'));
    expect(schedule.monthlyAmount, equals(7000000));
    expect(schedule.paySplitPercents, equals('[50,50]'));

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

  test('seedDemoData incluye metas con aportes y un préstamo con pagos', () async {
    await seedDemoData(testDb, nowLocal: nowLocal);
    expect(await testDb.select(testDb.goals).get(), hasLength(2));
    expect(await testDb.select(testDb.goalContributions).get(), hasLength(4));
    expect(await testDb.select(testDb.loans).get(), hasLength(1));
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

  test(
      'seedDemoData sobre PowerSync deja los mismos conteos por tabla que sobre Drift en memoria',
      () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    // 1. Cargar datos en base Drift en memoria (testDb)
    await seedDemoData(testDb, nowLocal: nowLocal);

    // 2. Medir conteos por tabla en Drift
    final expectedCounts = <String, int>{};
    for (final table in allPocktTables) {
      final res = await testDb
          .customSelect('SELECT count(*) as c FROM "$table"')
          .getSingle();
      expectedCounts[table] = res.read<int>('c');
    }

    // 3. Crear base PowerSync temporal
    final tempDir =
        Directory.systemTemp.createTempSync('demo_seed_powersync_');
    addTearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    final psDbPath = p.join(tempDir.path, 'demo_powersync.db');
    final psDb = ps.PowerSyncDatabase(
      schema: pocktPowerSyncSchema,
      path: psDbPath,
    );
    await psDb.initialize();
    addTearDown(psDb.close);

    final powerSyncDb = AppDatabase.powerSync(psDb);
    addTearDown(powerSyncDb.close);

    // 4. Sembrar demo en PowerSync
    await seedDemoData(powerSyncDb, nowLocal: nowLocal);

    // Deserializar cada tabla para verificar que ningún campo non-null quedó en null
    await powerSyncDb.select(powerSyncDb.categories).get();
    await powerSyncDb.select(powerSyncDb.transactions).get();
    await powerSyncDb.select(powerSyncDb.suggestedTransactions).get();
    await powerSyncDb.select(powerSyncDb.recurringRules).get();
    await powerSyncDb.select(powerSyncDb.incomeSchedules).get();
    await powerSyncDb.select(powerSyncDb.budgets).get();
    await powerSyncDb.select(powerSyncDb.dayMarks).get();
    await powerSyncDb.select(powerSyncDb.settings).get();
    await powerSyncDb.select(powerSyncDb.categoryKeywords).get();
    await powerSyncDb.select(powerSyncDb.merchantMemory).get();
    await powerSyncDb.select(powerSyncDb.salaryDeductions).get();
    await powerSyncDb.select(powerSyncDb.loans).get();
    await powerSyncDb.select(powerSyncDb.loanInstallments).get();
    await powerSyncDb.select(powerSyncDb.goals).get();
    await powerSyncDb.select(powerSyncDb.goalContributions).get();
    await powerSyncDb.select(powerSyncDb.entryShortcuts).get();
    await powerSyncDb.select(powerSyncDb.events).get();
    await powerSyncDb.select(powerSyncDb.counterpartyRules).get();

    // 5. Comparar conteos
    final actualCounts = <String, int>{};
    for (final table in allPocktTables) {
      final res = await powerSyncDb
          .customSelect('SELECT count(*) as c FROM "$table"')
          .getSingle();
      actualCounts[table] = res.read<int>('c');
    }

    expect(actualCounts, equals(expectedCounts));
  });

  test(
      'seedDemoData es atómica: si ocurre un error a mitad de camino, se revierte todo',
      () async {
    // Disparador para que falle cuando intente insertar el primer presupuesto
    await testDb.customStatement(
      'CREATE TRIGGER fail_on_budget BEFORE INSERT ON budgets '
      "BEGIN SELECT RAISE(ABORT, 'simulated budget failure'); END;",
    );

    expect(
      () => seedDemoData(testDb, nowLocal: nowLocal),
      throwsA(anything),
    );

    // Debe revertir todo: 0 transacciones, 0 esquemas, 0 presupuestos, 0 memorias
    final txCount =
        (await testDb.select(testDb.transactions).get()).length;
    final scheduleCount =
        (await testDb.select(testDb.incomeSchedules).get()).length;
    final budgetCount =
        (await testDb.select(testDb.budgets).get()).length;
    final memoryCount =
        (await testDb.select(testDb.merchantMemory).get()).length;

    expect(txCount, equals(0));
    expect(scheduleCount, equals(0));
    expect(budgetCount, equals(0));
    expect(memoryCount, equals(0));
  });
}
