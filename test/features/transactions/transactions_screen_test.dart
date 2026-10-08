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
import 'package:pockt/features/shell/ui/app_shell.dart';
import 'package:pockt/features/transactions/data/categories_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/transactions/ui/transactions_screen.dart';
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

  void usePhoneSize(WidgetTester t) {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
  }

  testWidgets('borrar y deshacer tras cambiar de pestaña', (t) async {
    usePhoneSize(t);
    final cats = (await t.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
    final id = (await t.runAsync(() => txRepo.add(
          type: TxType.expense,
          amount: 380000,
          categoryId: cats.firstWhere((c) => c.name == 'Hogar').id,
          merchant: 'Superseis',
          occurredAt: DateTime.now().toUtc(),
        )))!;

    await t.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(testDb)],
        child: MaterialApp(theme: buildDarkTheme(), home: const AppShell()),
      ),
    );
    await t.pumpAndSettle();

    // Deslizar y borrar en Inicio.
    final row = find.byKey(ValueKey('tx-row-$id'));
    expect(row, findsOneWidget);
    await Scrollable.ensureVisible(t.element(row), alignment: 0.5);
    await t.pumpAndSettle();
    await t.drag(row, const Offset(-500, 0));
    await t.pumpAndSettle();

    expect(find.text('Movimiento borrado'), findsOneWidget);
    final afterDelete = (await t.runAsync(() => txRepo.watchRecent().first))!;
    expect(afterDelete, isEmpty);

    // Ir a Movimientos: el aviso sigue vivo en el ScaffoldMessenger raíz.
    await t.tap(find.byKey(const ValueKey('tab-movimientos')));
    await t.pumpAndSettle();
    expect(find.text('Deshacer'), findsOneWidget);

    await t.tap(find.text('Deshacer'));
    await t.pumpAndSettle();

    final restored = (await t.runAsync(() => txRepo.watchRecent().first))!;
    expect(restored, hasLength(1));
    expect(restored.single.tx.id, id);
    // Aparece una sola vez en Movimientos.
    expect(find.text('Superseis'), findsOneWidget);
  });

  testWidgets('Movimientos agrupa por día y filtra por búsqueda', (t) async {
    usePhoneSize(t);
    final cats = (await t.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
    String cid(String name) => cats.firstWhere((c) => c.name == name).id;

    await t.runAsync(() async {
      await txRepo.add(type: TxType.expense, amount: 380000, categoryId: cid('Hogar'),
          merchant: 'Superseis', occurredAt: localToUtc(2026, 10, 8, 10, 0));
      await txRepo.add(type: TxType.expense, amount: 28500, categoryId: cid('Transporte'),
          merchant: 'Bolt', occurredAt: localToUtc(2026, 10, 7, 9, 3));
      await txRepo.add(type: TxType.expense, amount: 15000, categoryId: cid('Comida'),
          note: 'café', occurredAt: localToUtc(2026, 10, 5, 8, 12));
    });

    await t.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(testDb)],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: TransactionsScreen(nowLocal: DateTime(2026, 10, 8, 15, 0)),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Ayer'), findsOneWidget);
    expect(find.text('Lunes 5 de octubre'), findsOneWidget);
    expect(find.text('Superseis'), findsOneWidget);
    expect(find.text('Bolt'), findsOneWidget);

    await t.enterText(find.byKey(const ValueKey('tx-search')), 'super');
    await t.pumpAndSettle();

    expect(find.text('Superseis'), findsOneWidget);
    expect(find.text('Bolt'), findsNothing);
    expect(find.text('café'), findsNothing);
    expect(find.text('Ayer'), findsNothing);
  });
}
