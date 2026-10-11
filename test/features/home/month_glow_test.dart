import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  group('glowTint', () {
    const baseColor = Color(0xFF2196F3); // Azul

    test('tramo < 0.8 y null devuelve base sin mezcla', () {
      expect(glowTint(baseColor, null), equals(baseColor));
      expect(glowTint(baseColor, 0.0), equals(baseColor));
      expect(glowTint(baseColor, 0.5), equals(baseColor));
      expect(glowTint(baseColor, 0.79), equals(baseColor));
    });

    test('tramo 0.8 a 1.0 se mezcla gradualmente hacia ámbar', () {
      expect(glowTint(baseColor, 0.8), equals(baseColor));
      final at90 = glowTint(baseColor, 0.9);
      final expected90 = Color.lerp(baseColor, glowAmber, 0.5);
      expect(at90.toARGB32(), equals(expected90!.toARGB32()));
      expect(at90, isNot(equals(baseColor)));
      expect(at90, isNot(equals(glowAmber)));
      // A 0.99 está casi completamente en ámbar
      final at99 = glowTint(baseColor, 0.99);
      expect(at99, isNot(equals(baseColor)));
    });

    test('tramo >= 1.0 devuelve rojo-rosa', () {
      expect(glowTint(baseColor, 1.0), equals(glowRedPink));
      expect(glowTint(baseColor, 1.25), equals(glowRedPink));
      expect(glowTint(baseColor, 2.0), equals(glowRedPink));
    });
  });

  group('Aurora de dos manchas y pulso', () {
    testWidgets('MonthGlow contiene dos manchas con Transform dentro de RepaintBoundary', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonthGlow(color: Colors.red),
          ),
        ),
      );

      final boundaries = find.descendant(
        of: find.byType(MonthGlow),
        matching: find.byType(RepaintBoundary),
      );
      // Debe haber al menos dos manchas cacheadas con RepaintBoundary
      expect(boundaries, findsAtLeastNWidgets(2));

      final transforms = find.descendant(
        of: find.byType(MonthGlow),
        matching: find.byType(Transform),
      );
      expect(transforms, findsAtLeastNWidgets(2));
    });

    testWidgets('MonthGlow late una vez (escala 1.0 -> 1.08 -> 1.0) al activarse el pulso', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonthGlow(
              color: Colors.red,
              pulseTrigger: 0,
            ),
          ),
        ),
      );

      // Reconstruir con nuevo pulseTrigger
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonthGlow(
              color: Colors.red,
              pulseTrigger: 1,
            ),
          ),
        ),
      );

      // A mitad del pulso (~200 ms), la escala debe haber subido hacia ~1.08
      await tester.pump(const Duration(milliseconds: 200));

      final pulseTransformPeak = tester.widget<Transform>(
        find.descendant(
          of: find.byType(MonthGlow),
          matching: find.byType(Transform),
        ).first,
      );
      expect(pulseTransformPeak.transform.getMaxScaleOnAxis(), closeTo(1.08, 0.02));

      // Al completarse (~500 ms) vuelve a 1.0
      await tester.pump(const Duration(milliseconds: 350));
      final pulseTransformEnd = tester.widget<Transform>(
        find.descendant(
          of: find.byType(MonthGlow),
          matching: find.byType(Transform),
        ).first,
      );
      expect(pulseTransformEnd.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.01));
    });

    testWidgets('MonthGlow con animateDrift: true desplaza las manchas con el tiempo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonthGlow(
              color: Colors.red,
              animateDrift: true,
            ),
          ),
        ),
      );

      final initialTransforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(MonthGlow),
          matching: find.byType(Transform),
        ),
      ).toList();
      final initialOffset = initialTransforms[1].transform.getTranslation();

      // Avanzar el tiempo 11 segundos (mitad del ciclo de 22 s)
      await tester.pump(const Duration(seconds: 11));

      final updatedTransforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(MonthGlow),
          matching: find.byType(Transform),
        ),
      ).toList();
      final updatedOffset = updatedTransforms[1].transform.getTranslation();

      expect(updatedOffset.x, isNot(equals(initialOffset.x)));
    });

    testWidgets('MonthGlow con disableAnimations deja las manchas quietas', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: MonthGlow(
                color: Colors.red,
                animateDrift: true,
              ),
            ),
          ),
        ),
      );

      List<Offset> offsets() => tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(MonthGlow),
              matching: find.byType(Transform),
            ),
          )
          .map((t) {
            final v = t.transform.getTranslation();
            return Offset(v.x, v.y);
          })
          .toList();

      final before = offsets();
      await tester.pump(const Duration(seconds: 5));
      expect(offsets(), equals(before));
    });

    testWidgets('MonthGlow conectado a monthGlowPulseProvider reacciona al pulso al guardar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return Column(
                    children: [
                      MonthGlow(
                        color: Colors.blue,
                        pulseTrigger: ref.watch(monthGlowPulseProvider),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(monthGlowPulseProvider.notifier).pulse();
                        },
                        child: const Text('Guardar'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      final pulseTransformInitial = tester.widget<Transform>(
        find.descendant(
          of: find.byType(MonthGlow),
          matching: find.byType(Transform),
        ).first,
      );
      expect(pulseTransformInitial.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.01));

      // Tocar Guardar dispara el pulso
      await tester.tap(find.text('Guardar'));
      await tester.pump();

      // En el pico (~200 ms)
      await tester.pump(const Duration(milliseconds: 200));
      final pulseTransformPeak = tester.widget<Transform>(
        find.descendant(
          of: find.byType(MonthGlow),
          matching: find.byType(Transform),
        ).first,
      );
      expect(pulseTransformPeak.transform.getMaxScaleOnAxis(), closeTo(1.08, 0.02));

      // Al terminar (~500 ms) vuelve a 1.0
      await tester.pump(const Duration(milliseconds: 350));
      final pulseTransformEnd = tester.widget<Transform>(
        find.descendant(
          of: find.byType(MonthGlow),
          matching: find.byType(Transform),
        ).first,
      );
      expect(pulseTransformEnd.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.01));
    });
  });
}

