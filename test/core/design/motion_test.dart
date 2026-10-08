import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/design/motion.dart';

void main() {
  test('PocktSprings define firm y soft', () {
    expect(PocktSprings.firm, isNotNull);
    expect(PocktSprings.soft, isNotNull);
  });

  testWidgets('Pressable no escala con reduce motion', (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        home: Pressable(
          onTap: () {},
          child: const SizedBox(width: 50, height: 50),
        ),
      ),
    ));
    await tester.press(find.byType(Pressable));
    await tester.pump(const Duration(milliseconds: 50));
    final scale = tester
        .widget<Transform>(
            find.descendant(of: find.byType(Pressable), matching: find.byType(Transform)))
        .transform
        .getMaxScaleOnAxis();
    expect(scale, 1.0);
  });

  testWidgets('Pressable escala hacia 0.96 cuando se presiona con animaciones activas', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Pressable(
            onTap: () {},
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      ),
    ));
    final gesture = await tester.press(find.byType(Pressable));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final scale = tester
        .widget<Transform>(
            find.descendant(of: find.byType(Pressable), matching: find.byType(Transform)))
        .transform
        .getMaxScaleOnAxis();
    expect(scale, lessThan(1.0));
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
