import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/goals/domain/goal_progress.dart';
import 'package:pockt/features/goals/ui/goal_detail_actions.dart';
import 'package:pockt/features/goals/ui/goal_detail_sections.dart';

export 'package:pockt/features/goals/ui/goal_detail_actions.dart';
export 'package:pockt/features/goals/ui/goal_detail_sections.dart';
export 'package:pockt/features/goals/ui/goal_progress_ring_painter.dart';

class GoalDetailScreen extends ConsumerWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(goalsRepositoryProvider);

    return StreamBuilder<List<GoalWithProgress>>(
      stream: repo.watchActiveWithProgress(),
      builder: (context, snapshot) {
        // Buscar la meta entre activas o archivadas
        final items = snapshot.data ?? [];
        GoalWithProgress? item;
        for (final it in items) {
          if (it.goal.id == goalId) {
            item = it;
            break;
          }
        }

        if (item == null) {
          // Intentar obtener la meta directamente
          return FutureBuilder<Goal?>(
            future: repo.getGoal(goalId),
            builder: (context, futureSnap) {
              final goal = futureSnap.data;
              if (goal == null) {
                return Scaffold(
                  backgroundColor: colors.background,
                  appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: Icon(
                        uiIcon('arrow-left'),
                        color: colors.textPrimary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  body: Center(
                    child: Text(
                      'Meta no encontrada',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                );
              }
              return StreamBuilder<List<GoalContribution>>(
                stream: repo.watchContributions(goalId),
                builder: (context, contribSnap) {
                  final contribs = contribSnap.data ?? [];
                  final progress = calculateGoalProgress(
                    goal: goal,
                    contributions: contribs,
                  );
                  return _buildContent(
                    context,
                    ref,
                    goal: goal,
                    progress: progress,
                    contributions: contribs,
                  );
                },
              );
            },
          );
        }

        return StreamBuilder<List<GoalContribution>>(
          stream: repo.watchContributions(goalId),
          builder: (context, contribSnap) {
            final contribs = contribSnap.data ?? item!.contributions;
            final progress = calculateGoalProgress(
              goal: item!.goal,
              contributions: contribs,
            );
            return _buildContent(
              context,
              ref,
              goal: item.goal,
              progress: progress,
              contributions: contribs,
            );
          },
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref, {
    required Goal goal,
    required GoalProgress progress,
    required List<GoalContribution> contributions,
  }) {
    final colors = context.pockt;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            GoalDetailAppBar(goal: goal),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                children: [
                  // Anillo central
                  GoalProgressRing(goal: goal, progress: progress),
                  const SizedBox(height: 20),

                  // Badge de estado
                  Center(child: GoalStatusBadge(progress: progress)),
                  const SizedBox(height: 24),

                  // Botones Aportar y Retirar
                  GoalActionButtons(goal: goal),
                  const SizedBox(height: 24),

                  // Métricas
                  GoalMetricsCard(goal: goal, progress: progress),
                  const SizedBox(height: 28),

                  // Historial de aportes
                  Text(
                    'Historial de aportes',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (contributions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No hay aportes registrados',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                    )
                  else
                    ...contributions.map(
                      (c) => GoalContributionTile(contribution: c),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
