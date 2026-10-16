import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/reports/data/reports_repository.dart';
import 'package:pockt/features/reports/ui/charts.dart';
import 'package:pockt/features/reports/ui/views/category_transactions_sheet.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

class CategoriesView extends ConsumerWidget {
  final int year;
  final int month;
  final DateTime nowLocal;
  final bool isDark;

  const CategoriesView({
    super.key,
    required this.year,
    required this.month,
    required this.nowLocal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(reportsRepositoryProvider);
    final mode =
        ref.watch(monthStartModeProvider).value ?? MonthStartMode.calendar;
    final schedule = ref.watch(currentIncomeScheduleProvider).value;
    final isCurrent = year == nowLocal.year && month == nowLocal.month;
    final period = periodFor(
      isCurrent ? nowLocal : DateTime(year, month, 15),
      mode: mode,
      schedule: schedule,
    );

    return StreamBuilder<List<CategoryTotal>>(
      stream: repo.watchMonthByCategory(year, month, period: period),
      builder: (context, snapshot) {
        final totals = snapshot.data ?? const [];
        final totalExpense = totals.fold<int>(0, (sum, t) => sum + t.total);

        if (totals.isEmpty || totalExpense <= 0) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  uiIcon('chart-pie-slice'),
                  size: 44,
                  color: colors.textTertiary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Sin gastos este mes',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          physics: const BouncingScrollPhysics(),
          children: [
            CategoryDonutChart(
              totals: totals,
              totalExpense: totalExpense,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
            Text(
              'Por categoría',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < totals.length; i++) ...[
                    _CategoryRow(
                      item: totals[i],
                      totalExpense: totalExpense,
                      isDark: isDark,
                      onTap: () => _openCategoryTransactions(
                        context,
                        totals[i].category,
                      ),
                    ),
                    if (i < totals.length - 1)
                      Divider(
                        height: 1,
                        color: colors.glassBorder,
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _openCategoryTransactions(BuildContext context, Category category) {
    Haptics.tick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetContext) => CategoryTransactionsSheet(
        category: category,
        year: year,
        month: month,
        nowLocal: nowLocal,
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryTotal item;
  final int totalExpense;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.item,
    required this.totalExpense,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final catColor = Color(
      isDark ? item.category.colorDark : item.category.colorLight,
    );
    final pct = totalExpense > 0
        ? (item.total / totalExpense * 100)
              .toStringAsFixed(1)
              .replaceAll('.', ',')
        : '0,0';

    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: catColor.withValues(alpha: isDark ? 0.20 : 0.14),
              ),
              child: Center(
                child: categoryIcon(
                  item.category.icon,
                  size: 16,
                  color: catColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.category.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    '$pct %',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatGs(item.total),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(uiIcon('caret-right'), size: 14, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
