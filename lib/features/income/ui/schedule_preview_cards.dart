import 'package:flutter/material.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:pockt/features/income/domain/pay_split.dart';
import 'package:pockt/features/income/domain/salary_deduction.dart';

const List<String> kScheduleWeekdaysSpanish = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const List<String> kScheduleMonthsSpanish = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String formatSplitPreviewText({
  required int day1,
  required int day2,
  required int? monthlyAmount,
  required int splitPercent1,
}) {
  final d1 = day1 == -1 ? 'A fin de mes' : 'El $day1';
  final day2Label = day2 == -1 ? 'a fin de mes' : 'el $day2';

  if (monthlyAmount != null && monthlyAmount > 0) {
    final splits = splitAmounts(monthlyAmount, [
      splitPercent1,
      100 - splitPercent1,
    ]);
    return '$d1 cobrás ~${formatGs(splits[0])} · $day2Label ~${formatGs(splits[1])}';
  } else {
    return '$d1: $splitPercent1 % · $day2Label: ${100 - splitPercent1} %';
  }
}

String formatNextPayDateText(PayWindow? window) {
  if (window == null) return 'Sin fecha de cobro';
  if (window.isRange) {
    final w1 = kScheduleWeekdaysSpanish[window.earliest.weekday - 1];
    final m1 = kScheduleMonthsSpanish[window.earliest.month - 1];
    final w2 = kScheduleWeekdaysSpanish[window.latest.weekday - 1];
    final m2 = kScheduleMonthsSpanish[window.latest.month - 1];
    if (window.earliest.month == window.latest.month) {
      return 'Próximo cobro: entre el $w1 ${window.earliest.day} y el $w2 ${window.latest.day} de $m2';
    }
    return 'Próximo cobro: entre el $w1 ${window.earliest.day} de $m1 y el $w2 ${window.latest.day} de $m2';
  }
  final next = window.earliest;
  final weekday = kScheduleWeekdaysSpanish[next.weekday - 1];
  final month = kScheduleMonthsSpanish[next.month - 1];
  return 'Próximo cobro: $weekday ${next.day} de $month';
}

class ScheduleNetSummaryCard extends StatelessWidget {
  final int? monthlyAmount;
  final PayMode mode;
  final int day1;
  final int day2;
  final int splitPercent1;
  final List<SalaryDeductionItem> deductions;

  const ScheduleNetSummaryCard({
    super.key,
    required this.monthlyAmount,
    required this.mode,
    required this.day1,
    required this.day2,
    required this.splitPercent1,
    required this.deductions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    if (monthlyAmount == null || monthlyAmount! <= 0) {
      return GlassCard(
        key: const ValueKey('schedule-net-summary-card'),
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(PocktRadii.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LO QUE COBRÁS',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresá tu sueldo bruto para ver el desglose neto real.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    final splits = mode == PayMode.biweekly
        ? [splitPercent1, 100 - splitPercent1]
        : const [100];

    List<int> netList;
    try {
      netList = netPayAmounts(monthlyAmount!, splits, deductions);
    } catch (_) {
      netList = splitAmounts(monthlyAmount!, splits);
    }

    final totalNet = netList.fold<int>(0, (sum, val) => sum + val);
    final totalDeductions = monthlyAmount! - totalNet;

    return GlassCard(
      key: const ValueKey('schedule-net-summary-card'),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'LO QUE COBRÁS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: colors.textTertiary,
                  ),
                ),
              ),
              if (totalDeductions > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.glassFill,
                    borderRadius: BorderRadius.circular(PocktRadii.s),
                    border: Border.all(color: colors.glassBorder),
                  ),
                  child: Text(
                    '−${formatGs(totalDeductions)} en desc.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (mode == PayMode.biweekly && netList.length >= 2) ...[
            _NetRow(
              label:
                  '1ª quincena (${day1 == -1 ? 'Fin de mes' : 'Día $day1'})',
              grossAmount: splitAmounts(monthlyAmount!, splits)[0],
              netAmount: netList[0],
              deductionsApplied: 0,
            ),
            const SizedBox(height: 10),
            _NetRow(
              label:
                  '2ª quincena (${day2 == -1 ? 'Fin de mes' : 'Día $day2'})',
              grossAmount: splitAmounts(monthlyAmount!, splits)[1],
              netAmount: netList[1],
              deductionsApplied: totalDeductions,
            ),
          ] else ...[
            _NetRow(
              label: 'Cobro mensual',
              grossAmount: monthlyAmount!,
              netAmount: netList[0],
              deductionsApplied: totalDeductions,
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 0.5, color: colors.glassBorder),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total neto mensual',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                formatGs(totalNet),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NetRow extends StatelessWidget {
  final String label;
  final int grossAmount;
  final int netAmount;
  final int deductionsApplied;

  const _NetRow({
    required this.label,
    required this.grossAmount,
    required this.netAmount,
    required this.deductionsApplied,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            if (deductionsApplied > 0)
              Text(
                'Bruto ${formatGs(grossAmount)} − ${formatGs(deductionsApplied)}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: colors.textTertiary,
                ),
              ),
          ],
        ),
        Text(
          formatGs(netAmount),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class ScheduleLivePreviewCard extends StatelessWidget {
  final String nextPayDateText;

  const ScheduleLivePreviewCard({super.key, required this.nextPayDateText});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.positive.withValues(alpha: 0.16),
            ),
            child: Center(
              child: Icon(uiIcon('calendar'), size: 20, color: colors.positive),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              nextPayDateText,
              key: const ValueKey('next-pay-day-text'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScheduleSaveButton extends StatelessWidget {
  final VoidCallback onSave;

  const ScheduleSaveButton({super.key, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Pressable(
      key: const ValueKey('save-schedule-button'),
      onTap: onSave,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: colors.brandStart,
          borderRadius: BorderRadius.circular(PocktRadii.xl),
          boxShadow: [
            BoxShadow(
              color: colors.brandStart.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          'Guardar esquema',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
