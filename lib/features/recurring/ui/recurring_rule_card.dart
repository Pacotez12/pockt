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
import 'package:pockt/core/time/local_time.dart';

const List<String> kRecurringShortMonths = [
  'ene.',
  'feb.',
  'mar.',
  'abr.',
  'may.',
  'jun.',
  'jul.',
  'ago.',
  'sep.',
  'oct.',
  'nov.',
  'dic.',
];

Future<bool?> showDeleteRecurringConfirmDialog(
  BuildContext context, {
  required String ruleName,
}) {
  final colors = context.pockt;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Eliminar recurrente?'),
      content: Text('¿Seguro que querés eliminar "$ruleName"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const ValueKey('confirm-delete-recurring-btn'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('Eliminar', style: TextStyle(color: colors.danger)),
        ),
      ],
    ),
  );
}

class RecurringRuleCard extends ConsumerWidget {
  final RecurringRule rule;
  final VoidCallback onTap;

  const RecurringRuleCard({
    super.key,
    required this.rule,
    required this.onTap,
  });

  String _formatNextDue(DateTime date) {
    final local = toLocal(date);
    return '${local.day} de ${kRecurringShortMonths[local.month - 1]}';
  }

  String _formatFreq(String freq) {
    switch (freq) {
      case 'weekly':
        return 'Semanal';
      case 'yearly':
        return 'Anual';
      case 'monthly':
      default:
        return 'Mensual';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = ref.read(recurringRepositoryProvider);

    final categories = ref.watch(allCategoriesStreamProvider).value ?? const [];
    final category = categories
        .where((c) => c.id == rule.categoryId)
        .firstOrNull;
    final catColor = category != null
        ? (isDark ? category.colorDark : category.colorLight)
        : colors.brandStart.toARGB32();

    return Dismissible(
      key: ValueKey('dismiss-${rule.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colors.danger.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(PocktRadii.xl),
        ),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(uiIcon('trash'), color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Borrar',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        Haptics.tick();
        repo.delete(rule.id);
      },
      child: Pressable(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          borderRadius: BorderRadius.circular(PocktRadii.xl),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(catColor)
                      .withValues(alpha: isDark ? 0.20 : 0.14),
                ),
                child: Center(
                  child: category != null
                      ? categoryIcon(
                          category.icon,
                          size: 20,
                          color: Color(catColor),
                        )
                      : Icon(
                          uiIcon('arrows-clockwise'),
                          size: 18,
                          color: colors.brandStart,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: rule.active
                            ? colors.textPrimary
                            : colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatFreq(rule.frequency)} · Próximo: ${_formatNextDue(rule.nextDueDate)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatGs(rule.amount),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: rule.active
                          ? colors.textPrimary
                          : colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch.adaptive(
                        key: ValueKey('toggle-active-${rule.id}'),
                        value: rule.active,
                        onChanged: (active) {
                          Haptics.tick();
                          repo.setActive(rule.id, active);
                        },
                      ),
                      const SizedBox(width: 6),
                      Pressable(
                        semanticLabel: 'Borrar recurrente',
                        key: ValueKey('delete-recurring-${rule.id}'),
                        onTap: () async {
                          Haptics.tick();
                          final confirm =
                              await showDeleteRecurringConfirmDialog(
                                context,
                                ruleName: rule.name,
                              );
                          if (confirm == true) {
                            Haptics.danger();
                            repo.delete(rule.id);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            uiIcon('trash'),
                            size: 18,
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
