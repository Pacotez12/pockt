
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/entry/ui/amount_keypad.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';

void openGoalKeypad(
  BuildContext context, {
  required Goal goal,
  required bool isWithdraw,
}) {
  Haptics.tick();
  final colors = context.pockt;
  final customCategory = Category(
    id: goal.id,
    name: isWithdraw ? 'Retiro de ${goal.name}' : 'Aporte a ${goal.name}',
    icon: goal.icon,
    colorDark: colors.positive.toARGB32(),
    colorLight: colors.positive.toARGB32(),
    kind: isWithdraw ? CategoryKind.income : CategoryKind.expense,
    sortOrder: 0,
    archived: false,
  );

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Consumer(
        builder: (ctx, ref, _) {
          final repo = ref.read(goalsRepositoryProvider);
          return AmountKeypadScreen(
            category: customCategory,
            type: isWithdraw ? TxType.income : TxType.expense,
            showMerchant: false,
            onSaveOverride:
                ({
                  required int amount,
                  required Category category,
                  required DateTime occurredAt,
                  String? merchant,
                  String? note,
                }) async {
                  final effectiveAmount = isWithdraw
                      ? -amount.abs()
                      : amount.abs();
                  await repo.addContribution(
                    goalId: goal.id,
                    amount: effectiveAmount,
                    date: occurredAt,
                    note: note,
                  );
                },
          );
        },
      ),
    ),
  );
}

Future<bool?> confirmDeleteGoal(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      final colors = ctx.pockt;
      return AlertDialog(
        backgroundColor: colors.sheetSurface,
        title: Text(
          '¿Eliminar meta?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          'Se borrarán la meta y todo su historial de aportes.',
          style: TextStyle(fontFamily: 'Inter', color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Eliminar',
              style: TextStyle(
                color: colors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class GoalActionButtons extends StatelessWidget {
  final Goal goal;

  const GoalActionButtons({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    return Row(
      children: [
        Expanded(
          child: Pressable(
            key: const ValueKey('goal-contribute-button'),
            semanticLabel: 'Aportar a meta',
            onTap: () => openGoalKeypad(context, goal: goal, isWithdraw: false),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.brandStart, colors.brandEnd],
                ),
                borderRadius: BorderRadius.circular(PocktRadii.l),
                boxShadow: [
                  BoxShadow(
                    color: colors.brandStart.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(uiIcon('plus'), color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Aportar',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Pressable(
            key: const ValueKey('goal-withdraw-button'),
            semanticLabel: 'Retirar de meta',
            onTap: () => openGoalKeypad(context, goal: goal, isWithdraw: true),
            child: GlassCard(
              borderRadius: BorderRadius.circular(PocktRadii.l),
              padding: EdgeInsets.zero,
              // Misma altura que "Aportar" (48 con el borde).
              child: Container(
                height: 46,
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        uiIcon('minus'),
                        color: colors.textPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Retirar',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
