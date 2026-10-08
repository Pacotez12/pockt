import 'package:flutter/material.dart';

class PocktColors extends ThemeExtension<PocktColors> {
  final Color background;
  final Color glassFill;
  final Color glassBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color brandStart;
  final Color brandEnd;
  final Color positive;
  final Color sheetSurface;
  final List<Color> heat;

  const PocktColors({
    required this.background,
    required this.glassFill,
    required this.glassBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.brandStart,
    required this.brandEnd,
    required this.positive,
    required this.sheetSurface,
    required this.heat,
  });

  static final PocktColors dark = PocktColors(
    background: const Color(0xFF000000),
    glassFill: Colors.white.withValues(alpha: 0.07),
    glassBorder: Colors.white.withValues(alpha: 0.09),
    textPrimary: const Color(0xFFFFFFFF),
    textSecondary: Colors.white.withValues(alpha: 0.60),
    textTertiary: Colors.white.withValues(alpha: 0.45),
    brandStart: const Color(0xFFFF8A3D),
    brandEnd: const Color(0xFFFF3D7F),
    positive: const Color(0xFF1DD1A1),
    sheetSurface: const Color(0xFF18181B),
    heat: const [
      Color(0x0DFFFFFF),
      Color(0x38FF7A45),
      Color(0x73FF7A45),
      Color(0xB8FF645F),
      Color(0xFFFF3D7F),
    ],
  );

  static final PocktColors light = PocktColors(
    background: const Color(0xFFF7F7F8),
    glassFill: Colors.white.withValues(alpha: 0.70),
    glassBorder: Colors.black.withValues(alpha: 0.06),
    textPrimary: const Color(0xFF000000),
    textSecondary: Colors.black.withValues(alpha: 0.60),
    textTertiary: Colors.black.withValues(alpha: 0.45),
    brandStart: const Color(0xFFFF8A3D),
    brandEnd: const Color(0xFFFF3D7F),
    positive: const Color(0xFF0E9673),
    sheetSurface: const Color(0xFFFFFFFF),
    heat: const [
      Color(0x0D000000),
      Color(0xFFFFB08A),
      Color(0xFFFF8A5C),
      Color(0xFFF2603F),
      Color(0xFFE8306F),
    ],
  );

  @override
  PocktColors copyWith({
    Color? background,
    Color? glassFill,
    Color? glassBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? brandStart,
    Color? brandEnd,
    Color? positive,
    Color? sheetSurface,
    List<Color>? heat,
  }) {
    return PocktColors(
      background: background ?? this.background,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      brandStart: brandStart ?? this.brandStart,
      brandEnd: brandEnd ?? this.brandEnd,
      positive: positive ?? this.positive,
      sheetSurface: sheetSurface ?? this.sheetSurface,
      heat: heat ?? this.heat,
    );
  }

  @override
  PocktColors lerp(ThemeExtension<PocktColors>? other, double t) {
    if (other is! PocktColors) return this;
    return PocktColors(
      background: Color.lerp(background, other.background, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      brandStart: Color.lerp(brandStart, other.brandStart, t)!,
      brandEnd: Color.lerp(brandEnd, other.brandEnd, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      sheetSurface: Color.lerp(sheetSurface, other.sheetSurface, t)!,
      heat: List<Color>.generate(
        5,
        (i) => Color.lerp(heat[i], other.heat[i], t)!,
      ),
    );
  }
}

extension PocktTheme on BuildContext {
  PocktColors get pockt =>
      Theme.of(this).extension<PocktColors>() ?? PocktColors.dark;
}
