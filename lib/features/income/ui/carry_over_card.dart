import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/amounts_privacy.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';

/// Guarda el inicio (yyyy-MM-dd) del último período en que se decidió
/// qué hacer con lo que sobró del anterior (spec §7e).
const kCarryOverDecidedKey = 'carryover.decidedFor';

String _periodKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Valor guardado de [kCarryOverDecidedKey].
final carryOverDecidedProvider = StreamProvider<String?>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(kCarryOverDecidedKey),
);

/// true si ya se eligió "Sumar" o "Pasar a una meta" en este período.
bool carryOverDecided(String? saved, DateTime periodStart) =>
    saved == _periodKey(periodStart);

/// Tarjeta del Inicio cuando sobró plata del período anterior: ofrece pasarla
/// a una meta o sumarla al período actual. Sin decisión, ya está sumada.
class CarryOverCard extends ConsumerWidget {
  final int amount;
  final DateTime periodStart;
  final bool monthly;

  const CarryOverCard({
    super.key,
    required this.amount,
    required this.periodStart,
    this.monthly = false,
  });

  Future<void> _decide(WidgetRef ref) => ref
      .read(settingsRepositoryProvider)
      .set(kCarryOverDecidedKey, _periodKey(periodStart));

  Future<void> _moveToGoal(
    BuildContext context,
    WidgetRef ref,
    List<Goal> goals,
  ) async {
    final goal = await showModalBottomSheet<Goal>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _GoalPickerSheet(goals: goals),
    );
    if (goal == null) return;
    await ref
        .read(goalsRepositoryProvider)
        .addContribution(
          goalId: goal.id,
          amount: amount,
          date: DateTime.now(),
          note: monthly
              ? 'Sobrante del mes anterior'
              : 'Sobrante de la quincena anterior',
        );
    await _decide(ref);
    Haptics.save();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Aportado a ${goal.name}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final obscure = ref.watch(shouldObscureAmountsProvider);
    final goals = ref.watch(_activeGoalsProvider).value ?? const <Goal>[];
    final amountText = obscure ? '••••' : formatGs(amount);

    return GlassCard(
      key: const ValueKey('carry-over-card'),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.positive.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(uiIcon('coins'), size: 18, color: colors.positive),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Te sobraron ',
                    children: [
                      TextSpan(
                        text: amountText,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: monthly
                            ? ' del mes anterior'
                            : ' de la quincena anterior',
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: PocktType.body,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (goals.isNotEmpty) ...[
                Expanded(
                  child: _CardButton(
                    label: 'Pasar a una meta',
                    primary: true,
                    onTap: () => _moveToGoal(context, ref, goals),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: _CardButton(
                  label: monthly ? 'Sumar a este mes' : 'Sumar a esta quincena',
                  onTap: () {
                    Haptics.tick();
                    _decide(ref);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final _activeGoalsProvider = StreamProvider<List<Goal>>(
  (ref) => ref.watch(goalsRepositoryProvider).watchActive(),
);

class _CardButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _CardButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    return Pressable(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: primary
              ? LinearGradient(colors: [colors.brandStart, colors.brandEnd])
              : null,
          color: primary ? null : colors.glassFill,
          border: primary ? null : Border.all(color: colors.glassBorder),
          borderRadius: BorderRadius.circular(PocktRadii.m),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: PocktType.body,
              fontWeight: FontWeight.w600,
              color: primary ? Colors.white : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalPickerSheet extends StatelessWidget {
  final List<Goal> goals;

  const _GoalPickerSheet({required this.goals});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    // Material (no Container) para que los ListTile pinten su ripple.
    return Material(
      color: colors.sheetSurface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(PocktRadii.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '¿A qué meta?',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: PocktType.title,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final goal in goals)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            uiIcon(goal.icon),
                            color: colors.textSecondary,
                          ),
                          title: Text(
                            goal.name,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: colors.textPrimary,
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(goal),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
