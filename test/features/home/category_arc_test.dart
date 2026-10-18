import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/home/ui/category_arc.dart';
import 'package:pockt/features/home/ui/home_screen.dart';
import 'package:pockt/features/income/domain/period_summary.dart';
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
    SafeToSpend? safeOverride,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        safeToSpendProvider.overrideWith((ref) => Stream.value(safeOverride ?? testSafe)),
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
      expect(find.textContaining('Gastado en octubre'), findsOneWidget);
      expect(find.text('Gs. 400.000'), findsOneWidget);

      // Expandir chips al tocar el arco/título
      await tester.tap(find.textContaining('Gastado en octubre'));
      await tester.pumpAndSettle();

      // Chips de categoría: nombre y %, sin montos
      expect(find.text('Comida'), findsOneWidget);
      expect(find.text('75 %'), findsOneWidget);
      expect(find.text('Gs. 300.000'), findsNothing);

      expect(find.text('Transporte'), findsOneWidget);
      expect(find.text('25 %'), findsOneWidget);
      expect(find.text('Gs. 100.000'), findsNothing);
    });

    testWidgets('tocar un chip de categoría resalta el tramo y muestra su monto en el centro; tocar de nuevo vuelve al total', (tester) async {
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

      // Expandir chips al tocar el título
      await tester.tap(find.textContaining('Gastado en octubre'));
      await tester.pumpAndSettle();

      // Tocar chip "Comida" -> muestra monto de Comida en el centro
      await tester.tap(find.text('Comida'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Comida en octubre'), findsOneWidget);
      expect(find.text('Gs. 300.000'), findsOneWidget);
      expect(find.text('75 % de lo gastado'), findsOneWidget);

      // Tocar de nuevo "Comida" -> vuelve al total del mes
      await tester.tap(find.text('Comida'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Gastado en octubre'), findsOneWidget);
      expect(find.text('Gs. 400.000'), findsOneWidget);
      expect(find.text('Gs. 300.000'), findsNothing);
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

    testWidgets('CompactSafeToSpendCard unifica permitido, gastos de hoy y la línea del período', (tester) async {
      final now = DateTime(2026, 10, 15, 12, 0);

      await tester.pumpWidget(
        createTestHost(
          overrides: [
            homePeriodSummaryProvider(now).overrideWithValue(
              HomePeriodSummary(
                schedule: IncomeSchedule(
                  id: 's-1',
                  mode: 'biweekly',
                  payDays: '[15, -1]',
                  payDayRules: '["either", "previous"]',
                  paySplitPercents: '[50, 50]',
                  categoryId: 'cat-salary',
                  effectiveFrom: DateTime(2026, 9, 1),
                ),
                periodLine: PeriodLine(
                  label: '2ª quincena',
                  remaining: 820000,
                  daysToNextPay: 14,
                  nextPayDate: DateTime(2026, 10, 31),
                  periodStartDate: DateTime(2026, 10, 15),
                ),
              ),
            ),
          ],
          child: CompactSafeToSpendCard(nowLocal: now),
        ),
      );
      await tester.pumpAndSettle();

      // Fila 1: Podés gastar hoy + monto
      expect(find.text('Podés gastar hoy'), findsOneWidget);
      expect(find.text('Gs. 125.800'), findsOneWidget);

      // Gastos de hoy > 0: barrita y texto gastaste hoy presentes
      expect(find.text('gastaste hoy Gs. 48.500'), findsOneWidget);

      // Fila 2: period-line unificada dentro de la tarjeta
      expect(find.byKey(const ValueKey('period-line')), findsOneWidget);
      expect(find.textContaining('2ª quincena'), findsOneWidget);
      expect(find.textContaining('Gs. 820.000'), findsOneWidget);
    });

    testWidgets('CompactSafeToSpendCard sin gastos hoy (Gs. 0) oculta barrita y texto "gastaste hoy"', (tester) async {
      final now = DateTime(2026, 10, 15, 12, 0);

      await tester.pumpWidget(
        createTestHost(
          safeOverride: SafeToSpend(
            amount: 150000,
            todayAllowance: 150000,
            spentToday: 0,
            quedan: 2251500,
            pendingRecurring: 0,
            proratedGoals: 0,
            daysUntilPay: 13,
            targetDate: DateTime(2026, 10, 31),
            hasIncomeSchedule: true,
          ),
          overrides: [
            homePeriodSummaryProvider(now).overrideWithValue(
              HomePeriodSummary(
                schedule: IncomeSchedule(
                  id: 's-1',
                  mode: 'biweekly',
                  payDays: '[15, -1]',
                  payDayRules: '["either", "previous"]',
                  paySplitPercents: '[50, 50]',
                  categoryId: 'cat-salary',
                  effectiveFrom: DateTime(2026, 9, 1),
                ),
                periodLine: PeriodLine(
                  label: '2ª quincena',
                  remaining: 1500000,
                  daysToNextPay: 14,
                  nextPayDate: DateTime(2026, 10, 31),
                  periodStartDate: DateTime(2026, 10, 15),
                ),
              ),
            ),
          ],
          child: CompactSafeToSpendCard(nowLocal: now),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Podés gastar hoy'), findsOneWidget);
      expect(find.text('Gs. 150.000'), findsOneWidget);

      // Con Gs. 0 gastados hoy: NO muestra barrita ni texto "gastaste hoy"
      expect(find.textContaining('gastaste hoy'), findsNothing);

      // Fila 2: period-line sigue presente
      expect(find.byKey(const ValueKey('period-line')), findsOneWidget);
      expect(find.textContaining('Gs. 1.500.000'), findsOneWidget);
    });

    testWidgets('CategoryArc en anchos 360 dp y 412 dp: bloque central elevado 16-20 dp sin tocar tramos ni con subetiqueta', (tester) async {
      final now = DateTime(2026, 10, 15, 12, 0);
      final cats = (await tester.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
      final comida = cats.firstWhere((c) => c.name == 'Comida');
      final transporte = cats.firstWhere((c) => c.name == 'Transporte');

      await tester.runAsync(() async {
        await txRepo.add(
          type: TxType.expense,
          amount: 350000,
          categoryId: comida.id,
          occurredAt: DateTime(2026, 10, 5, 12, 0),
        );
        await txRepo.add(
          type: TxType.expense,
          amount: 150000,
          categoryId: transporte.id,
          occurredAt: DateTime(2026, 10, 6, 12, 0),
        );
      });

      for (final width in [360.0, 412.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestHost(
            child: SingleChildScrollView(
              child: CategoryArc(
                key: ValueKey('arc-$width'),
                year: 2026,
                month: 10,
                nowLocal: now,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final arcPaint = find.byType(CustomPaint).first;
        final arcRect = tester.getRect(arcPaint);
        final radius = (width / 2) - 24;
        final cy = arcRect.top + radius + 14;
        final cx = arcRect.left + width / 2;
        final center = Offset(cx, cy);
        final innerRadius = radius - 6.0;

        // Estado normal: bloque elevado unos 16-20 dp respecto al fondo (bottom: 28 vs 10)
        final amountBottom = tester.getBottomLeft(find.text('Gs. 500.000')).dy;
        final clearanceFromBottom = arcRect.bottom - amountBottom;
        expect(clearanceFromBottom, greaterThanOrEqualTo(24.0));

        // Verificar que las 4 esquinas del título y monto no tocan el arco
        for (final textFinder in [find.textContaining('Gastado en octubre'), find.text('Gs. 500.000')]) {
          final rect = tester.getRect(textFinder);
          final corners = [
            rect.topLeft,
            rect.topRight,
            rect.bottomLeft,
            rect.bottomRight,
          ];
          for (final corner in corners) {
            final dist = (corner - center).distance;
            expect(dist, lessThan(innerRadius - 8.0));
          }
        }

        // Expandir chips al tocar el título
        await tester.tap(find.textContaining('Gastado en octubre'));
        await tester.pumpAndSettle();

        // Tocar chip de categoría para mostrar la subetiqueta (ej. "70 % de lo gastado")
        await tester.tap(find.text('Comida'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Comida en octubre'), findsOneWidget);
        expect(find.text('Gs. 350.000'), findsOneWidget);
        expect(find.text('70 % de lo gastado'), findsOneWidget);

        // Verificar que con subetiqueta ningún texto toca los tramos del arco
        for (final textFinder in [
          find.textContaining('Comida en octubre'),
          find.text('Gs. 350.000'),
          find.text('70 % de lo gastado'),
        ]) {
          final rect = tester.getRect(textFinder);
          final corners = [
            rect.topLeft,
            rect.topRight,
            rect.bottomLeft,
            rect.bottomRight,
          ];
          for (final corner in corners) {
            final dist = (corner - center).distance;
            expect(dist, lessThan(innerRadius - 8.0));
          }
        }
      }
    });

    testWidgets('alineación: bordes de Podés gastar hoy y period-line coinciden, y primer chip comparte borde izquierdo con la tarjeta', (tester) async {
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
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            safeToSpendProvider.overrideWith((ref) => Stream.value(testSafe)),
            homePeriodSummaryProvider(now).overrideWithValue(
              HomePeriodSummary(
                schedule: IncomeSchedule(
                  id: 's-1',
                  mode: 'biweekly',
                  payDays: '[15, -1]',
                  payDayRules: '["either", "previous"]',
                  paySplitPercents: '[50, 50]',
                  categoryId: 'cat-salary',
                  effectiveFrom: DateTime(2026, 9, 1),
                ),
                periodLine: PeriodLine(
                  label: '2ª quincena',
                  remaining: 820000,
                  daysToNextPay: 14,
                  nextPayDate: DateTime(2026, 10, 31),
                  periodStartDate: DateTime(2026, 10, 15),
                ),
              ),
            ),
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

      // 1. En la tarjeta: 'Podés gastar hoy' y 'period-line' comparten exactamente el borde izquierdo
      final podesGastarHoyLeft = tester.getTopLeft(find.text('Podés gastar hoy')).dx;
      final periodLineLeft = tester.getTopLeft(find.byKey(const ValueKey('period-line'))).dx;
      expect(periodLineLeft, equals(podesGastarHoyLeft));

      // El monto de Podés gastar hoy y 'period-line-payday' comparten el borde derecho
      final allowanceRight = tester.getTopRight(find.text('Gs. 125.800')).dx;
      final paydayRight = tester.getTopRight(find.byKey(const ValueKey('period-line-payday'))).dx;
      expect(paydayRight, equals(allowanceRight));

      // 2. El primer chip (Comida) comparte el borde izquierdo con el contenido de la tarjeta
      await tester.tap(find.textContaining('Gastado en octubre'));
      await tester.pumpAndSettle();

      final firstChip = find.ancestor(
        of: find.text('Comida'),
        matching: find.byType(Pressable),
      ).first;
      final firstChipLeft = tester.getTopLeft(firstChip).dx;
      expect(firstChipLeft, equals(podesGastarHoyLeft));

      // 3. El arco queda centrado respecto del mismo ancho y eje que las tarjetas
      final arcCenterX = tester.getCenter(find.byType(CategoryArc)).dx;
      final cardCenterX = tester.getCenter(find.byType(CompactSafeToSpendCard)).dx;
      expect(arcCenterX, equals(cardCenterX));
    });
  });
}
