import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/reports/data/reports_repository.dart';
import 'package:pockt/features/reports/ui/reports_screen.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionsRepository txRepo;
  late ReportsRepository reportsRepo;
  late String comidaId;
  late String transporteId;

  setUp(() async {
    setLocalZone('America/Asuncion');
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    txRepo = TransactionsRepository(db);
    reportsRepo = ReportsRepository(db);

    final cats = await db.select(db.categories).get();
    comidaId = cats.firstWhere((c) => c.name == 'Comida').id;
    transporteId = cats.firstWhere((c) => c.name == 'Transporte').id;
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpReportsScreen(
    WidgetTester tester, {
    DateTime? nowLocal,
    int? initialYear,
    int? initialMonth,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          reportsRepositoryProvider.overrideWithValue(reportsRepo),
          transactionsRepositoryProvider.overrideWithValue(txRepo),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: ReportsScreen(
            nowLocal: nowLocal ?? DateTime(2026, 10, 15, 12, 0),
            initialYear: initialYear ?? 2026,
            initialMonth: initialMonth ?? 10,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('con datos muestra las 4 vistas al deslizar', (tester) async {
    // 1. Cargar datos para octubre 2026 y septiembre 2026
    await txRepo.add(
      type: TxType.expense,
      amount: 120000,
      categoryId: comidaId,
      merchant: 'Superseis',
      occurredAt: DateTime(2026, 10, 5, 12, 0),
    );
    await txRepo.add(
      type: TxType.expense,
      amount: 80000,
      categoryId: transporteId,
      merchant: 'Bolt',
      occurredAt: DateTime(2026, 10, 10, 12, 0),
    );
    // Septiembre: gasto 100.000 (para comparación: 200.000 vs 100.000 -> 100% más)
    await txRepo.add(
      type: TxType.expense,
      amount: 100000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 9, 5, 12, 0),
    );

    await pumpReportsScreen(tester);

    // Vista 1: Mes por categoría
    expect(find.text('Reportes'), findsOneWidget);
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Transporte'), findsOneWidget);

    // Deslizar a Vista 2: Evolución
    final pageView = find.byType(PageView);
    expect(pageView, findsOneWidget);
    await tester.drag(pageView, const Offset(-450, 0));
    await tester.pumpAndSettle();

    expect(find.text('Evolución'), findsAtLeastNWidgets(1));
    expect(find.byKey(const ValueKey('evolution-chart')), findsOneWidget);

    // Deslizar a Vista 3: Comparación
    await tester.drag(pageView, const Offset(-450, 0));
    await tester.pumpAndSettle();

    expect(find.text('Comparación'), findsAtLeastNWidgets(1));
    expect(find.textContaining('a esta altura'), findsOneWidget);

    // Deslizar a Vista 4: Por comercio
    await tester.drag(pageView, const Offset(-450, 0));
    await tester.pumpAndSettle();

    expect(find.text('Por comercio'), findsAtLeastNWidgets(1));
    expect(find.text('Superseis'), findsOneWidget);
    expect(find.text('Bolt'), findsOneWidget);
  });

  testWidgets('mes vacío muestra el estado vacío en cada vista (sin excepciones)', (tester) async {
    // Sin transacciones
    await pumpReportsScreen(tester);

    // Vista 1 vacía
    expect(find.text('Sin gastos este mes'), findsOneWidget);

    // Deslizar a Vista 2 vacía
    final pageView = find.byType(PageView);
    await tester.drag(pageView, const Offset(-450, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sin movimientos en este período'), findsOneWidget);

    // Deslizar a Vista 3 vacía
    await tester.drag(pageView, const Offset(-450, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sin datos para comparar'), findsOneWidget);

    // Deslizar a Vista 4 vacía
    await tester.drag(pageView, const Offset(-450, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sin comercios registrados este mes'), findsOneWidget);
  });

  testWidgets('tocar una categoría abre la lista filtrada', (tester) async {
    await txRepo.add(
      type: TxType.expense,
      amount: 150000,
      categoryId: comidaId,
      merchant: 'Superseis',
      note: 'Compras de la semana',
      occurredAt: DateTime(2026, 10, 5, 12, 0),
    );

    await pumpReportsScreen(tester);

    // Tocar la categoría Comida
    await tester.tap(find.text('Comida'));
    await tester.pumpAndSettle();

    // Se abre el detalle/hoja con los movimientos del mes de Comida
    expect(find.text('Compras de la semana'), findsOneWidget);
    expect(find.text('Superseis'), findsOneWidget);
  });

  testWidgets('en Comparación las tarjetas Mes actual / Mes anterior usan los tokens de diseño', (tester) async {
    await txRepo.add(
      type: TxType.expense,
      amount: 120000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 5, 12, 0),
    );
    await txRepo.add(
      type: TxType.expense,
      amount: 100000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 9, 5, 12, 0),
    );

    await pumpReportsScreen(tester);

    final pageView = find.byType(PageView);
    await tester.drag(pageView, const Offset(-450, 0));
    await tester.pumpAndSettle();
    await tester.drag(pageView, const Offset(-450, 0));
    await tester.pumpAndSettle();

    final pillFinder = find.ancestor(
      of: find.textContaining('Mes actual'),
      matching: find.byType(Container),
    ).first;

    final container = tester.widget<Container>(pillFinder);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, PocktColors.dark.glassFill);
    expect(decoration.border, Border.all(color: PocktColors.dark.glassBorder));
  });
}
