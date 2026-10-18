import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/home/ui/category_arc.dart';
import 'package:pockt/features/home/ui/home_screen.dart';
import 'package:pockt/features/safe_to_spend/domain/safe_to_spend.dart';
import 'package:pockt/features/transactions/data/categories_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  late AppDatabase db;
  late CategoriesRepository catRepo;
  late TransactionsRepository txRepo;

  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() async {
    setLocalZone('America/Asuncion');
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    catRepo = CategoriesRepository(db);
    txRepo = TransactionsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  final testSafe = SafeToSpend(
    amount: 125800,
    todayAllowance: 125800,
    spentToday: 48500,
    quedan: 2251500,
    pendingRecurring: 0,
    proratedGoals: 0,
    daysUntilPay: 13,
    targetDate: DateTime(2026, 10, 31),
    hasIncomeSchedule: true,
  );

  Widget createTestHost({
    required Widget child,
    List<dynamic> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        safeToSpendProvider.overrideWith((ref) => Stream.value(testSafe)),
        ...overrides,
      ],
      child: MaterialApp(
        theme: buildDarkTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  group('CategoryArc & Inicio por categoría', () {
    test('default de homeHeadline es monthSpent', () {
      expect(HomeHeadline.parse(null), equals(HomeHeadline.monthSpent));
      expect(HomeHeadline.parse(''), equals(HomeHeadline.monthSpent));
      expect(HomeHeadline.parse('monthSpent'), equals(HomeHeadline.monthSpent));
      expect(HomeHeadline.parse('safeToSpend'), equals(HomeHeadline.safeToSpend));
    });

    testWidgets('HomeScreen por defecto muestra CategoryArc en lugar de TodayArc', (tester) async {
      final now = DateTime(2026, 10, 15, 12, 0);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            safeToSpendProvider.overrideWith((ref) => Stream.value(testSafe)),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: HomeScreen(
              initialYear: 2026,
              initialMonth: 10,
              nowLocal: now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CategoryArc), findsOneWidget);
    });

    testWidgets('mes sin gasto: muestra pista vacía y texto "Todavía no gastaste en octubre"', (tester) async {
      final now = DateTime(2026, 10, 15, 12, 0);

      await tester.pumpWidget(
        createTestHost(
          child: CategoryArc(
            year: 2026,
            month: 10,
            nowLocal: now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Todavía no gastaste en octubre'), findsOneWidget);
      expect(find.text('Gastado en octubre'), findsNothing);
    });

    testWidgets('con gastos: muestra centro con total, % y lista de categorías', (tester) async {
      final now = DateTime(2026, 10, 15, 12, 0);
      final cats = (await tester.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
      final comida = cats.firstWhere((c) => c.name == 'Comida');
      final transporte = cats.firstWhere((c) => c.name == 'Transporte');

      await tester.runAsync(() async {
        await txRepo.add(
          type: TxType.expense,
          amount: 300000,
          categoryId: comida.id,
          occurredAt: DateTime(2026, 10, 5, 12, 0),
        );
        await txRepo.add(
          type: TxType.expense,
          amount: 100000,
          categoryId: transporte.id,
          occurredAt: DateTime(2026, 10, 6, 12, 0),
        );
      });

      await tester.pumpWidget(
        createTestHost(
          child: CategoryArc(
            year: 2026,
            month: 10,
            nowLocal: now,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Centro
      expect(find.text('Gastado en octubre'), findsOneWidget);
      expect(find.text('Gs. 400.000'), findsOneWidget);

      // Filas de categoría
      expect(find.text('Comida'), findsOneWidget);
      expect(find.text('75 %'), findsOneWidget);
      expect(find.text('Gs. 300.000'), findsOneWidget);

      expect(find.text('Transporte'), findsOneWidget);
      expect(find.text('25 %'), findsOneWidget);
      expect(find.text('Gs. 100.000'), findsOneWidget);
    });

    testWidgets('tocar una fila de categoría resalta el tramo y actualiza el centro; tocar de nuevo vuelve al total', (tester) async {
      final now = DateTime(2026, 10, 15, 12, 0);
      final cats = (await tester.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
      final comida = cats.firstWhere((c) => c.name == 'Comida');
      final transporte = cats.firstWhere((c) => c.name == 'Transporte');

      await tester.runAsync(() async {
        await txRepo.add(
          type: TxType.expense,
          amount: 300000,
          categoryId: comida.id,
          occurredAt: DateTime(2026, 10, 5, 12, 0),
        );
        await txRepo.add(
          type: TxType.expense,
          amount: 100000,
          categoryId: transporte.id,
          occurredAt: DateTime(2026, 10, 6, 12, 0),
        );
      });

      await tester.pumpWidget(
        createTestHost(
          child: CategoryArc(
            year: 2026,
            month: 10,
            nowLocal: now,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tocar fila "Comida"
      await tester.tap(find.text('Comida'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Centro actualizado para Comida
      expect(find.text('Comida en octubre'), findsOneWidget);
      expect(find.text('75 % de lo gastado'), findsOneWidget);

      // Tocar de nuevo "Comida" -> vuelve al total
      await tester.tap(find.text('Comida'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Gastado en octubre'), findsOneWidget);
      expect(find.text('Gs. 400.000'), findsOneWidget);
    });

    testWidgets('respeta ocultar montos con ••••', (tester) async {
      final now = DateTime(2026, 10, 15, 12, 0);
      final cats = (await tester.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
      final comida = cats.firstWhere((c) => c.name == 'Comida');

      await tester.runAsync(() async {
        await txRepo.add(
          type: TxType.expense,
          amount: 500000,
          categoryId: comida.id,
          occurredAt: DateTime(2026, 10, 5, 12, 0),
        );
      });

      await tester.pumpWidget(
        createTestHost(
          overrides: [
            privacyHideAmountsProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: CategoryArc(
            year: 2026,
            month: 10,
            nowLocal: now,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('••••'), findsWidgets);
      expect(find.text('Gs. 500.000'), findsNothing);
    });

    testWidgets('CompactSafeToSpendCard muestra permitido, barrita y gastos de hoy', (tester) async {
      final now = DateTime(2026, 10, 15, 12, 0);

      await tester.pumpWidget(
        createTestHost(
          child: CompactSafeToSpendCard(nowLocal: now),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Podés gastar hoy'), findsOneWidget);
      expect(find.text('Gs. 125.800'), findsOneWidget);
      expect(find.text('gastaste hoy Gs. 48.500'), findsOneWidget);
    });

    testWidgets('sin esquema de cobro no muestra la línea de "quedan"', (tester) async {
      final now = DateTime(2026, 10, 15, 12, 0);
      final cats = (await tester.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
      final comida = cats.firstWhere((c) => c.name == 'Comida');

      await tester.runAsync(() async {
        await txRepo.add(
          type: TxType.expense,
          amount: 250000,
          categoryId: comida.id,
          occurredAt: DateTime(2026, 10, 5, 12, 0),
        );
      });

      await tester.pumpWidget(
        createTestHost(
          overrides: [
            homePeriodSummaryProvider(now).overrideWithValue(
              const HomePeriodSummary(),
            ),
          ],
          child: CategoryArc(
            year: 2026,
            month: 10,
            nowLocal: now,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Gastado en octubre'), findsOneWidget);
      expect(find.text('Gs. 250.000'), findsNWidgets(2));
      expect(find.textContaining('quedan'), findsNothing);
    });
  });
}
