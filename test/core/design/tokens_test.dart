import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });

  test('colores heat y brand coinciden con especificación', () {
    expect(PocktColors.dark.brandStart, const Color(0xFFFF8A3D));
    expect(PocktColors.dark.brandEnd, const Color(0xFFFF3D7F));
    expect(PocktColors.light.brandStart, const Color(0xFFFF8A3D));
    expect(PocktColors.light.brandEnd, const Color(0xFFFF3D7F));

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
}
