import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/features/splash/ui/pockt_splash.dart';

void main() {
  setUp(() {
    PocktSplash.resetForTesting();
  });

  testWidgets('con disableAnimations no hay animación y el contenido aparece directo', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: const PocktSplash(
            child: Scaffold(
              body: Center(child: Text('Pantalla de Inicio')),
            ),
          ),
        ),
      ),
    );

    // Con disableAnimations el splash no se anima y el contenido se ve de inmediato
    expect(find.text('Pantalla de Inicio'), findsOneWidget);
    // El splash overlay no bloquea ni está en juego
    expect(PocktSplash.hasShownSplash, isTrue);
  });

  testWidgets('tocar la pantalla saltea la animación y muestra el contenido', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: const PocktSplash(
          child: Scaffold(
            body: Center(child: Text('Pantalla de Inicio')),
          ),
        ),
      ),
    );

    // Al inicio (t=0) está animando el splash
    await tester.pump(const Duration(milliseconds: 100));

    // Tocamos la pantalla
    await tester.tap(find.byType(PocktSplash));
    await tester.pumpAndSettle();

    // El contenido es visible
    expect(find.text('Pantalla de Inicio'), findsOneWidget);
  });

  testWidgets('al terminar la animación el contenido queda visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: const PocktSplash(
          child: Scaffold(
            body: Center(child: Text('Pantalla de Inicio')),
          ),
        ),
      ),
    );

    // Avanzamos el tiempo de la animación completa (~1100 ms)
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de Inicio'), findsOneWidget);
  });

  testWidgets('solo se ejecuta en arranque en frío: un segundo montaje muestra el contenido directo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: const PocktSplash(
          child: Scaffold(
            body: Center(child: Text('Pantalla de Inicio')),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Pantalla de Inicio'), findsOneWidget);

    // Montar de nuevo otro PocktSplash
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: const PocktSplash(
          child: Scaffold(
            body: Center(child: Text('Segunda Vista')),
          ),
        ),
      ),
    );

    // Debe mostrarse de inmediato sin esperar 1100ms
    expect(find.text('Segunda Vista'), findsOneWidget);
  });
}
