import 'package:flutter/material.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/budgets/domain/budget_status.dart';

const List<String> kBudgetMonthNames = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

Color getBudgetCategoryColor(Category category, bool isDark) {
  return Color(isDark ? category.colorDark : category.colorLight);
}

Color getBudgetEffectiveColor(
  BudgetStatus status,
  Category category,
  PocktColors colors,
  bool isDark,
) {
  if (status.level == BudgetLevel.over) {
    return colors.danger;
  } else if (status.level == BudgetLevel.warning) {
    return colors.warning;
  } else {
    return getBudgetCategoryColor(category, isDark);
  }
}

/// Dispara alerta háptica al cruzar el umbral del 80 % (advertencia) o 100 % (exceso).
void triggerBudgetThresholdAlert(BudgetLevel? previous, BudgetLevel current) {
  if (previous == null) return;
  if (previous != BudgetLevel.over && current == BudgetLevel.over) {
    Haptics.danger();
  } else if (previous == BudgetLevel.ok && current == BudgetLevel.warning) {
    Haptics.warning();
  }
}
