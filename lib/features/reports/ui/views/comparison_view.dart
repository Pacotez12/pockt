import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/reports/data/reports_repository.dart';
import 'package:pockt/features/reports/domain/compare.dart';
import 'package:pockt/features/reports/ui/views/report_shared_widgets.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

class ComparisonView extends ConsumerWidget {
  final int year;
  final int month;
  final DateTime todayLocal;
  final bool isDark;

  const ComparisonView({
    super.key,
    required this.year,
    required this.month,
    required this.todayLocal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(reportsRepositoryProvider);

    return StreamBuilder<Comparison>(
      stream: repo.watchComparison(todayLocal: todayLocal),
      builder: (context, snapshot) {
        final comp = snapshot.data;
        if (comp == null || (comp.current == 0 && comp.previous == 0)) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(uiIcon('trend-up'), size: 44, color: colors.textTertiary),
                const SizedBox(height: 12),
                Text(
                  'Sin datos para comparar',
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

        final prevMonth = month == 1 ? 12 : month - 1;
        final prevYear = month == 1 ? year - 1 : year;
        final prevMonthName = kReportMonthNames[prevMonth - 1].toLowerCase();

        String headline;
        if (comp.changePct == null) {
          headline =
              'Gastaste ${formatGs(comp.current)} este mes · sin gastos en $prevMonthName a esta altura';
        } else {
          final pct = comp.changePct!.round();
          if (pct > 0) {
            headline =
                'Este mes gastaste $pct % más que en $prevMonthName a esta altura';
          } else if (pct < 0) {
            headline =
                'Este mes gastaste ${pct.abs()} % menos que en $prevMonthName a esta altura';
          } else {
            headline =
                'Este mes gastaste lo mismo que en $prevMonthName a esta altura';
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          physics: const BouncingScrollPhysics(),
          children: [
            Text(
              'Comparación',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ReportStatPill(
                          label: 'Mes actual\n(${kReportMonthNames[month - 1]})',
                          amount: comp.current,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ReportStatPill(
                          label: 'Mes anterior\n($prevMonthName)',
                          amount: comp.previous,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Comparación por categoría',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _CategoryComparisonSection(
              curYear: year,
              curMonth: month,
              prevYear: prevYear,
              prevMonth: prevMonth,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }
}

class _CategoryComparisonSection extends ConsumerWidget {
  final int curYear;
  final int curMonth;
  final int prevYear;
  final int prevMonth;
  final bool isDark;

  const _CategoryComparisonSection({
    required this.curYear,
    required this.curMonth,
    required this.prevYear,
    required this.prevMonth,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(reportsRepositoryProvider);

    return StreamBuilder<List<CategoryTotal>>(
      stream: repo.watchMonthByCategory(curYear, curMonth),
      builder: (context, curSnap) {
        return StreamBuilder<List<CategoryTotal>>(
          stream: repo.watchMonthByCategory(prevYear, prevMonth),
          builder: (context, prevSnap) {
            final curList = curSnap.data ?? const [];
            final prevList = prevSnap.data ?? const [];

            final map = <String, ({Category category, int cur, int prev})>{};
            for (final c in curList) {
              map[c.category.id] = (
                category: c.category,
                cur: c.total,
                prev: 0,
              );
            }
            for (final p in prevList) {
              final existing = map[p.category.id];
              if (existing != null) {
                map[p.category.id] = (
                  category: existing.category,
                  cur: existing.cur,
                  prev: p.total,
                );
              } else {
                map[p.category.id] = (
                  category: p.category,
                  cur: 0,
                  prev: p.total,
                );
              }
            }

            final items = map.values.toList()
              ..sort(
                (a, b) => max(b.cur, b.prev).compareTo(max(a.cur, a.prev)),
              );

            if (items.isEmpty) {
              return const SizedBox.shrink();
            }

            return GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _CategoryComparisonRow(
                      category: items[i].category,
                      cur: items[i].cur,
                      prev: items[i].prev,
                      isDark: isDark,
                    ),
                    if (i < items.length - 1)
                      Divider(
                        height: 1,
                        color: colors.glassBorder,
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CategoryComparisonRow extends StatelessWidget {
  final Category category;
  final int cur;
  final int prev;
  final bool isDark;

  const _CategoryComparisonRow({
    required this.category,
    required this.cur,
    required this.prev,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final catColor = Color(isDark ? category.colorDark : category.colorLight);

    String changeLabel;
    Color changeColor;
    if (prev == 0 && cur > 0) {
      changeLabel = 'Nuevo';
      changeColor = colors.brandStart;
    } else if (prev > 0 && cur == 0) {
      changeLabel = '-100 %';
      changeColor = colors.positive;
    } else if (prev > 0) {
      final pct = (((cur - prev) / prev) * 100).round();
      if (pct > 0) {
        changeLabel = '+$pct %';
        changeColor = colors.danger;
      } else if (pct < 0) {
        changeLabel = '$pct %';
        changeColor = colors.positive;
      } else {
        changeLabel = '0 %';
        changeColor = colors.textTertiary;
      }
    } else {
      changeLabel = '0 %';
      changeColor = colors.textTertiary;
    }

    return Padding(
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
              child: categoryIcon(category.icon, size: 16, color: catColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  'Antes: ${formatGs(prev)}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatGs(cur),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: colors.textPrimary,
                ),
              ),
              Text(
                changeLabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: changeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
