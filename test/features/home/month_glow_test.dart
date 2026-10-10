import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/home/ui/month_glow.dart';

void main() {
  testWidgets('MonthGlow renderiza con color inicial y tamaño 470x470', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MonthGlow(color: Colors.red),
        ),
      ),
    );

    expect(find.byType(MonthGlow), findsOneWidget);
    final size = tester.getSize(find.byType(MonthGlow));
    expect(size.width, equals(470.0));
    expect(size.height, equals(470.0));
  });

  testWidgets('MonthGlow realiza fundido cruzado al cambiar de color y queda en el nuevo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MonthGlow(color: Colors.red),
        ),
      ),
    );

    // Cambiar a color azul
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MonthGlow(color: Colors.blue),
        ),
      ),
    );

    final glowFadeTransitions = find.descendant(
      of: find.byType(MonthGlow),
      matching: find.byType(FadeTransition),
    );

    // Durante la animación hay 2 FadeTransition activos en Stack (saliente y entrante)
    await tester.pump(const Duration(milliseconds: 300));
    expect(glowFadeTransitions, findsNWidgets(2));

    // Al finalizar la animación (~900 ms) el fundido termina y solo queda la capa actual
    await tester.pumpAndSettle();
    expect(glowFadeTransitions, findsNothing);
  });

  testWidgets('MonthGlow con animaciones deshabilitadas cambia inmediatamente', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: MonthGlow(color: Colors.red),
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: MonthGlow(color: Colors.blue),
          ),
        ),
      ),
    );

    final glowFadeTransitions = find.descendant(
      of: find.byType(MonthGlow),
      matching: find.byType(FadeTransition),
    );

    // No debe haber transiciones activas dentro de MonthGlow
    await tester.pump();
    expect(glowFadeTransitions, findsNothing);
  });
}
