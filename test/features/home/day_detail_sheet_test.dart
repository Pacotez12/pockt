import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/home/ui/day_detail_sheet.dart';
import 'package:pockt/features/transactions/data/categories_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late AppDatabase testDb;
  late CategoriesRepository catRepo;
  late TransactionsRepository txRepo;

  DateTime localToUtc(int y, int m, int d, [int h = 12, int min = 0]) =>
      tz.TZDateTime(tz.getLocation('America/Asuncion'), y, m, d, h, min).toUtc();

  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() {
    setLocalZone('America/Asuncion');
    testDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    catRepo = CategoriesRepository(testDb);
    txRepo = TransactionsRepository(testDb);
  });

  tearDown(() async {
    await testDb.close();
  });

  testWidgets('detalle: total, múltiplo del promedio y categorías', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    final cats = (await t.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
    String id(String name) => cats.firstWhere((c) => c.name == name).id;

    await t.runAsync(() async {
      // Sábado 17: 612.000 en tres categorías.
      await txRepo.add(type: TxType.expense, amount: 380000, categoryId: id('Hogar'),
          merchant: 'Superseis', occurredAt: localToUtc(2026, 10, 17, 19, 40));
      await txRepo.add(type: TxType.expense, amount: 186000, categoryId: id('Comida'),
          occurredAt: localToUtc(2026, 10, 17, 21, 15));
      await txRepo.add(type: TxType.expense, amount: 46000, categoryId: id('Transporte'),
          occurredAt: localToUtc(2026, 10, 17, 9, 0));
      // Otros 3 días suman 108.000 → promedio (720.000 / 4) = 180.000.
      await txRepo.add(type: TxType.expense, amount: 50000, categoryId: id('Comida'),
          occurredAt: localToUtc(2026, 10, 3));
      await txRepo.add(type: TxType.expense, amount: 30000, categoryId: id('Comida'),
          occurredAt: localToUtc(2026, 10, 5));
      await txRepo.add(type: TxType.expense, amount: 28000, categoryId: id('Transporte'),
          occurredAt: localToUtc(2026, 10, 9));
    });

    await t.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(testDb)],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showDayDetail(context, DateTime(2026, 10, 17)),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();

    expect(find.text('Sábado 17 de octubre'), findsOneWidget);
    expect(find.text('Gs. 612.000'), findsOneWidget);
    expect(find.textContaining('3,4× tu día promedio'), findsOneWidget);
    expect(find.textContaining('tu día más caro del mes'), findsOneWidget);
    expect(find.text('En qué se fue'), findsOneWidget);
    // Barras por categoría y lista de movimientos del día.
    expect(find.text('Hogar'), findsWidgets);
    expect(find.text('Comida'), findsWidgets);
    expect(find.text('Transporte'), findsWidgets);
    expect(find.text('Superseis'), findsOneWidget);
    expect(find.text('380.000'), findsWidgets);
  });

  testWidgets('único día con gasto: sin múltiplo del promedio', (t) async {
    final cats = (await t.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
    await t.runAsync(() => txRepo.add(
          type: TxType.expense,
          amount: 15000,
          categoryId: cats.first.id,
          occurredAt: localToUtc(2026, 10, 17),
        ));

    await t.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(testDb)],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDayDetail(context, DateTime(2026, 10, 17)),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();

    expect(find.text('Gs. 15.000'), findsOneWidget);
    expect(find.textContaining('tu día promedio'), findsNothing);
  });
}
