import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/events/data/events_repository.dart';
import 'package:pockt/features/income/data/income_schedule_repository.dart';
import 'package:pockt/features/reports/data/reports_repository.dart';
import 'package:pockt/features/reports/domain/weekly_summary.dart';
import 'package:pockt/features/safe_to_spend/domain/safe_to_spend.dart';
import 'package:pockt/features/settings/domain/export_csv.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/widget/home_widget_bridge.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    await initLocalZone();
  });

  late AppDatabase db;
  late TransactionsRepository txRepo;

  const catComidaId = '018f0000-0000-7000-8000-000000000001';
  const catOtrosId = '018f0000-0000-7000-8000-000000000010';
  const catSueldoId = '018f0000-0000-7000-8000-000000000011';

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    txRepo = TransactionsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Pago de tarjeta (TxType.transfer) NO suma en gastado, quedan, presupuestos, reportes, calendario, saldo arrastrado, Podés gastar hoy, ¿Lo compro?, hormiga, eventos ni widget, y sale como Transferencia en CSV', () async {
    final oct10 = DateTime(2026, 10, 10, 12, 0).toUtc();
    final oct14 = DateTime(2026, 10, 14, 12, 0).toUtc();

    // 1. Esquema de cobro desde 01/10/2026
    await db
        .into(db.incomeSchedules)
        .insert(
          IncomeSchedulesCompanion.insert(
            id: 'sched-1',
            mode: 'biweekly',
            payDays: '[15, -1]',
            payDayRules: '["either", "previous"]',
            monthlyAmount: const Value(6000000),
            paySplitPercents: '[50, 50]',
            categoryId: catSueldoId,
            effectiveFrom: DateTime(2026, 10, 1),
          ),
        );

    // Ingreso en 1ª quincena (01/10): 3.000.000
    await txRepo.add(
      type: TxType.income,
      amount: 3000000,
      categoryId: catSueldoId,
      occurredAt: DateTime(2026, 10, 1, 9, 0),
    );

    // Gasto real (10/10): 50.000 en Comida
    await txRepo.add(
      type: TxType.expense,
      amount: 50000,
      categoryId: catComidaId,
      merchant: 'Pizza Hut',
      occurredAt: oct10,
    );

    // Evento activo el 14/10
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: 'ev-1',
            name: 'Viaje',
            icon: 'airplane-tilt',
            startDate: DateTime(2026, 10, 12),
            isActive: const Value(true),
            createdAt: DateTime(2026, 10, 12),
          ),
        );

    // Gasto hormiga (<= 25.000) el 14/10: 15.000 en Comida (vinculado a evento)
    await txRepo.add(
      type: TxType.expense,
      amount: 15000,
      categoryId: catComidaId,
      merchant: 'Biggie',
      occurredAt: oct14,
      eventId: 'ev-1',
    );

    // Pago de tarjeta (TxType.transfer) el 14/10 por 1.500.000 y otro chico por 10.000
    await txRepo.add(
      type: TxType.transfer,
      amount: 1500000,
      categoryId: catComidaId,
      merchant: 'Bancop Pago de tarjeta con cedula',
      occurredAt: oct14,
      eventId: 'ev-1',
    );
    await txRepo.add(
      type: TxType.transfer,
      amount: 10000,
      categoryId: catOtrosId,
      merchant: 'FINANCIERA FIC Pago de tarjeta con',
      occurredAt: oct14,
    );

    // A) Gastado e Ingresos del mes (watchMonthTotal)
    final spentMonth = await txRepo
        .watchMonthTotal(2026, 10, TxType.expense)
        .first;
    final incomeMonth = await txRepo
        .watchMonthTotal(2026, 10, TxType.income)
        .first;
    expect(
      spentMonth,
      65000,
    ); // 50.000 + 15.000 (excluye 1.510.000 de transfer)
    expect(incomeMonth, 3000000);

    // B) Quedan / Período (watchTotalSince)
    final spentSinceOct1 = await txRepo
        .watchTotalSince(DateTime(2026, 10, 1), TxType.expense)
        .first;
    expect(spentSinceOct1, 65000);

    // C) Presupuestos (watchMonthCategoryTotals)
    final catSpends = await txRepo.watchMonthCategoryTotals(2026, 10).first;
    final comidaSpend = catSpends.firstWhere(
      (c) => c.category.id == catComidaId,
    );
    expect(comidaSpend.total, 65000);

    // D) Reportes (Categorías, Evolución, Comercios, Semana, Hormiga)
    final reportsRepo = ReportsRepository(db);
    final breakdown = await reportsRepo.watchMonthByCategory(2026, 10).first;
    expect(breakdown.fold<int>(0, (s, c) => s + c.total), 65000);

    final trend = await reportsRepo
        .watchEvolution(months: 1, todayLocal: DateTime(2026, 10, 14))
        .first;
    expect(trend.single.expense, 65000);
    expect(trend.single.income, 3000000);

    final merchants = await reportsRepo.watchByMerchant(2026, 10).first;
    expect(merchants.fold<int>(0, (s, m) => s + m.total), 65000);

    final allActive = await txRepo.getAllActive();
    final weekly = calculateWeeklySummary(
      currentWeekTxs: allActive,
      previousWeekTxs: const [],
      weekStart: DateTime(2026, 10, 12),
      weekEnd: DateTime(2026, 10, 18),
    );
    expect(weekly.currentWeekTotal, 65000);

    final antSummary = await reportsRepo
        .watchAntExpenses(2026, 10, threshold: 25000)
        .first;
    expect(antSummary.total, 15000); // excluye el transfer de 10.000
    expect(antSummary.count, 1);

    // E) Calendario (watchDailyExpenseTotals & daysWithExpense)
    final dailyTotals = await txRepo.watchDailyExpenseTotals(2026, 10).first;
    expect(dailyTotals[14], 15000);

    // F) Saldo arrastrado (carryOverBefore al 15/10: ingresos 3.000.000 - gastos 65.000)
    final incomeRepo = IncomeScheduleRepository(db);
    final carryOver = await incomeRepo.carryOverBefore(DateTime(2026, 10, 15));
    expect(carryOver, 3000000 - 65000);

    // G) Podés gastar hoy & ¿Lo compro? (cálculo de impacto diario)
    // Una sugerencia pendiente de tipo transfer tampoco descuenta de pendingRecurring
    final safePure = safeToSpendToday(
      todayLocal: DateTime(2026, 10, 14),
      remaining: spentSinceOct1 == 65000 ? (3000000 - 65000) : 0,
      nextPayDate: DateTime(2026, 10, 15),
      pendingSuggestions: [
        SuggestedTransaction(
          id: 'sug-transfer',
          type: TxType.transfer,
          amount: 900000,
          currency: 'PYG',
          occurredAt: DateTime(2026, 10, 14),
          source: TxSource.capture,
          status: 'pending',
          createdAt: DateTime(2026, 10, 14),
        ),
      ],
    );
    expect(safePure.pendingRecurring, 0);
    expect(safePure.quedan, 3000000 - 65000);

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final queue = <SafeToSpend>[];
    final sub = container.listen(safeToSpendProvider, (prev, next) {
      final val = next.value;
      if (val != null) queue.add(val);
    });
    addTearDown(sub.close);
    while (queue.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final safe = queue.last;
    expect(safe.quedan, 3000000 + 3000000 - 65000);
    final simAfter = calculateSafeToSpend(
      remaining: safe.quedan - 100000,
      pendingRecurring: safe.pendingRecurring,
      proratedGoals: safe.proratedGoals,
      daysUntilPay: safe.daysUntilPay,
    );
    expect(simAfter, lessThan(safe.amount));

    // H) Eventos (watchEventDetail)
    final eventsRepo = EventsRepository(db);
    final evDetail = await eventsRepo.watchEventDetail('ev-1').first;
    expect(evDetail.total, 15000); // excluye el transfer de 1.500.000

    // I) Widget (topCategories solo cuenta gastos reales)
    final topCats = await topCategories(
      db,
      n: 4,
      nowLocal: DateTime(2026, 10, 14, 15, 0),
    );
    expect(topCats.first.id, catComidaId);

    // J) CSV (columna Tipo muestra 'Transferencia' para TxType.transfer)
    final csv = generateTransactionsCsv(allActive);
    expect(csv, contains(';Transferencia;1500000;'));
    expect(csv, contains(';Gasto;50000;'));
    expect(csv, contains(';Ingreso;3000000;'));
  });
}
