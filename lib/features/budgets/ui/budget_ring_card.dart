import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/budgets/data/budgets_repository.dart';
import 'package:pockt/features/budgets/domain/budget_status.dart';
import 'package:pockt/features/budgets/ui/budget_alerts.dart';

export 'package:pockt/features/budgets/ui/budget_alerts.dart';

/// Anillo de progreso de presupuesto por categoría.
///
/// Muestra un arco circular animado con [PocktSprings.soft] representando el ratio
/// consumido del presupuesto. Cambia de color según el estado (categoría, advertencia ≥ 80 %,
/// peligro ≥ 100 %).
class BudgetRing extends StatefulWidget {
  final double ratio;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? child;

  const BudgetRing({
    super.key,
    required this.ratio,
    required this.color,
    this.size = 58,
    this.strokeWidth = 5,
    this.child,
  });

  @override
  State<BudgetRing> createState() => _BudgetRingState();
}

class _BudgetRingState extends State<BudgetRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _oldRatio = 0.0;

  @override
  void initState() {
    super.initState();
    _oldRatio = widget.ratio;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = AlwaysStoppedAnimation(widget.ratio);
  }

  @override
  void didUpdateWidget(BudgetRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ratio != widget.ratio) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _oldRatio = widget.ratio;
        return;
      }
      _oldRatio = _animation.value;
      _controller.reset();
      _animation = Tween<double>(begin: _oldRatio, end: widget.ratio).animate(
        CurvedAnimation(
          parent: _controller,
          curve: SpringCurve(spring: PocktSprings.soft),
        ),
      );
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final effectiveRatio = reduceMotion
                ? widget.ratio
                : _animation.value;
            return CustomPaint(
              painter: BudgetRingPainter(
                ratio: effectiveRatio,
                color: widget.color,
                strokeWidth: widget.strokeWidth,
              ),
              child: Center(child: widget.child),
            );
          },
        ),
      ),
    );
  }
}

class BudgetRingPainter extends CustomPainter {
  final double ratio;
  final Color color;
  final double strokeWidth;

  BudgetRingPainter({
    required this.ratio,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track de fondo sutil
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (ratio <= 0.0) return;

    final sweepAngle = (ratio.clamp(0.0, 1.0)) * 2 * pi;

    // Resplandor sutil cuando cruza a advertencia o exceso
    if (ratio >= 0.8) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth + 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        glowPaint,
      );
    }

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant BudgetRingPainter oldDelegate) {
    return oldDelegate.ratio != ratio ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class BudgetCard extends StatelessWidget {
  final BudgetView budgetView;
  final int spent;
  final VoidCallback onTap;

  const BudgetCard({
    super.key,
    required this.budgetView,
    required this.spent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = budgetStatus(spent, budgetView.budget.monthlyLimit);
    final effectiveColor = getBudgetEffectiveColor(
      status,
      budgetView.category,
      colors,
      isDark,
    );

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      child: Pressable(
        onTap: onTap,
        child: Row(
          children: [
            BudgetRing(
              ratio: status.ratio,
              color: effectiveColor,
              size: 58,
              strokeWidth: 5,
              child: categoryIcon(
                budgetView.category.icon,
                size: 22,
                color: effectiveColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        budgetView.category.name,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: effectiveColor.withValues(
                            alpha: isDark ? 0.20 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(PocktRadii.m),
                          border: Border.all(
                            color: effectiveColor.withValues(
                              alpha: isDark ? 0.40 : 0.25,
                            ),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${(status.ratio * 100).round()} %',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: effectiveColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatGs(spent),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          ' de ${formatGs(budgetView.budget.monthlyLimit)}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: colors.textTertiary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      status.remaining >= 0
                          ? 'Quedan ${formatGs(status.remaining)}'
                          : 'Excedido por ${formatGs(-status.remaining)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: status.level == BudgetLevel.over
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: status.level == BudgetLevel.over
                            ? colors.danger
                            : (status.level == BudgetLevel.warning
                                  ? colors.warning
                                  : colors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BudgetDetailSummaryCard extends StatelessWidget {
  final int spent;
  final int monthlyLimit;
  final BudgetStatus status;
  final Color effectiveColor;

  const BudgetDetailSummaryCard({
    super.key,
    required this.spent,
    required this.monthlyLimit,
    required this.status,
    required this.effectiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CustomPaint(
              painter: BudgetRingPainter(
                ratio: status.ratio,
                color: effectiveColor,
                strokeWidth: 6,
              ),
              child: Center(
                child: Text(
                  '${(status.ratio * 100).round()}%',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: effectiveColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gastado: ${formatGs(spent)}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tope: ${formatGs(monthlyLimit)}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: colors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status.remaining >= 0
                      ? 'Quedan: ${formatGs(status.remaining)}'
                      : 'Excedido: ${formatGs(-status.remaining)}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: status.level == BudgetLevel.over
                        ? colors.danger
                        : (status.level == BudgetLevel.warning
                              ? colors.warning
                              : colors.textSecondary),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
