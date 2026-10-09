import 'dart:math';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/budgets/data/budgets_repository.dart';
import 'package:pockt/features/income/data/income_schedule_repository.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:pockt/features/recurring/data/recurring_repository.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/recurring/domain/recurrence.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

/// Carga datos de demostración realistas y deterministas en la base de datos [db].
///
/// SOLO ejecuta la carga si no existen movimientos en la base de datos.
/// Utiliza una semilla fija de [Random] para garantizar determinismo.
Future<void> seedDemoData(
  AppDatabase db, {
  required DateTime nowLocal,
}) async {
  // 1. SOLO si no hay movimientos:
  final existingTx =
      (await (db.select(db.transactions)..limit(1)).get()).isNotEmpty;
  if (existingTx) {
    return;
  }

  final cats = await db.select(db.categories).get();
  final catByName = {for (final c in cats) c.name: c};

  final comida = catByName['Comida']!;
  final transporte = catByName['Transporte']!;
  final ocio = catByName['Ocio']!;
  final servicios = catByName['Servicios']!;
  final salud = catByName['Salud']!;
  final hogar = catByName['Hogar']!;
  final sueldo = catByName['Sueldo']!;

  final txRepo = TransactionsRepository(db, clock: () => nowLocal);
  final incomeRepo = IncomeScheduleRepository(db, clock: () => nowLocal);
  final budgetsRepo = BudgetsRepository(db);
  final recurringRepo = RecurringRepository(db, clock: () => nowLocal);
  final suggestionsRepo = SuggestionsRepository(db, clock: () => nowLocal);

  // 2. Esquema de cobro quincenal [15, -1] con expectedAmount 3.500.000
  await incomeRepo.setSchedule(
    mode: PayMode.biweekly,
    payDays: const [15, -1],
    shiftToPreviousBusinessDay: true,
    expectedAmount: 3500000,
    categoryId: sueldo.id,
  );

  // 3. Sueldos registrados:
  // - Los dos sueldos del mes anterior (día 15 y fin de mes / 30/09)
  // - El de fin de mes de hace dos meses (dentro de los ~45 días)
  final prevMonthDate = DateTime(nowLocal.year, nowLocal.month - 1, 1);
  final lastDayPrevMonth =
      DateTime(prevMonthDate.year, prevMonthDate.month + 1, 0).day;

  // 15 del mes anterior (e.g. 15/09)
  await txRepo.add(
    type: TxType.income,
    amount: 3500000,
    categoryId: sueldo.id,
    occurredAt: DateTime(prevMonthDate.year, prevMonthDate.month, 15, 8, 30),
    merchant: 'Empresa',
    note: '1ª quincena',
  );

  // Fin del mes anterior (e.g. 30/09)
  await txRepo.add(
    type: TxType.income,
    amount: 3500000,
    categoryId: sueldo.id,
    occurredAt:
        DateTime(prevMonthDate.year, prevMonthDate.month, lastDayPrevMonth, 8, 30),
    merchant: 'Empresa',
    note: '2ª quincena',
  );

  // Hace dos meses (fin de mes, e.g. 31/08 hace ~40 días)
  final twoMonthsAgoDate = DateTime(nowLocal.year, nowLocal.month - 2, 1);
  final lastDayTwoMonthsAgo =
      DateTime(twoMonthsAgoDate.year, twoMonthsAgoDate.month + 1, 0).day;
  await txRepo.add(
    type: TxType.income,
    amount: 3500000,
    categoryId: sueldo.id,
    occurredAt: DateTime(
        twoMonthsAgoDate.year, twoMonthsAgoDate.month, lastDayTwoMonthsAgo, 8, 30),
    merchant: 'Empresa',
    note: '2ª quincena',
  );

  // Si hoy es día 15 o posterior del mes actual, registrar el sueldo del día 15
  if (nowLocal.day >= 15) {
    await txRepo.add(
      type: TxType.income,
      amount: 3500000,
      categoryId: sueldo.id,
      occurredAt: DateTime(nowLocal.year, nowLocal.month, 15, 8, 30),
      merchant: 'Empresa',
      note: '1ª quincena',
    );
  }

  // 4. Presupuestos:
  // Comida: 1.500.000 (~85% usado este mes)
  // Transporte: 500.000 (~50% usado este mes)
  // Ocio: 400.000 (pasado del 100%)
  await budgetsRepo.setLimit(comida.id, 1500000);
  await budgetsRepo.setLimit(transporte.id, 500000);
  await budgetsRepo.setLimit(ocio.id, 400000);

  // 5. Recurrentes Netflix y ANDE, con una sugerencia pendiente de cada uno en la bandeja
  final netflixRuleId = await recurringRepo.add(
    name: 'Netflix',
    type: TxType.expense,
    amount: 85000,
    categoryId: ocio.id,
    frequency: RecurrenceFrequency.monthly,
    dayOfMonth: 8,
  );

  final andeRuleId = await recurringRepo.add(
    name: 'ANDE',
    type: TxType.expense,
    amount: 280000,
    categoryId: servicios.id,
    frequency: RecurrenceFrequency.monthly,
    dayOfMonth: 10,
  );

  await suggestionsRepo.createIfAbsent(
    type: TxType.expense,
    amount: 85000,
    categoryId: ocio.id,
    merchant: 'Netflix',
    occurredAt: nowLocal.subtract(const Duration(days: 1)),
    source: TxSource.recurring,
    sourceRef: netflixRuleId,
  );

  await suggestionsRepo.createIfAbsent(
    type: TxType.expense,
    amount: 280000,
    categoryId: servicios.id,
    merchant: 'ANDE',
    occurredAt: nowLocal.subtract(const Duration(days: 2)),
    source: TxSource.recurring,
    sourceRef: andeRuleId,
  );

  // 6. Gastos del mes actual deterministas con montos exactos para presupuestos:
  // Comida: 1.275.000 (85.0% de 1.500.000)
  // Transporte: 250.000 (50.0% de 500.000)
  // Ocio: 430.000 (107.5% de 400.000, >100%)
  // Servicios: 165.000 (Tigo)
  // Salud: 140.000 (Farmacia Catedral)
  // Hogar: 140.000
  final currentMonthTxs = [
    // Comida (1.275.000 total)
    (category: comida, merchant: 'Superseis', amount: 410000, preferredDay: 6, hour: 11, minute: 30),
    (category: comida, merchant: 'Stock', amount: 285000, preferredDay: 4, hour: 18, minute: 15),
    (category: comida, merchant: 'Superseis', amount: 220000, preferredDay: 3, hour: 16, minute: 40),
    (category: comida, merchant: 'Biggie', amount: 85000, preferredDay: 1, hour: 21, minute: 10),
    (category: comida, merchant: 'Biggie', amount: 65000, preferredDay: 3, hour: 22, minute: 5),
    (category: comida, merchant: 'Lomitería', amount: 60000, preferredDay: 5, hour: 21, minute: 45),
    (category: comida, merchant: 'Biggie', amount: 50000, preferredDay: 8, hour: 20, minute: 30),
    (category: comida, merchant: 'Café Martínez', amount: 45000, preferredDay: 1, hour: 10, minute: 15),
    (category: comida, merchant: 'Café Martínez', amount: 35000, preferredDay: 5, hour: 15, minute: 20),
    (category: comida, merchant: 'Café Martínez', amount: 20000, preferredDay: 9, hour: 8, minute: 12),

    // Transporte (250.000 total)
    (category: transporte, merchant: 'Petrobras', amount: 160000, preferredDay: 6, hour: 12, minute: 15),
    (category: transporte, merchant: 'Uber', amount: 32000, preferredDay: 8, hour: 14, minute: 20),
    (category: transporte, merchant: 'Bolt', amount: 29500, preferredDay: 1, hour: 19, minute: 45),
    (category: transporte, merchant: 'Bolt', amount: 28500, preferredDay: 9, hour: 9, minute: 3),

    // Ocio (430.000 total)
    (category: ocio, merchant: 'Cine Itaú', amount: 180000, preferredDay: 5, hour: 20, minute: 0),
    (category: ocio, merchant: 'Bar', amount: 110000, preferredDay: 1, hour: 23, minute: 30),
    (category: ocio, merchant: 'Netflix', amount: 85000, preferredDay: 3, hour: 4, minute: 10),
    (category: ocio, merchant: 'Spotify', amount: 55000, preferredDay: 4, hour: 5, minute: 0),

    // Otros
    (category: servicios, merchant: 'Tigo', amount: 165000, preferredDay: 1, hour: 11, minute: 0),
    (category: salud, merchant: 'Farmacia Catedral', amount: 95000, preferredDay: 1, hour: 17, minute: 40),
    (category: salud, merchant: 'Farmacia Catedral', amount: 45000, preferredDay: 5, hour: 18, minute: 50),
    (category: hogar, merchant: 'Bazar', amount: 140000, preferredDay: 1, hour: 16, minute: 15),
  ];

  final maxDay = nowLocal.day;
  // Días que dejamos sin gastos para contraste en el calendario de calor (l0)
  final emptyDays = <int>{
    if (maxDay >= 3) 2,
    if (maxDay >= 8) 7,
  };

  for (final item in currentMonthTxs) {
    int day;
    if (item.preferredDay == 9 && maxDay >= 9) {
      day = maxDay;
    } else if (item.preferredDay <= maxDay && !emptyDays.contains(item.preferredDay)) {
      day = item.preferredDay;
    } else {
      day = 1 + ((item.preferredDay - 1) % maxDay);
      if (emptyDays.contains(day)) {
        day = 1;
      }
    }

    await txRepo.add(
      type: TxType.expense,
      amount: item.amount,
      categoryId: item.category.id,
      merchant: item.merchant,
      occurredAt: DateTime(nowLocal.year, nowLocal.month, day, item.hour, item.minute),
    );
  }

  // 7. Gastos de los ~45 días previos con Random determinista (semilla 42)
  final rng = Random(42);
  final startDate = nowLocal.subtract(const Duration(days: 45));
  final lastDayOfPast =
      DateTime(nowLocal.year, nowLocal.month, 1).subtract(const Duration(days: 1));

  final expenseTemplates = [
    (category: comida, merchant: 'Superseis', min: 80000, max: 240000),
    (category: comida, merchant: 'Biggie', min: 20000, max: 65000),
    (category: comida, merchant: 'Stock', min: 70000, max: 190000),
    (category: comida, merchant: 'Café Martínez', min: 25000, max: 48000),
    (category: comida, merchant: 'Lomitería', min: 30000, max: 55000),
    (category: transporte, merchant: 'Bolt', min: 16000, max: 35000),
    (category: transporte, merchant: 'Uber', min: 20000, max: 42000),
    (category: transporte, merchant: 'Petrobras', min: 130000, max: 220000),
    (category: salud, merchant: 'Farmacia Catedral', min: 35000, max: 110000),
    (category: ocio, merchant: 'Spotify', min: 55000, max: 55000),
    (category: servicios, merchant: 'ANDE', min: 240000, max: 290000),
    (category: servicios, merchant: 'Tigo', min: 150000, max: 180000),
  ];

  var current = DateTime(startDate.year, startDate.month, startDate.day);
  final end = DateTime(lastDayOfPast.year, lastDayOfPast.month, lastDayOfPast.day);

  while (!current.isAfter(end)) {
    // ~20% de días sin gastos para contraste en el mapa de calor
    if (rng.nextDouble() < 0.20) {
      current = current.add(const Duration(days: 1));
      continue;
    }

    // Días caros para contraste
    final isExpensiveDay =
        (current.day == 10 || current.day == 24 || rng.nextDouble() < 0.06);
    if (isExpensiveDay) {
      final superAmount = 450000 + (rng.nextInt(15) * 10000);
      final petroAmount = 180000 + (rng.nextInt(5) * 10000);
      await txRepo.add(
        type: TxType.expense,
        amount: superAmount,
        categoryId: comida.id,
        merchant: 'Superseis',
        occurredAt: DateTime(current.year, current.month, current.day, 11, 30),
      );
      await txRepo.add(
        type: TxType.expense,
        amount: petroAmount,
        categoryId: transporte.id,
        merchant: 'Petrobras',
        occurredAt: DateTime(current.year, current.month, current.day, 17, 15),
      );
    } else {
      final txCount = 1 + rng.nextInt(3);
      for (var i = 0; i < txCount; i++) {
        final tpl = expenseTemplates[rng.nextInt(expenseTemplates.length)];
        final span = (tpl.max - tpl.min) ~/ 1000;
        final raw = span > 0 ? tpl.min + (rng.nextInt(span + 1) * 1000) : tpl.min;
        final hour = 8 + rng.nextInt(14);
        final minute = rng.nextInt(60);

        await txRepo.add(
          type: TxType.expense,
          amount: raw,
          categoryId: tpl.category.id,
          merchant: tpl.merchant,
          occurredAt:
              DateTime(current.year, current.month, current.day, hour, minute),
        );
      }
    }

    current = current.add(const Duration(days: 1));
  }
}
