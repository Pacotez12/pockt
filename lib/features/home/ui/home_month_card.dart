import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/amounts_privacy.dart';
import 'package:pockt/features/home/data/home_providers.dart';
import 'package:pockt/features/home/ui/home_top_bar.dart';
import 'package:pockt/features/income/domain/period_summary.dart';
import 'package:pockt/features/income/ui/income_schedule_screen.dart';

/// Tarjeta "Gastado en {mes}" debajo del Arco de hoy:
/// monto del mes, barra de categorías y línea de período.
class HomeMonthCard extends ConsumerWidget {
  final int year;
  final int month;
  final DateTime nowLocal;
  final PeriodLine? periodLine;
  final IncomeSchedule? schedule;

  const HomeMonthCard({
    super.key,
    required this.year,
    required this.month,
    required this.nowLocal,
    this.periodLine,
    this.schedule,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final obscure = ref.watch(shouldObscureAmountsProvider);
    final monthNameLower = kMonthNames[month - 1].toLowerCase();
    final monthTotal =
        ref
            .watch(
              homeMonthTotalProvider((
                year: year,
                month: month,
                nowLocal: nowLocal,
              )),
            )
            .value ??
        0;

    return GlassCard(
      key: const ValueKey('home-month-card'),
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'Gastado en $monthNameLower',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: PocktType.caption,
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                obscure ? '••••' : formatGs(monthTotal),
                key: const ValueKey('home-month-total'),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          CategorySegmentedBar(
            year: year,
            month: month,
            nowLocal: nowLocal,
          ),
          const SizedBox(height: 12),
          if (periodLine != null)
            HomePeriodLine(
              line: periodLine!,
              scheduleMode: schedule?.mode,
            )
          else
            // Sin esquema de cobro no hay "quedan · cobrás en": se invita a
            // configurarlo en vez de esconder la línea.
            Pressable(
              key: const ValueKey('home-setup-payday'),
              semanticLabel: 'Configurá cuándo cobrás',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const IncomeScheduleScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Configurá cuándo cobrás para ver cuánto te queda',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: PocktType.caption,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Icon(
                      uiIcon('caret-right'),
                      size: 16,
                      color: colors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Barra segmentada que distribuye visualmente el gasto por categoría.
class CategorySegmentedBar extends ConsumerWidget {
  final int year;
  final int month;
  final DateTime nowLocal;

  const CategorySegmentedBar({
    super.key,
    required this.year,
    required this.month,
    required this.nowLocal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryTotals =
        ref
            .watch(
              homeCategoryTotalsProvider((
                year: year,
                month: month,
                nowLocal: nowLocal,
              )),
            )
            .value ??
        const [];

    if (categoryTotals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: colors.glassFill,
          ),
        ),
      );
    }

    final sum = categoryTotals.fold<int>(0, (acc, c) => acc + c.total);
    if (sum <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: colors.glassFill,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          for (int i = 0; i < categoryTotals.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              flex: (categoryTotals[i].total * 1000 ~/ sum).clamp(1, 1000),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: Color(
                    isDark
                        ? categoryTotals[i].category.colorDark
                        : categoryTotals[i].category.colorLight,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Línea del período (quincena / mes) con monto restante y fecha de cobro.
class HomePeriodLine extends ConsumerWidget {
  final PeriodLine line;
  final String? scheduleMode;
  final EdgeInsetsGeometry padding;

  const HomePeriodLine({
    super.key,
    required this.line,
    this.scheduleMode,
    this.padding = const EdgeInsets.symmetric(horizontal: 6),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final carry = line.carryOver;
    final obscure = ref.watch(shouldObscureAmountsProvider);
    final previous = scheduleMode?.toLowerCase() == 'monthly'
        ? 'del mes anterior'
        : 'de la quincena anterior';
    final carryText = obscure
        ? 'incluye •••• $previous'
        : 'incluye ${carry > 0 ? '+' : '−'}${formatGs(carry.abs())} $previous';

    return Pressable(
      semanticLabel: 'Línea del período',
      onTap: () => ref.read(amountsRevealedProvider.notifier).toggle(),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              key: const ValueKey('period-line'),
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  // Con letra grande, la línea se achica en vez de partir "Gs." del monto.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        text: '${line.label} · quedan ',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: colors.textSecondary.withValues(alpha: 0.75),
                        ),
                        children: [
                          TextSpan(
                            text: obscure
                                ? '••••'
                                : (line.isEstimate
                                      ? '~${formatGs(line.remaining)} '
                                      : formatGs(line.remaining)),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: line.remaining < 0
                                  ? colors.danger
                                  : colors.textPrimary,
                            ),
                          ),
                          if (line.isEstimate && !obscure)
                            TextSpan(
                              text: '(estimado)',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: colors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      key: const ValueKey('period-line-remaining'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  line.payDayText,
                  key: const ValueKey('period-line-payday'),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.textSecondary.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            if (carry != 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  carryText,
                  key: const ValueKey('period-line-carry'),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: PocktType.caption,
                    color: colors.textSecondary.withValues(alpha: 0.55),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
