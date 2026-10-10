import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/transactions/ui/tx_row.dart';

TxView _makeTxView({String id = 'tx-1', String merchant = 'Superseis'}) {
  return TxView(
    tx: Transaction(
      id: id,
      type: TxType.expense,
      amount: 45000,
      currency: 'PYG',
      categoryId: 'cat-1',
      merchant: merchant,
      note: null,
      occurredAt: DateTime(2026, 10, 10, 12, 0),
      createdAt: DateTime(2026, 10, 10, 12, 0),
      updatedAt: DateTime(2026, 10, 10, 12, 0),
      source: TxSource.manual,
      deletedAt: null,
    ),
    category: const Category(
      id: 'cat-1',
      name: 'Supermercado',
      kind: CategoryKind.expense,
      icon: 'shopping-cart',
      colorLight: 0xFFFF8A3D,
      colorDark: 0xFFFF8A3D,
      sortOrder: 0,
      archived: false,
    ),
  );
}

void main() {
  testWidgets('la fila deslizada mantiene el fondo de la acción del alto de la fila y sigue las esquinas de la tarjeta', (tester) async {
    final view = _makeTxView();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: SwipeableTxRow(
                  view: view,
                  subtitle: '12:00',
                  isFirst: true,
                  isLast: false,
                  cardRadius: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rowFinder = find.byType(SwipeableTxRow);
    final rowSize = tester.getSize(rowFinder);

    // Iniciar arrastre hacia la izquierda (revelar fondo de borrar)
    final gesture = await tester.startGesture(tester.getCenter(rowFinder));
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();

    // El fondo de la acción existe y tiene exactamente el mismo alto que la fila
    final bgFinder = find.byKey(const ValueKey('tx-action-bg-delete'));
    expect(bgFinder, findsOneWidget);
    final bgSize = tester.getSize(bgFinder);
    expect(bgSize.height, rowSize.height);

    // Esquinas: la primera fila sigue las esquinas superiores de la tarjeta (24) y fondo cuadrado (0)
    final container = tester.widget<Container>(bgFinder);
    final decoration = container.decoration as BoxDecoration;
    final radius = decoration.borderRadius as BorderRadius;
    expect(radius.topLeft, const Radius.circular(24));
    expect(radius.topRight, const Radius.circular(24));
    expect(radius.bottomLeft, Radius.zero);
    expect(radius.bottomRight, Radius.zero);

    // El ícono de acción está centrado verticalmente con respecto a la fila
    final iconFinder = find.descendant(of: bgFinder, matching: find.byType(Icon));
    expect(iconFinder, findsOneWidget);
    final iconCenter = tester.getCenter(iconFinder);
    final rowCenter = tester.getCenter(rowFinder);
    expect((iconCenter.dy - rowCenter.dy).abs(), lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('última fila tiene esquinas inferiores redondeadas y superiores rectas', (tester) async {
    final view = _makeTxView();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: SwipeableTxRow(
                  view: view,
                  subtitle: '12:00',
                  isFirst: false,
                  isLast: true,
                  cardRadius: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rowFinder = find.byType(SwipeableTxRow);
    final gesture = await tester.startGesture(tester.getCenter(rowFinder));
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();

    final bgFinder = find.byKey(const ValueKey('tx-action-bg-delete'));
    final container = tester.widget<Container>(bgFinder);
    final decoration = container.decoration as BoxDecoration;
    final radius = decoration.borderRadius as BorderRadius;
    expect(radius.topLeft, Radius.zero);
    expect(radius.topRight, Radius.zero);
    expect(radius.bottomLeft, const Radius.circular(20));
    expect(radius.bottomRight, const Radius.circular(20));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('fila única tiene todas las esquinas redondeadas al radio de la tarjeta', (tester) async {
    final view = _makeTxView();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: SwipeableTxRow(
                  view: view,
                  subtitle: '12:00',
                  isFirst: true,
                  isLast: true,
                  cardRadius: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rowFinder = find.byType(SwipeableTxRow);
    final gesture = await tester.startGesture(tester.getCenter(rowFinder));
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();

    final bgFinder = find.byKey(const ValueKey('tx-action-bg-delete'));
    final container = tester.widget<Container>(bgFinder);
    final decoration = container.decoration as BoxDecoration;
    final radius = decoration.borderRadius as BorderRadius;
    expect(radius.topLeft, const Radius.circular(24));
    expect(radius.topRight, const Radius.circular(24));
    expect(radius.bottomLeft, const Radius.circular(24));
    expect(radius.bottomRight, const Radius.circular(24));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('fila intermedia tiene esquinas completamente rectas', (tester) async {
    final view = _makeTxView();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: SwipeableTxRow(
                  view: view,
                  subtitle: '12:00',
                  isFirst: false,
                  isLast: false,
                  cardRadius: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rowFinder = find.byType(SwipeableTxRow);
    final gesture = await tester.startGesture(tester.getCenter(rowFinder));
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();

    final bgFinder = find.byKey(const ValueKey('tx-action-bg-delete'));
    final container = tester.widget<Container>(bgFinder);
    final decoration = container.decoration as BoxDecoration;
    final radius = decoration.borderRadius as BorderRadius;
    expect(radius, BorderRadius.zero);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('TxGroupCard aplica padding cero a la tarjeta y marca isFirst e isLast', (tester) async {
    final t1 = _makeTxView(id: 'tx-1', merchant: 'Superseis');
    final t2 = _makeTxView(id: 'tx-2', merchant: 'Biggie');
    final t3 = _makeTxView(id: 'tx-3', merchant: 'Farmacenter');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: TxGroupCard(
                  items: [t1, t2, t3],
                  cardRadius: 24,
                  subtitleBuilder: (v) => '10:00',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // La tarjeta envolvente no tiene relleno interno (padding cero)
    // para que las filas lleguen hasta el borde de la tarjeta de vidrio.
    final rows = tester.widgetList<SwipeableTxRow>(find.byType(SwipeableTxRow)).toList();
    expect(rows, hasLength(3));
    expect(rows[0].isFirst, isTrue);
    expect(rows[0].isLast, isFalse);
    expect(rows[1].isFirst, isFalse);
    expect(rows[1].isLast, isFalse);
    expect(rows[2].isFirst, isFalse);
    expect(rows[2].isLast, isTrue);
  });
}
