import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/reports/data/reports_repository.dart';
import 'package:pockt/features/reports/ui/charts.dart';
import 'package:pockt/features/reports/ui/views/report_shared_widgets.dart';

class EvolutionView extends ConsumerWidget {
  final int months;
  final DateTime todayLocal;
  final bool isDark;
  final ValueChanged<int> onMonthsChanged;

  const EvolutionView({
    super.key,
    required this.months,
    required this.todayLocal,
    required this.isDark,
    required this.onMonthsChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(reportsRepositoryProvider);

    return StreamBuilder<List<MonthTotals>>(
      stream: repo.watchEvolution(months: months, todayLocal: todayLocal),
      builder: (context, snapshot) {
        final totals = snapshot.data ?? const [];
        final hasData = totals.any((m) => m.expense > 0 || m.income > 0);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          physics: const BouncingScrollPhysics(),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Evolución',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: colors.glassFill,
                    borderRadius: BorderRadius.circular(PocktRadii.l),
                    border: Border.all(color: colors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      ReportPeriodChip(
                        label: '6 meses',
                        selected: months == 6,
                        onTap: () {
                          Haptics.tick();
                          onMonthsChanged(6);
                        },
                      ),
                      ReportPeriodChip(
                        label: '12 meses',
                        selected: months == 12,
                        onTap: () {
                          Haptics.tick();
                          onMonthsChanged(12);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 80),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        uiIcon('chart-bar'),
                        size: 44,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sin movimientos en este período',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              EvolutionChart(totals: totals, isDark: isDark),
              const SizedBox(height: 16),
              _buildEvolutionSummary(colors, totals),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEvolutionSummary(PocktColors colors, List<MonthTotals> totals) {
    var sumExp = 0;
    var sumInc = 0;
    for (final m in totals) {
      sumExp += m.expense;
      sumInc += m.income;
    }
    final count = max(1, totals.length);
    final avgExp = (sumExp / count).round();
    final avgInc = (sumInc / count).round();
    final netSaving = sumInc - sumExp;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Promedio mensual de gasto',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                formatGs(avgExp),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Promedio mensual de ingreso',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                formatGs(avgInc),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: colors.glassBorder),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ahorro neto del período',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                formatGs(netSaving),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: netSaving < 0 ? colors.danger : colors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
