import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/features/home/ui/today_arc.dart';

void main() {
  Widget host(Widget child, {double width = 360, double scale = 1}) =>
      MaterialApp(
        theme: buildDarkTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 800),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(width: width - 32, child: child),
            ),
          ),
        ),
      );

  testWidgets('normal: lo que queda hoy y cuánto gastaste', (tester) async {
    await tester.pumpWidget(
      host(const TodayArc(allowance: 125800, spent: 48500, reduceMotion: true)),
    );
    expect(find.text('Te quedan hoy'), findsOneWidget);
    expect(find.text('Gs. 77.300'), findsOneWidget);
    expect(find.text('gastaste Gs. 48.500 de Gs. 125.800'), findsOneWidget);
  });

  testWidgets('pasado del límite muestra el excedente', (tester) async {
    await tester.pumpWidget(
      host(
        const TodayArc(allowance: 100000, spent: 130000, reduceMotion: true),
      ),
    );
    expect(find.text('Te pasaste hoy'), findsOneWidget);
    expect(find.text('Gs. 30.000'), findsOneWidget);
  });

  testWidgets('sin margen en el período', (tester) async {
    await tester.pumpWidget(
      host(const TodayArc(allowance: -20000, spent: 0, reduceMotion: true)),
    );
    expect(find.text('No queda margen hasta el cobro'), findsOneWidget);
  });

  testWidgets('ocultar montos tapa todos los números', (tester) async {
    await tester.pumpWidget(
      host(
        const TodayArc(
          allowance: 125800,
          spent: 48500,
          obscure: true,
          reduceMotion: true,
        ),
      ),
    );
    expect(find.textContaining('Gs.'), findsNothing);
    expect(find.text('••••'), findsOneWidget);
  });

  testWidgets('letra 1,3 en 360 px no desborda', (tester) async {
    await tester.pumpWidget(
      host(
        const TodayArc(allowance: 1258000, spent: 485000, reduceMotion: true),
        scale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('lectores de pantalla oyen la frase completa', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(const TodayArc(allowance: 125800, spent: 48500, reduceMotion: true)),
    );
    expect(
      find.bySemanticsLabel(
        'Te quedan hoy Gs. 77.300, gastaste Gs. 48.500 de Gs. 125.800',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
