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
      final focused = theme.inputDecorationTheme.focusedBorder as OutlineInputBorder;
      expect(focused.borderSide.color, colors.brandStart);
      final error = theme.inputDecorationTheme.errorBorder as OutlineInputBorder;
      expect(error.borderSide.color, colors.danger);
    });
  }
}
