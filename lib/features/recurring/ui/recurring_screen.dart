import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/recurring/ui/recurring_form_screen.dart';
import 'package:pockt/features/recurring/ui/recurring_rule_card.dart';

export 'package:pockt/features/recurring/ui/recurring_form_screen.dart';
export 'package:pockt/features/recurring/ui/recurring_frequency_card.dart';
export 'package:pockt/features/recurring/ui/recurring_rule_card.dart';

/// Pantalla de gestión de reglas recurrentes (spec §5.7 / §5.10).
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  void _openAdd(BuildContext context) {
    Haptics.tick();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RecurringFormScreen()));
  }

  void _openEdit(BuildContext context, RecurringRule rule) {
    Haptics.tick();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RecurringFormScreen(rule: rule)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final rulesAsync = ref.watch(recurringRepositoryProvider).watchAll();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Pressable(
                    semanticLabel: 'Volver',
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.glassFill,
                        border: Border.all(color: colors.glassBorder),
                      ),
                      child: Center(
                        child: Icon(
                          uiIcon('arrow-left'),
                          size: 18,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recurrentes',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Gastos fijos y suscripciones',
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
                    semanticLabel: 'Agregar recurrente',
                    key: const ValueKey('add-recurring-button'),
                    onTap: () => _openAdd(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.brandStart.withValues(alpha: 0.18),
                        border: Border.all(
                          color: colors.brandStart.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          uiIcon('plus'),
                          size: 18,
                          color: colors.brandStart,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<RecurringRule>>(
                stream: rulesAsync,
                builder: (context, snapshot) {
                  final rules = snapshot.data ?? const [];

                  if (rules.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: rules.length,
                    itemBuilder: (context, index) {
                      final rule = rules[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RecurringRuleCard(
                          rule: rule,
                          onTap: () => _openEdit(context, rule),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.pockt;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.glassFill,
                border: Border.all(color: colors.glassBorder),
              ),
              child: Center(
                child: Icon(
                  uiIcon('sparkle'),
                  size: 28,
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sin recurrentes',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anotá suscripciones o gastos fijos para que te recordemos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Pressable(
              key: const ValueKey('empty-add-recurring-button'),
              onTap: () => _openAdd(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.brandStart,
                  borderRadius: BorderRadius.circular(PocktRadii.xl),
                ),
                child: const Text(
                  'Agregar recurrente',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
