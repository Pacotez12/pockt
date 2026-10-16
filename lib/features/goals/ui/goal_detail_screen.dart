import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/entry/ui/amount_keypad.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/goals/domain/goal_progress.dart';
import 'package:pockt/features/goals/ui/goal_editor.dart';

class GoalDetailScreen extends ConsumerWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  void _openKeypad(
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

  Future<bool?> _confirmDelete(BuildContext context) {
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
    final repo = ref.read(goalsRepositoryProvider);

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

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
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
                        await repo.archiveGoal(
                          goal.id,
                          archived: !goal.archived,
                        );
                      } else if (val == 'delete') {
                        Haptics.danger();
                        final confirm = await _confirmDelete(context);
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
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                children: [
                  // Anillo central
                  Center(
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
                              painter: _GoalProgressRingPainter(
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
                              Icon(
                                uiIcon(goal.icon),
                                size: 32,
                                color: colors.brandAt(0),
                              ),
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
                  ),
                  const SizedBox(height: 20),

                  // Badge de estado
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(PocktRadii.xl),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
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
                  ),
                  const SizedBox(height: 24),

                  // Botones Aportar y Retirar
                  Row(
                    children: [
                      Expanded(
                        child: Pressable(
                          key: const ValueKey('goal-contribute-button'),
                          semanticLabel: 'Aportar a meta',
                          onTap: () => _openKeypad(
                            context,
                            goal: goal,
                            isWithdraw: false,
                          ),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [colors.brandStart, colors.brandEnd],
                              ),
                              borderRadius: BorderRadius.circular(PocktRadii.l),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.brandStart.withValues(
                                    alpha: 0.25,
                                  ),
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
                                    Icon(
                                      uiIcon('plus'),
                                      color: Colors.white,
                                      size: 18,
                                    ),
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
                          onTap: () => _openKeypad(
                            context,
                            goal: goal,
                            isWithdraw: true,
                          ),
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
                  ),
                  const SizedBox(height: 24),

                  // Métricas
                  GlassCard(
                    borderRadius: BorderRadius.circular(PocktRadii.xl),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _statRow(
                          context,
                          label: 'Objetivo total',
                          value: formatGs(goal.targetAmount),
                        ),
                        Divider(height: 18, color: colors.glassBorder),
                        _statRow(
                          context,
                          label: 'Restante',
                          value: formatGs(progress.remaining),
                        ),
                        if (goal.targetDate != null) ...[
                          Divider(height: 18, color: colors.glassBorder),
                          _statRow(
                            context,
                            label: 'Fecha objetivo',
                            value: formatShortDate(goal.targetDate!),
                          ),
                          Divider(height: 18, color: colors.glassBorder),
                          _statRow(
                            context,
                            label: 'Ritmo necesario',
                            value: progress.requiredMonthlyPace != null
                                ? '${formatGs(progress.requiredMonthlyPace!)} / mes'
                                : '-',
                          ),
                        ],
                        Divider(height: 18, color: colors.glassBorder),
                        _statRow(
                          context,
                          label: 'Ritmo real',
                          value: progress.realDailyPace > 0
                              ? '${formatGs(progress.realMonthlyPace)} / mes'
                              : 'Sin aportes recientes',
                        ),
                        if (progress.projectedFinishDate != null &&
                            !progress.isCompleted) ...[
                          Divider(height: 18, color: colors.glassBorder),
                          _statRow(
                            context,
                            label: 'Fecha proyectada',
                            value: formatShortDate(
                              progress.projectedFinishDate!,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
                    ...contributions.map((c) {
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isNegative
                                        ? colors.warning.withValues(alpha: 0.15)
                                        : colors.positive.withValues(
                                            alpha: 0.15,
                                          ),
                                  ),
                                  child: Icon(
                                    uiIcon(isNegative ? 'minus' : 'plus'),
                                    size: 18,
                                    color: isNegative
                                        ? colors.warning
                                        : colors.positive,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.note != null && c.note!.isNotEmpty
                                            ? c.note!
                                            : (isNegative
                                                  ? 'Retiro'
                                                  : 'Aporte'),
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
                                    color: isNegative
                                        ? colors.warning
                                        : colors.positive,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
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

class _GoalProgressRingPainter extends CustomPainter {
  final double percent;
  final Color trackColor;
  final Color startColor;
  final Color endColor;
  final double strokeWidth;

  const _GoalProgressRingPainter({
    required this.percent,
    required this.trackColor,
    required this.startColor,
    required this.endColor,
    this.strokeWidth = 14,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final clamped = percent.clamp(0.0, 1.0);
    if (clamped <= 0) return;

    final sweepAngle = clamped * 2 * pi;
    final arcPaint = Paint()
      // El degradé recorre solo el tramo pintado, empezando arriba (-π/2).
      ..shader = SweepGradient(
        colors: [startColor, endColor],
        startAngle: 0,
        endAngle: sweepAngle,
        transform: const GradientRotation(-pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(rect, -pi / 2, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _GoalProgressRingPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor ||
        oldDelegate.trackColor != trackColor;
  }
}
