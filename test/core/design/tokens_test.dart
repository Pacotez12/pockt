import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/tokens.dart';

void main() {
  test('oscuro usa negro puro y vidrio 7%/9%', () {
    expect(PocktColors.dark.background, const Color(0xFF000000));
    expect(PocktColors.dark.glassFill, Colors.white.withValues(alpha: 0.07));
    expect(PocktColors.dark.glassBorder, Colors.white.withValues(alpha: 0.09));
    expect(PocktColors.dark.heat, hasLength(5));
    expect(PocktColors.light.heat, hasLength(5));
  });

  test('lerp interpola entre claro y oscuro', () {
    final mid = PocktColors.dark.lerp(PocktColors.light, 0.5);
    expect(mid.background, isNot(PocktColors.dark.background));
    expect(mid.sheetSurface, isNot(PocktColors.dark.sheetSurface));
  });

  test('sheetSurface oscuro es 0xFF18181B y claro es blanco', () {
    expect(PocktColors.dark.sheetSurface, const Color(0xFF18181B));
    expect(PocktColors.light.sheetSurface, const Color(0xFFFFFFFF));
  });

  test('colores heat y brand coinciden con especificación', () {
    expect(PocktColors.dark.brandStart, const Color(0xFFFF8A3D));
    expect(PocktColors.dark.brandEnd, const Color(0xFFFF3D7F));
    expect(PocktColors.dark.positive, const Color(0xFF1DD1A1));
    expect(PocktColors.light.brandStart, const Color(0xFFFF8A3D));
    expect(PocktColors.light.brandEnd, const Color(0xFFFF3D7F));
    expect(PocktColors.light.positive, const Color(0xFF0E9673));

    expect(PocktColors.dark.heat, [
      const Color(0x0DFFFFFF),
      const Color(0x38FF7A45),
      const Color(0x73FF7A45),
      const Color(0xB8FF645F),
      const Color(0xFFFF3D7F),
    ]);

    expect(PocktColors.light.heat, [
      const Color(0x0D000000),
      const Color(0xFFFFB08A),
      const Color(0xFFFF8A5C),
      const Color(0xFFF2603F),
      const Color(0xFFE8306F),
    ]);
  });

  testWidgets('GlassCard usa radio por defecto de 24', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [PocktColors.dark]),
      home: const Scaffold(
        body: GlassCard(child: SizedBox(width: 50, height: 50)),
      ),
    ));
    final container = tester.widget<Container>(
      find.descendant(of: find.byType(GlassCard), matching: find.byType(Container)),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(24));
  });
}
