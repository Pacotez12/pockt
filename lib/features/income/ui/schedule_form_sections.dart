import 'package:flutter/material.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/income/domain/pay_days.dart';

class ScheduleModeSelector extends StatelessWidget {
  final PayMode mode;
  final ValueChanged<PayMode> onModeChanged;

  const ScheduleModeSelector({
    super.key,
    required this.mode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(PocktRadii.xl),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModePill(
              key: const ValueKey('schedule-mode-biweekly'),
              title: 'Quincenal',
              isSelected: mode == PayMode.biweekly,
              onTap: () {
                Haptics.tick();
                onModeChanged(PayMode.biweekly);
              },
            ),
          ),
          Expanded(
            child: _ModePill(
              key: const ValueKey('schedule-mode-monthly'),
              title: 'Mensual',
              isSelected: mode == PayMode.monthly,
              onTap: () {
                Haptics.tick();
                onModeChanged(PayMode.monthly);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ScheduleDaysSelector extends StatelessWidget {
  final PayMode mode;
  final int day1;
  final int day2;
  final int monthlyDay;
  final PayDayRule day1Rule;
  final PayDayRule day2Rule;
  final PayDayRule monthlyRule;
  final ValueChanged<int> onDay1Changed;
  final ValueChanged<int> onDay2Changed;
  final ValueChanged<int> onMonthlyDayChanged;
  final ValueChanged<PayDayRule> onDay1RuleChanged;
  final ValueChanged<PayDayRule> onDay2RuleChanged;
  final ValueChanged<PayDayRule> onMonthlyRuleChanged;

  const ScheduleDaysSelector({
    super.key,
    required this.mode,
    required this.day1,
    required this.day2,
    required this.monthlyDay,
    required this.day1Rule,
    required this.day2Rule,
    required this.monthlyRule,
    required this.onDay1Changed,
    required this.onDay2Changed,
    required this.onMonthlyDayChanged,
    required this.onDay1RuleChanged,
    required this.onDay2RuleChanged,
    required this.onMonthlyRuleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    if (mode == PayMode.biweekly) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(PocktRadii.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Días de cobro',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Primer y segundo cobro de la quincena',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            // Primer cobro
            Text(
              '1er cobro: día $day1',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [1, 5, 10, 15, 20].map((d) {
                final sel = day1 == d;
                return _DayChip(
                  text: '$d',
                  isSelected: sel,
                  onTap: () {
                    Haptics.tick();
                    onDay1Changed(d);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            RuleSelector(
              key: const ValueKey('rule-selector-day1'),
              currentRule: day1Rule,
              onChanged: onDay1RuleChanged,
            ),
            const SizedBox(height: 20),
            Divider(color: colors.glassBorder, height: 1),
            const SizedBox(height: 20),
            // Segundo cobro
            Text(
              '2º cobro: ${day2 == -1 ? "Último día" : "día $day2"}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [25, 28, 30, -1].map((d) {
                final sel = day2 == d;
                return _DayChip(
                  text: d == -1 ? 'Último' : '$d',
                  isSelected: sel,
                  onTap: () {
                    Haptics.tick();
                    onDay2Changed(d);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            RuleSelector(
              key: const ValueKey('rule-selector-day2'),
              currentRule: day2Rule,
              onChanged: onDay2RuleChanged,
            ),
          ],
        ),
      );
    } else {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(PocktRadii.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Día del mes',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Elegí qué día de cada mes cobrás',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [1, 5, 10, 15, 20, 25, 28, 30, -1].map((d) {
                final sel = monthlyDay == d;
                return _DayChip(
                  text: d == -1 ? 'Último día' : '$d',
                  isSelected: sel,
                  onTap: () {
                    Haptics.tick();
                    onMonthlyDayChanged(d);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            RuleSelector(
              key: const ValueKey('rule-selector-monthly'),
              currentRule: monthlyRule,
              onChanged: onMonthlyRuleChanged,
            ),
          ],
        ),
      );
    }
  }
}

class ScheduleMonthlyAmountTile extends StatelessWidget {
  final int? monthlyAmount;
  final VoidCallback onTap;

  const ScheduleMonthlyAmountTile({
    super.key,
    required this.monthlyAmount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Pressable(
      key: const ValueKey('schedule-monthly-amount-tile'),
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: BorderRadius.circular(PocktRadii.xl),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sueldo mensual',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    monthlyAmount != null && monthlyAmount! > 0
                        ? formatGs(monthlyAmount!)
                        : 'Opcional (se sugerirá al cobrar)',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(uiIcon('caret-right'), size: 16, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class RuleSelector extends StatelessWidget {
  final PayDayRule currentRule;
  final ValueChanged<PayDayRule> onChanged;

  const RuleSelector({
    super.key,
    required this.currentRule,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Si no es día hábil:',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(PocktRadii.l),
            border: Border.all(color: colors.glassBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: _RulePill(
                  title: 'El anterior',
                  isSelected: currentRule == PayDayRule.previous,
                  onTap: () => onChanged(PayDayRule.previous),
                ),
              ),
              Expanded(
                child: _RulePill(
                  title: 'El siguiente',
                  isSelected: currentRule == PayDayRule.next,
                  onTap: () => onChanged(PayDayRule.next),
                ),
              ),
              Expanded(
                child: _RulePill(
                  title: 'Puede variar',
                  isSelected: currentRule == PayDayRule.either,
                  onTap: () => onChanged(PayDayRule.either),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RulePill extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _RulePill({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return GestureDetector(
      onTap: () {
        Haptics.tick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? colors.background : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModePill({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(PocktRadii.l),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? colors.background : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayChip({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.brandStart : colors.glassFill,
          borderRadius: BorderRadius.circular(PocktRadii.m),
          border: Border.all(
            color: isSelected ? colors.brandStart : colors.glassBorder,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
