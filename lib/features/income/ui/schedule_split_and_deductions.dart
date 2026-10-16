import 'package:flutter/material.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/income/domain/salary_deduction.dart';

class ScheduleSplitSelector extends StatelessWidget {
  final int day1;
  final int day2;
  final int splitPercent1;
  final String splitPreviewText;
  final ValueChanged<int> onSplitChanged;

  const ScheduleSplitSelector({
    super.key,
    required this.day1,
    required this.day2,
    required this.splitPercent1,
    required this.splitPreviewText,
    required this.onSplitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return GlassCard(
      key: const ValueKey('schedule-split-section'),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reparto',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$splitPercent1 % / ${100 - splitPercent1} %',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.brandStart,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colors.brandStart,
              inactiveTrackColor: colors.glassBorder,
              thumbColor: colors.brandStart,
              overlayColor: colors.brandStart.withValues(alpha: 0.16),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              key: const ValueKey('schedule-split-slider'),
              value: splitPercent1.toDouble(),
              min: 5,
              max: 95,
              divisions: 18,
              onChanged: (value) {
                final stepped = (value / 5).round() * 5;
                if (stepped != splitPercent1) {
                  Haptics.tick();
                  onSplitChanged(stepped);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${day1 == -1 ? "Fin de mes" : "Día $day1"}: $splitPercent1 %',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                ),
                Text(
                  '${day2 == -1 ? "Fin de mes" : "Día $day2"}: ${100 - splitPercent1} %',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.glassFill,
              borderRadius: BorderRadius.circular(PocktRadii.m),
              border: Border.all(color: colors.glassBorder),
            ),
            child: Row(
              children: [
                Icon(uiIcon('coins'), size: 16, color: colors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    splitPreviewText,
                    key: const ValueKey('schedule-split-preview-text'),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScheduleDeductionsSection extends StatelessWidget {
  final List<SalaryDeductionItem> deductions;
  final int? monthlyAmount;
  final VoidCallback onAdd;
  final void Function(SalaryDeductionItem item, int index) onEdit;
  final ValueChanged<int> onDelete;

  const ScheduleDeductionsSection({
    super.key,
    required this.deductions,
    required this.monthlyAmount,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'DESCUENTOS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: colors.textTertiary,
                  ),
                ),
              ),
              Pressable(
                key: const ValueKey('add-deduction-button'),
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.brandStart.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(PocktRadii.m),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(uiIcon('plus'), size: 12, color: colors.brandStart),
                      const SizedBox(width: 4),
                      Text(
                        'Agregar',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.brandStart,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (deductions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Sin descuentos (IPS, seguro médico, aportes). Los descuentos se restan del último cobro del mes.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: colors.textTertiary,
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < deductions.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 16,
                      thickness: 0.5,
                      color: colors.glassBorder,
                    ),
                  _DeductionRow(
                    deduction: deductions[i],
                    index: i,
                    monthlyAmount: monthlyAmount,
                    onEdit: () => onEdit(deductions[i], i),
                    onDelete: () => onDelete(i),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _DeductionRow extends StatelessWidget {
  final SalaryDeductionItem deduction;
  final int index;
  final int? monthlyAmount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DeductionRow({
    required this.deduction,
    required this.index,
    required this.monthlyAmount,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    final String subtitle;
    if (deduction.kind == 'percent') {
      final pct = deduction.value / 100.0;
      final pctStr = pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 2);
      final approx = monthlyAmount != null && monthlyAmount! > 0
          ? (monthlyAmount! * (deduction.value / 10000.0)).round()
          : null;
      subtitle =
          '$pctStr % del bruto${approx != null ? ' (~${formatGs(approx)})' : ''}';
    } else {
      subtitle = '${formatGs(deduction.value)} fijo';
    }

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.textSecondary.withValues(alpha: 0.12),
          ),
          child: Center(
            child: Icon(uiIcon('tag'), size: 15, color: colors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deduction.name,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        Pressable(
          semanticLabel: 'Editar descuento',
          key: ValueKey('edit-deduction-$index'),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              uiIcon('paint-brush'),
              size: 16,
              color: colors.textTertiary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Pressable(
          semanticLabel: 'Borrar descuento',
          key: ValueKey('delete-deduction-$index'),
          onTap: onDelete,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(uiIcon('trash'), size: 16, color: colors.danger),
          ),
        ),
      ],
    );
  }
}
