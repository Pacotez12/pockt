import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/goals/domain/goal_progress.dart';
import 'package:pockt/features/goals/ui/goal_editor.dart';
import 'package:pockt/features/goals/ui/goal_detail_actions.dart';
import 'package:pockt/features/goals/ui/goal_progress_ring_painter.dart';

class GoalDetailAppBar extends ConsumerWidget {
  final Goal goal;

  const GoalDetailAppBar({super.key, required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.read(goalsRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            child: Text(
              goal.name,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Pressable(
            semanticLabel: 'Editar meta',
            onTap: () {
              Haptics.tick();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GoalEditorScreen(goalId: goal.id),
                ),
              );
            },
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
                  uiIcon('pencil-simple'),
                  size: 18,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            key: const ValueKey('goal-options-menu'),
            tooltip: 'Más opciones',
            padding: EdgeInsets.zero,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.glassFill,
                border: Border.all(color: colors.glassBorder),
              ),
              child: Center(
                child: Icon(
                  uiIcon('dots-three-vertical'),
                  size: 18,
                  color: colors.textSecondary,
                ),
              ),
            ),
            color: colors.sheetSurface,
            onSelected: (val) async {
              if (val == 'archive') {
                Haptics.save();
                await repo.archiveGoal(goal.id, archived: !goal.archived);
              } else if (val == 'delete') {
                Haptics.danger();
                final confirm = await confirmDeleteGoal(context);
                if (confirm == true) {
                  await repo.deleteGoal(goal.id);
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'archive',
                child: Text(
                  goal.archived ? 'Desarchivar meta' : 'Archivar meta',
                  style: TextStyle(color: colors.textPrimary),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Eliminar meta',
                  style: TextStyle(color: colors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GoalProgressRing extends StatelessWidget {
  final Goal goal;
  final GoalProgress progress;

  const GoalProgressRing({
    super.key,
    required this.goal,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    return Center(
      child: SizedBox(
        width: 190,
        height: 190,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 170,
              height: 170,
              child: CustomPaint(
                painter: GoalProgressRingPainter(
                  percent: progress.percent,
                  trackColor: colors.glassBorder,
                  startColor: colors.brandStart,
                  endColor: colors.brandEnd,
                  strokeWidth: 14,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(uiIcon(goal.icon), size: 32, color: colors.brandAt(0)),
                const SizedBox(height: 6),
                Text(
                  '${(progress.percent * 100).toInt()} %',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  formatGs(progress.saved),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: PocktType.caption,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GoalStatusBadge extends StatelessWidget {
  final GoalProgress progress;

  const GoalStatusBadge({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final String statusText;
    final Color statusColor;
    if (progress.status is GoalStatusOnTrack) {
      statusText = progress.isCompleted ? '¡Meta cumplida!' : 'A tiempo';
      statusColor = colors.positive;
    } else if (progress.status is GoalStatusLate) {
      final late = progress.status as GoalStatusLate;
      statusText = late.months == 1
          ? '1 mes tarde'
          : '${late.months} meses tarde';
      statusColor = colors.warning;
    } else {
      statusText = 'Sin fecha límite';
      statusColor = colors.textTertiary;
    }
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(PocktRadii.xl),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          statusText,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: PocktType.caption,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      ),
    );
  }
}

class GoalMetricsCard extends StatelessWidget {
  final Goal goal;
  final GoalProgress progress;

  const GoalMetricsCard({
    super.key,
    required this.goal,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    return GlassCard(
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GoalStatRow(
            label: 'Objetivo total',
            value: formatGs(goal.targetAmount),
          ),
          Divider(height: 18, color: colors.glassBorder),
          GoalStatRow(label: 'Restante', value: formatGs(progress.remaining)),
          if (goal.targetDate != null) ...[
            Divider(height: 18, color: colors.glassBorder),
            GoalStatRow(
              label: 'Fecha objetivo',
              value: formatShortDate(goal.targetDate!),
            ),
            Divider(height: 18, color: colors.glassBorder),
            GoalStatRow(
              label: 'Ritmo necesario',
              value: progress.requiredMonthlyPace != null
                  ? '${formatGs(progress.requiredMonthlyPace!)} / mes'
                  : '-',
            ),
          ],
          Divider(height: 18, color: colors.glassBorder),
          GoalStatRow(
            label: 'Ritmo real',
            value: progress.realDailyPace > 0
                ? '${formatGs(progress.realMonthlyPace)} / mes'
                : 'Sin aportes recientes',
          ),
          if (progress.projectedFinishDate != null &&
              !progress.isCompleted) ...[
            Divider(height: 18, color: colors.glassBorder),
            GoalStatRow(
              label: 'Fecha proyectada',
              value: formatShortDate(progress.projectedFinishDate!),
            ),
          ],
        ],
      ),
    );
  }
}

class GoalStatRow extends StatelessWidget {
  final String label;
  final String value;

  const GoalStatRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: colors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class GoalContributionTile extends ConsumerWidget {
  final GoalContribution contribution;

  const GoalContributionTile({super.key, required this.contribution});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.read(goalsRepositoryProvider);
    final c = contribution;
    final isNegative = c.amount < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('contrib-${c.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: colors.danger,
            borderRadius: BorderRadius.circular(PocktRadii.l),
          ),
          child: Icon(uiIcon('trash'), color: Colors.white),
        ),
        onDismissed: (_) {
          Haptics.tick();
          repo.deleteContribution(c.id);
        },
        child: GlassCard(
          borderRadius: BorderRadius.circular(PocktRadii.l),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isNegative
                      ? colors.warning.withValues(alpha: 0.15)
                      : colors.positive.withValues(alpha: 0.15),
                ),
                child: Icon(
                  uiIcon(isNegative ? 'minus' : 'plus'),
                  size: 18,
                  color: isNegative ? colors.warning : colors.positive,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.note != null && c.note!.isNotEmpty
                          ? c.note!
                          : (isNegative ? 'Retiro' : 'Aporte'),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      formatShortDate(c.date),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${isNegative ? '-' : '+'}${formatGs(c.amount.abs())}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isNegative ? colors.warning : colors.positive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
