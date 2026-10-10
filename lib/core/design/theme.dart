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

DatePickerThemeData _buildDatePickerTheme(PocktColors colors) {
  return DatePickerThemeData(
    backgroundColor: colors.sheetSurface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: colors.glassBorder),
    ),
    headerBackgroundColor: colors.sheetSurface,
    headerForegroundColor: colors.textPrimary,
    headerHeadlineStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: colors.textPrimary,
    ),
    headerHelpStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: colors.textSecondary,
    ),
    weekdayStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: colors.textSecondary,
    ),
    dayStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      color: colors.textPrimary,
    ),
    yearStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      color: colors.textPrimary,
    ),
    dayForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return Colors.white;
      }
      if (states.contains(WidgetState.disabled)) {
        return colors.textTertiary;
      }
      return colors.textPrimary;
    }),
    dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return colors.brandStart;
      }
      return Colors.transparent;
    }),
    todayForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return Colors.white;
      }
      return colors.brandStart;
    }),
    todayBorder: BorderSide(color: colors.brandStart),
    cancelButtonStyle: TextButton.styleFrom(
      foregroundColor: colors.textSecondary,
      textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
    ),
    confirmButtonStyle: TextButton.styleFrom(
      foregroundColor: colors.brandStart,
      textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
    ),
    dividerColor: colors.glassBorder,
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
    dialogTheme: DialogThemeData(
      backgroundColor: colors.sheetSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.glassBorder),
      ),
    ),
    datePickerTheme: _buildDatePickerTheme(colors),
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
    dialogTheme: DialogThemeData(
      backgroundColor: colors.sheetSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.glassBorder),
      ),
    ),
    datePickerTheme: _buildDatePickerTheme(colors),
    textTheme: _applyTabularInter(Typography.material2021().black, colors.textPrimary),
    extensions: [colors],
  );
}
