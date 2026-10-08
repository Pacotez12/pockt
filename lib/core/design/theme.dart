import 'package:flutter/material.dart';
import 'package:pockt/core/design/tokens.dart';

TextTheme _applyTabularInter(TextTheme base, Color color) {
  const fontFeatures = [FontFeature.tabularFigures()];
  TextStyle withTabular(TextStyle? style) {
    return (style ?? const TextStyle()).copyWith(
      fontFamily: 'Inter',
      fontFeatures: fontFeatures,
      color: color,
    );
  }

  return base.copyWith(
    displayLarge: withTabular(base.displayLarge),
    displayMedium: withTabular(base.displayMedium),
    displaySmall: withTabular(base.displaySmall),
    headlineLarge: withTabular(base.headlineLarge),
    headlineMedium: withTabular(base.headlineMedium),
    headlineSmall: withTabular(base.headlineSmall),
    titleLarge: withTabular(base.titleLarge),
    titleMedium: withTabular(base.titleMedium),
    titleSmall: withTabular(base.titleSmall),
    bodyLarge: withTabular(base.bodyLarge),
    bodyMedium: withTabular(base.bodyMedium),
    bodySmall: withTabular(base.bodySmall),
    labelLarge: withTabular(base.labelLarge),
    labelMedium: withTabular(base.labelMedium),
    labelSmall: withTabular(base.labelSmall),
  );
}

ThemeData buildDarkTheme() {
  final colors = PocktColors.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: colors.background,
    colorScheme: ColorScheme.dark(
      surface: colors.background,
      primary: colors.brandStart,
      secondary: colors.brandEnd,
    ),
    textTheme: _applyTabularInter(Typography.material2021().white, colors.textPrimary),
    extensions: [colors],
  );
}

ThemeData buildLightTheme() {
  final colors = PocktColors.light;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: colors.background,
    colorScheme: ColorScheme.light(
      surface: colors.background,
      primary: colors.brandStart,
      secondary: colors.brandEnd,
    ),
    textTheme: _applyTabularInter(Typography.material2021().black, colors.textPrimary),
    extensions: [colors],
  );
}
