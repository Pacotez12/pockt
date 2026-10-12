import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/design/tokens.dart';

void main() {
  for (final (name, theme, colors) in [
    ('oscuro', buildDarkTheme(), PocktColors.dark),
    ('claro', buildLightTheme(), PocktColors.light),
  ]) {
    test('tema $name: avisos flotantes con la hoja y campos con foco de marca', () {
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(theme.snackBarTheme.backgroundColor, colors.sheetSurface);
      // Foco y error salen del esquema; el tema solo define `border` para no
      // pisar los campos que usan `border: InputBorder.none`.
      expect(theme.colorScheme.primary, colors.brandStart);
      expect(theme.colorScheme.error, colors.danger);
      expect(theme.inputDecorationTheme.enabledBorder, isNull);
      expect(theme.inputDecorationTheme.filled, isFalse);
    });
  }
}
