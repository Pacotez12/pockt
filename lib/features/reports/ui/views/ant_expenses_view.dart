import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/reports/data/reports_repository.dart';
import 'package:pockt/features/reports/domain/ant_expenses.dart';

class AntExpensesView extends ConsumerWidget {
  final int year;
  final int month;
  final bool isDark;

  const AntExpensesView({
    super.key,
    required this.year,
    required this.month,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(reportsRepositoryProvider);
    final mode =
        ref.watch(monthStartModeProvider).value ?? MonthStartMode.calendar;
    final schedule = ref.watch(currentIncomeScheduleProvider).value;
    final threshold = ref.watch(reportsAntThresholdProvider).value ?? 30000;
    final nowLocal = toLocal(DateTime.now());
    final isCurrent = year == nowLocal.year && month == nowLocal.month;
    final period = periodFor(
      isCurrent ? nowLocal : DateTime(year, month, 15),
      mode: mode,
      schedule: schedule,
    );

    return StreamBuilder<AntExpensesSummary>(
      stream: repo.watchAntExpenses(
        year,
        month,
        period: period,
        threshold: threshold,
      ),
      builder: (context, snapshot) {
        final summary = snapshot.data ?? AntExpensesSummary.empty;
        final list = summary.groups;

        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(uiIcon('coins'), size: 44, color: colors.textTertiary),
                const SizedBox(height: 12),
                Text(
                  'Sin gastos hormiga este mes',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.textTertiary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gastos menores o iguales a ${formatGs(threshold)}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: colors.textTertiary.withValues(alpha: 0.8),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gastos hormiga',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.glassFill,
                    borderRadius: BorderRadius.circular(PocktRadii.m),
                    border: Border.all(color: colors.glassBorder),
                  ),
                  child: Text(
                    '≤ ${formatGs(threshold)}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: PocktType.caption,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total hormiga',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: PocktType.caption,
                            fontWeight: FontWeight.w500,
                            color: colors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatGs(summary.total),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${summary.count} ${summary.count == 1 ? 'compra' : 'compras'}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: PocktType.caption,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Proyección anual',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: PocktType.caption,
                            fontWeight: FontWeight.w500,
                            color: colors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatGs(summary.annualProjection),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'total × 12',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: PocktType.caption,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    _AntGroupRow(group: list[i], isDark: isDark),
                    if (i < list.length - 1)
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
}

class _AntGroupRow extends StatelessWidget {
  final AntExpenseGroup group;
  final bool isDark;

  const _AntGroupRow({required this.group, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final catColor =
        (isDark ? group.colorDark : group.colorLight) ??
        colors.textTertiary.toARGB32();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(catColor).withValues(alpha: 0.16),
            ),
            child: Center(
              child: categoryIcon(
                group.categoryIcon,
                size: 18,
                color: Color(catColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${group.count} ${group.count == 1 ? 'compra' : 'compras'} · Promedio ${formatGs(group.average)}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: colors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatGs(group.total),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
