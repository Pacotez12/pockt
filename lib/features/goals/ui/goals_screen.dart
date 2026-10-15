import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/goals/domain/goal_progress.dart';
import 'package:pockt/features/goals/ui/goal_detail_screen.dart';
import 'package:pockt/features/goals/ui/goal_editor.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  String _formatGs(int amount) {
    final formatter = NumberFormat('#,###', 'es_PY');
    return '₲ ${formatter.format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final repo = ref.watch(goalsRepositoryProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: StreamBuilder<List<GoalWithProgress>>(
          stream: repo.watchActiveWithProgress(),
          builder: (context, snapshot) {
            final activeGoals = snapshot.data ?? [];
            final totalSaved = activeGoals.fold<int>(
              0,
              (sum, item) => sum + item.progress.saved,
            );

            return Column(
              children: [
                // AppBar / Header superior
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                              'Metas de ahorro',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              'Ahorro para objetivos con proyección',
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
                        key: const ValueKey('add-goal-button'),
                        semanticLabel: 'Agregar meta',
                        onTap: () {
                          Haptics.tick();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const GoalEditorScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [colors.brandStart, colors.brandEnd],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.brandStart.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              uiIcon('plus'),
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenido de la lista
                Expanded(
                  child: activeGoals.isEmpty
                      ? _buildEmptyState(context)
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          children: [
                            // Encabezado Opción B: "Ahorrado: Gs. X en N metas"
                            GlassCard(
                              borderRadius: BorderRadius.circular(
                                PocktRadii.xl,
                              ),
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colors
                                          .brandAt(0)
                                          .withValues(alpha: 0.15),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        uiIcon('target'),
                                        size: 24,
                                        color: colors.brandAt(0),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Ahorrado total',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatGs(totalSaved),
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.glassFill,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: colors.glassBorder,
                                      ),
                                    ),
                                    child: Text(
                                      '${activeGoals.length} ${activeGoals.length == 1 ? 'meta' : 'metas'}',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colors.brandAt(0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Lista de tarjetas de metas
                            ...activeGoals.map((item) {
                              return _buildGoalCard(context, item);
                            }),
                            const SizedBox(height: 20),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, GoalWithProgress item) {
    final colors = context.pockt;
    final goal = item.goal;
    final progress = item.progress;

    final String statusText;
    final Color statusColor;
    if (progress.status is GoalStatusOnTrack) {
      statusText = progress.isCompleted ? '¡Cumplida!' : 'A tiempo';
      statusColor = colors.positive;
    } else if (progress.status is GoalStatusLate) {
      final late = progress.status as GoalStatusLate;
      statusText = late.months == 1
          ? '1 mes tarde'
          : '${late.months} meses tarde';
      statusColor = colors.warning;
    } else {
      statusText = 'Sin fecha';
      statusColor = colors.textTertiary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Pressable(
        key: ValueKey('goal-card-${goal.id}'),
        onTap: () {
          Haptics.tick();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GoalDetailScreen(goalId: goal.id),
            ),
          );
        },
        child: GlassCard(
          borderRadius: BorderRadius.circular(PocktRadii.xl),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: ícono, nombre, fecha y estado
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.brandAt(0).withValues(alpha: 0.15),
                      border: Border.all(
                        color: colors.brandAt(0).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        uiIcon(goal.icon),
                        size: 20,
                        color: colors.brandAt(0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          goal.targetDate != null
                              ? 'Meta: ${formatShortDate(goal.targetDate!)}'
                              : 'Sin fecha límite',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge de estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Barra de progreso con degradé de marca
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 7,
                  child: Stack(
                    children: [
                      Container(color: colors.glassBorder),
                      FractionallySizedBox(
                        widthFactor: progress.percent,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colors.brandStart, colors.brandEnd],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Fila inferior: montos y porcentaje / ritmo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatGs(progress.saved)} de ${_formatGs(goal.targetAmount)}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  Text(
                    '${(progress.percent * 100).toInt()} %',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.brandAt(0),
                    ),
                  ),
                ],
              ),
              if (progress.requiredMonthlyPace != null &&
                  !progress.isCompleted) ...[
                const SizedBox(height: 4),
                Text(
                  'Ritmo: ${_formatGs(progress.requiredMonthlyPace!)} / mes',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.pockt;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.brandAt(0).withValues(alpha: 0.12),
              ),
              child: Center(
                child: Icon(
                  uiIcon('target'),
                  size: 32,
                  color: colors.brandAt(0),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No tenés metas activas',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Creá objetivos de ahorro para vacaciones, compras o tu fondo de emergencia.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Pressable(
              onTap: () {
                Haptics.tick();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GoalEditorScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.brandStart, colors.brandEnd],
                  ),
                  borderRadius: BorderRadius.circular(PocktRadii.l),
                ),
                child: const Text(
                  'Crear primera meta',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
