import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/transactions/data/categories_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late AppDatabase db;
  late CategoriesRepository catRepo;
  late TransactionsRepository txRepo;

  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() async {
    setLocalZone('America/Asuncion');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    catRepo = CategoriesRepository(db);
    txRepo = TransactionsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('gasto a las 23:30 en Asunción cuenta en su día local', () async {
    final expenses = await catRepo.watchActive(CategoryKind.expense).first;
    final comida = expenses.firstWhere((c) => c.name == 'Comida').id;

    final local = tz.TZDateTime(tz.getLocation(kFallbackZone), 2026, 10, 31, 23, 30);
    await txRepo.add(
      type: TxType.expense,
      amount: 15000,
      categoryId: comida,
      occurredAt: local.toUtc(),
    );

    expect(await txRepo.watchDailyExpenseTotals(2026, 10).first, {31: 15000});
    expect(await txRepo.watchMonthTotal(2026, 10, TxType.expense).first, 15000);
    expect(await txRepo.watchMonthTotal(2026, 11, TxType.expense).first, 0);
  });

  test('mes vacío devuelve 0 y mapas vacíos', () async {
    expect(await txRepo.watchMonthTotal(2026, 2, TxType.expense).first, 0);
    expect(await txRepo.watchDailyExpenseTotals(2026, 2).first, isEmpty);
    expect(await txRepo.watchMonthCategoryTotals(2026, 2).first, isEmpty);
  });

  test('categoría archivada: fuera de la grilla, visible en sus movimientos', () async {
    final expenses = await catRepo.watchActive(CategoryKind.expense).first;
    final ocio = expenses.firstWhere((c) => c.name == 'Ocio').id;
    final now = DateTime.utc(2026, 10, 8, 12, 0);

    final id = await txRepo.add(
      type: TxType.expense,
      amount: 5000,
      categoryId: ocio,
      occurredAt: now,
    );
    await catRepo.archive(ocio);

    final activeExpenses = await catRepo.watchActive(CategoryKind.expense).first;
    expect(activeExpenses.map((c) => c.id), isNot(contains(ocio)));

    final recent = await txRepo.watchRecent().first;
    expect(recent.firstWhere((v) => v.tx.id == id).category.id, ocio);
  });

  test('softDelete oculta, restore devuelve, restore doble no duplica', () async {
    final expenses = await catRepo.watchActive(CategoryKind.expense).first;
    final transporte = expenses.firstWhere((c) => c.name == 'Transporte').id;
    final now = DateTime.utc(2026, 10, 8, 12, 0);

    final id = await txRepo.add(
      type: TxType.expense,
      amount: 28500,
      categoryId: transporte,
      occurredAt: now,
    );

    await txRepo.softDelete(id);
    expect(await txRepo.watchRecent().first, isEmpty);

    await txRepo.restore(id);
    await txRepo.restore(id);
    final recent = await txRepo.watchRecent().first;
    expect(recent, hasLength(1));
    expect(recent.single.tx.id, id);
  });

  test('monto 0 o negativo se rechaza', () {
    final now = DateTime.utc(2026, 10, 8, 12, 0);
    expect(
      () => txRepo.add(
        type: TxType.expense,
        amount: 0,
        categoryId: 'cat-dummy',
        occurredAt: now,
      ),
      throwsArgumentError,
    );
    expect(
      () => txRepo.add(
        type: TxType.expense,
        amount: -500,
        categoryId: 'cat-dummy',
        occurredAt: now,
      ),
      throwsArgumentError,
    );
  });

  test('watchFiltered busca en nota y comercio sin distinguir mayúsculas', () async {
    final expenses = await catRepo.watchActive(CategoryKind.expense).first;
    final hogar = expenses.firstWhere((c) => c.name == 'Hogar').id;
    final now = DateTime.utc(2026, 10, 8, 12, 0);

    await txRepo.add(
      type: TxType.expense,
      amount: 150000,
      categoryId: hogar,
      occurredAt: now,
      merchant: 'Superseis Los Laureles',
      note: 'Compras de la semana',
    );

    final resultMerchant = await txRepo.watchFiltered(query: 'super').first;
    expect(resultMerchant, hasLength(1));
    expect(resultMerchant.single.tx.merchant, 'Superseis Los Laureles');

    final resultNote = await txRepo.watchFiltered(query: 'COMPRAS').first;
    expect(resultNote, hasLength(1));

    final resultNone = await txRepo.watchFiltered(query: 'noexiste').first;
    expect(resultNone, isEmpty);
  });

  test('watchMonthCategoryTotals agrupa gastos de mayor a menor', () async {
    final expenses = await catRepo.watchActive(CategoryKind.expense).first;
    final comida = expenses.firstWhere((c) => c.name == 'Comida').id;
    final hogar = expenses.firstWhere((c) => c.name == 'Hogar').id;
    final dt = tz.TZDateTime(tz.getLocation(kFallbackZone), 2026, 10, 15, 14, 0).toUtc();

    await txRepo.add(type: TxType.expense, amount: 20000, categoryId: comida, occurredAt: dt);
    await txRepo.add(type: TxType.expense, amount: 80000, categoryId: hogar, occurredAt: dt);
    await txRepo.add(type: TxType.expense, amount: 15000, categoryId: comida, occurredAt: dt);

    final totals = await txRepo.watchMonthCategoryTotals(2026, 10).first;
    expect(totals, hasLength(2));
    expect(totals[0].category.id, hogar);
    expect(totals[0].total, 80000);
    expect(totals[1].category.id, comida);
    expect(totals[1].total, 35000);
  });

  test('watchDay filtra movimientos de un día local específico', () async {
    final expenses = await catRepo.watchActive(CategoryKind.expense).first;
    final comida = expenses.firstWhere((c) => c.name == 'Comida').id;

    final day1 = tz.TZDateTime(tz.getLocation(kFallbackZone), 2026, 10, 15, 10, 0);
    final day2 = tz.TZDateTime(tz.getLocation(kFallbackZone), 2026, 10, 16, 10, 0);

    await txRepo.add(type: TxType.expense, amount: 12000, categoryId: comida, occurredAt: day1.toUtc());
    await txRepo.add(type: TxType.expense, amount: 18000, categoryId: comida, occurredAt: day2.toUtc());

    final day1Results = await txRepo.watchDay(DateTime(2026, 10, 15)).first;
    expect(day1Results, hasLength(1));
    expect(day1Results.single.tx.amount, 12000);
  });

  test('con setLocalZone Europe/Madrid un gasto a las 23:30 de Madrid cuenta en el día 31 de Madrid', () async {
    setLocalZone('Europe/Madrid');
    final expenses = await catRepo.watchActive(CategoryKind.expense).first;
    final comida = expenses.firstWhere((c) => c.name == 'Comida').id;
    final madridLoc = tz.getLocation('Europe/Madrid');
    final local = tz.TZDateTime(madridLoc, 2026, 10, 31, 23, 30);

    await txRepo.add(
      type: TxType.expense,
      amount: 25000,
      categoryId: comida,
      occurredAt: local.toUtc(),
    );

    expect(await txRepo.watchDailyExpenseTotals(2026, 10).first, {31: 25000});
    expect(await txRepo.watchMonthTotal(2026, 10, TxType.expense).first, 25000);
  });

  test('watchTotalSince suma movimientos desde el inicio del día local dado', () async {
    final expenses = await catRepo.watchActive(CategoryKind.expense).first;
    final incomes = await catRepo.watchActive(CategoryKind.income).first;
    final comida = expenses.firstWhere((c) => c.name == 'Comida').id;
    final sueldo = incomes.firstWhere((c) => c.name == 'Sueldo').id;

    // Movimiento anterior al día de corte (29/09)
    await txRepo.add(
      type: TxType.income,
      amount: 1000000,
      categoryId: sueldo,
      occurredAt: tz.TZDateTime(tz.getLocation(kFallbackZone), 2026, 9, 29, 12, 0).toUtc(),
    );
    // Movimiento en el día de corte (30/09)
    await txRepo.add(
      type: TxType.income,
      amount: 3500000,
      categoryId: sueldo,
      occurredAt: tz.TZDateTime(tz.getLocation(kFallbackZone), 2026, 9, 30, 8, 30).toUtc(),
    );
    // Gastos entre el día de corte y hoy
    await txRepo.add(
      type: TxType.expense,
      amount: 455000,
      categoryId: comida,
      occurredAt: tz.TZDateTime(tz.getLocation(kFallbackZone), 2026, 9, 30, 20, 0).toUtc(),
    );
    await txRepo.add(
      type: TxType.expense,
      amount: 2000000,
      categoryId: comida,
      occurredAt: tz.TZDateTime(tz.getLocation(kFallbackZone), 2026, 10, 5, 14, 0).toUtc(),
    );

    final cutDay = DateTime(2026, 9, 30);
    expect(await txRepo.watchTotalSince(cutDay, TxType.income).first, 3500000);
    expect(await txRepo.watchTotalSince(cutDay, TxType.expense).first, 2455000);
  });
}
