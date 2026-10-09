import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/design/wordmark.dart';

void main() {
  testWidgets('PocktWordmark renderiza texto pockt con Inter w800 y dot-orbe', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: const Scaffold(
          body: Center(
            child: PocktWordmark(size: 60),
          ),
        ),
      ),
    );

    // Texto pockt
    final textFinder = find.text('pockt');
    expect(textFinder, findsOneWidget);

    final textWidget = tester.widget<Text>(textFinder);
    expect(textWidget.style?.fontFamily, 'Inter');
    expect(textWidget.style?.fontWeight, FontWeight.w800);
    expect(textWidget.style?.fontSize, 60.0);
    expect(textWidget.style?.letterSpacing, -0.06 * 60.0);
    expect(textWidget.style?.color, PocktColors.dark.textPrimary);

    // Dot-orbe CustomPaint
    final customPaintFinder = find.descendant(
      of: find.byType(PocktWordmark),
      matching: find.byType(CustomPaint),
    );
    expect(customPaintFinder, findsAtLeastNWidgets(1));

    // Tamaño del dot: 0.22 * 60 = 13.2
    final sizedBox = tester.widget<SizedBox>(
      find.ancestor(
        of: customPaintFinder.first,
        matching: find.byType(SizedBox),
      ).first,
    );
    expect(sizedBox.width, closeTo(0.22 * 60.0, 0.01));
    expect(sizedBox.height, closeTo(0.22 * 60.0, 0.01));
  });

  testWidgets('PocktWordmark usa color custom si se especifica', (tester) async {
    const customColor = Colors.yellow;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: const Scaffold(
          body: Center(
            child: PocktWordmark(size: 40, color: customColor),
          ),
        ),
      ),
    );

    final textWidget = tester.widget<Text>(find.text('pockt'));
    expect(textWidget.style?.color, customColor);
  });
}
