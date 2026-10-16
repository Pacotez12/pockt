import 'package:flutter/material.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/recurring/domain/recurrence.dart';

class RecurringFrequencyCard extends StatelessWidget {
  final RecurrenceFrequency frequency;
  final int? dayOfMonth;
  final ValueChanged<RecurrenceFrequency> onFrequencyChanged;
  final ValueChanged<int> onDayOfMonthChanged;

  const RecurringFrequencyCard({
    super.key,
    required this.frequency,
    required this.dayOfMonth,
    required this.onFrequencyChanged,
    required this.onDayOfMonthChanged,
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
          Text(
            'Frecuencia',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: RecurringFreqPill(
                  key: const ValueKey('freq-monthly'),
                  title: 'Mensual',
                  isSelected: frequency == RecurrenceFrequency.monthly,
                  onTap: () => onFrequencyChanged(RecurrenceFrequency.monthly),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RecurringFreqPill(
                  key: const ValueKey('freq-weekly'),
                  title: 'Semanal',
                  isSelected: frequency == RecurrenceFrequency.weekly,
                  onTap: () => onFrequencyChanged(RecurrenceFrequency.weekly),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RecurringFreqPill(
                  key: const ValueKey('freq-yearly'),
                  title: 'Anual',
                  isSelected: frequency == RecurrenceFrequency.yearly,
                  onTap: () => onFrequencyChanged(RecurrenceFrequency.yearly),
                ),
              ),
            ],
          ),
          if (frequency == RecurrenceFrequency.monthly) ...[
            const SizedBox(height: 14),
            Text(
              'Día del mes: ${dayOfMonth ?? 15}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [1, 5, 10, 15, 20, 25, 28, 30].map((d) {
                final sel = dayOfMonth == d;
                return Pressable(
                  onTap: () => onDayOfMonthChanged(d),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? colors.brandStart : colors.glassFill,
                      borderRadius: BorderRadius.circular(PocktRadii.m),
                      border: Border.all(
                        color: sel ? colors.brandStart : colors.glassBorder,
                      ),
                    ),
                    child: Text(
                      '$d',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : colors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class RecurringFreqPill extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const RecurringFreqPill({
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.textPrimary : colors.glassFill,
          borderRadius: BorderRadius.circular(PocktRadii.m),
          border: Border.all(
            color: isSelected ? colors.textPrimary : colors.glassBorder,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? colors.background : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
