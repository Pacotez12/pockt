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
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/goals/ui/goal_detail_screen.dart';
import 'package:pockt/features/transactions/data/categories_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/transactions/ui/transactions_screen.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late AppDatabase testDb;
  late CategoriesRepository catRepo;
  late TransactionsRepository txRepo;
  late GoalsRepository goalsRepo;
  late String comidaId;

  DateTime localToUtc(int y, int m, int d, [int h = 12, int min = 0]) =>
      tz.TZDateTime(
        tz.getLocation('America/Asuncion'),
        y,
        m,
        d,
        h,
        min,
      ).toUtc();

  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() async {
    setLocalZone('America/Asuncion');
    testDb = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    catRepo = CategoriesRepository(testDb);
    txRepo = TransactionsRepository(testDb);
    goalsRepo = GoalsRepository(testDb);

    final cats = await catRepo.watchActive(CategoryKind.expense).first;
    comidaId = cats.firstWhere((c) => c.name == 'Comida').id;
  });

  tearDown(() async {
    await testDb.close();
  });

  void usePhoneSize(WidgetTester t) {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(() => t.view.resetPhysicalSize());
    addTearDown(() => t.view.resetDevicePixelRatio());
    addTearDown(() => t.pumpWidget(const SizedBox()));
  }

  Widget buildApp(Widget child) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(testDb),
        transactionsRepositoryProvider.overrideWithValue(txRepo),
        goalsRepositoryProvider.overrideWithValue(goalsRepo),
      ],
      child: MaterialApp(theme: buildDarkTheme(), home: child),
    );
  }

  testWidgets(
    'aparece la fila de aporte en Movimientos tras aportar y no cambia total del mes',
    (t) async {
      usePhoneSize(t);

      final goalId = await goalsRepo.createGoal(
        name: 'PC Gamer',
        icon: 'laptop',
        targetAmount: 5000000,
      );

      // Gasto normal de 100.000
      await txRepo.add(
        type: TxType.expense,
        amount: 100000,
        categoryId: comidaId,
        occurredAt: localToUtc(2026, 10, 8, 11, 0),
        merchant: 'Almuerzo',
      );

      // Aporte a meta de 500.000
      await goalsRepo.addContribution(
        goalId: goalId,
        amount: 500000,
        date: localToUtc(2026, 10, 8, 12, 0),
        note: 'Ahorro quincena',
      );

      // Verificar que el total de gastos del mes sigue siendo 100.000
      final allTxs = await txRepo.getAllActive();
      final monthSpent = allTxs.fold<int>(
        0,
        (sum, item) =>
            sum + (item.tx.type == TxType.expense ? item.tx.amount : 0),
      );
      expect(monthSpent, equals(100000));

      // Renderizar Movimientos
      await t.pumpWidget(
        buildApp(TransactionsScreen(nowLocal: DateTime(2026, 10, 8, 15, 0))),
      );
      await t.pumpAndSettle();

      expect(find.text('Aporte · PC Gamer'), findsOneWidget);
      expect(find.text('500.000'), findsOneWidget);
      expect(find.text('Almuerzo'), findsOneWidget);
    },
  );

  testWidgets('retiro muestra "Retiro · {meta}"', (t) async {
    usePhoneSize(t);

    final goalId = await goalsRepo.createGoal(
      name: 'Viaje',
      icon: 'airplane-tilt',
      targetAmount: 2000000,
    );

    // Retiro de 150.000 (monto negativo)
    await goalsRepo.addContribution(
      goalId: goalId,
      amount: -150000,
      date: localToUtc(2026, 10, 8, 10, 0),
      note: 'Emergencia',
    );

    await t.pumpWidget(
      buildApp(TransactionsScreen(nowLocal: DateTime(2026, 10, 8, 15, 0))),
    );
    await t.pumpAndSettle();

    expect(find.text('Retiro · Viaje'), findsOneWidget);
    expect(find.text('150.000'), findsOneWidget);
  });

  testWidgets(
    'filtros ocultan aportes: por tipo y por búsqueda que no coincide',
    (t) async {
      usePhoneSize(t);

      final goalId = await goalsRepo.createGoal(
        name: 'Fondo Emergencia',
        icon: 'shield-check',
        targetAmount: 10000000,
      );

      await goalsRepo.addContribution(
        goalId: goalId,
        amount: 300000,
        date: localToUtc(2026, 10, 8, 10, 0),
      );

      await t.pumpWidget(
        buildApp(TransactionsScreen(nowLocal: DateTime(2026, 10, 8, 15, 0))),
      );
      await t.pumpAndSettle();

      expect(find.text('Aporte · Fondo Emergencia'), findsOneWidget);

      // Filtrar por Gastos -> no debe aparecer
      await t.tap(find.text('Gastos'));
      await t.pumpAndSettle();
      expect(find.text('Aporte · Fondo Emergencia'), findsNothing);

      // Volver a Todos -> debe aparecer
      await t.tap(find.text('Todos'));
      await t.pumpAndSettle();
      expect(find.text('Aporte · Fondo Emergencia'), findsOneWidget);

      // Buscar "Emergencia" -> debe aparecer
      await t.enterText(find.byKey(const ValueKey('tx-search')), 'Emergencia');
      await t.pumpAndSettle();
      expect(find.text('Aporte · Fondo Emergencia'), findsOneWidget);

      // Buscar "Super" -> no debe aparecer
      await t.enterText(find.byKey(const ValueKey('tx-search')), 'Super');
      await t.pumpAndSettle();
      expect(find.text('Aporte · Fondo Emergencia'), findsNothing);
    },
  );

  testWidgets('tocar la fila navega a GoalDetailScreen', (t) async {
    usePhoneSize(t);

    final goalId = await goalsRepo.createGoal(
      name: 'Guitarra',
      icon: 'gift',
      targetAmount: 1500000,
    );

    await goalsRepo.addContribution(
      goalId: goalId,
      amount: 200000,
      date: localToUtc(2026, 10, 8, 10, 0),
    );

    await t.pumpWidget(
      buildApp(TransactionsScreen(nowLocal: DateTime(2026, 10, 8, 15, 0))),
    );
    await t.pumpAndSettle();

    await t.tap(find.text('Aporte · Guitarra'));
    await t.pumpAndSettle();

    // Comprobar que navegó al detalle de la meta
    expect(find.byType(GoalDetailScreen), findsOneWidget);
    expect(find.text('Guitarra'), findsWidgets);
  });
}
