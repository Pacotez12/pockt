import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';

/// "Arco de hoy" del Inicio (spec §7d-bis): semicírculo que se llena con lo
/// gastado hoy contra el límite del día, con lo que te queda en el centro.
class TodayArc extends StatelessWidget {
  final int allowance;
  final int spent;
  final bool obscure;
  final bool reduceMotion;

  /// false sin esquema de cobro: el período corre hasta fin de mes.
  final bool untilPayday;

  const TodayArc({
    super.key,
    required this.allowance,
    required this.spent,
    this.obscure = false,
    this.reduceMotion = false,
    this.untilPayday = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final noMargin = allowance <= 0;
    final over = !noMargin && spent > allowance;
    final progress = noMargin ? 0.0 : (spent / allowance).clamp(0.0, 1.0);

    String gs(int v) => obscure ? '••••' : formatGs(v);
    final String title;
    final String amount;
    final String detail;
    if (noMargin) {
      title = untilPayday
          ? 'No queda margen hasta el cobro'
          : 'No queda margen este mes';
      amount = gs(allowance);
      detail = 'gastaste ${gs(spent)} hoy';
    } else if (over) {
      title = 'Te pasaste hoy';
      amount = gs(spent - allowance);
      detail = 'gastaste ${gs(spent)} de ${gs(allowance)}';
    } else {
      title = 'Te quedan hoy';
      amount = gs(allowance - spent);
      detail = 'gastaste ${gs(spent)} de ${gs(allowance)}';
    }
    final alert = noMargin || over;

    return Semantics(
      label: '$title $amount, $detail',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1.75,
        child: LayoutBuilder(
          builder: (context, box) {
            final stroke = 10.0;
            return Stack(
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => CustomPaint(
                      painter: _TodayArcPainter(
                        progress: value,
                        stroke: stroke,
                        // glassBorder: glassFill casi no se ve en modo claro.
                        track: alert && progress == 0
                            ? colors.danger.withValues(alpha: 0.35)
                            : colors.glassBorder,
                        start: over ? colors.danger : colors.brandStart,
                        end: over ? colors.danger : colors.brandEnd,
                      ),
                    ),
                  ),
                ),
                // Texto dentro del semicírculo, lejos del trazo.
                Positioned(
                  left: box.maxWidth * 0.16,
                  right: box.maxWidth * 0.16,
                  top: box.maxHeight * 0.36,
                  bottom: box.maxHeight * 0.02,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: PocktType.caption,
                            color: alert ? colors.danger : colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          amount,
                          key: const ValueKey('today-arc-amount'),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.2,
                            height: 1,
                            color: alert ? colors.danger : colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          detail,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: PocktType.caption,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TodayArcPainter extends CustomPainter {
  final double progress;
  final double stroke;
  final Color track;
  final Color start;
  final Color end;

  const _TodayArcPainter({
    required this.progress,
    required this.stroke,
    required this.track,
    required this.start,
    required this.end,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Semicírculo apoyado en la base: radio limitado por ancho y alto.
    final radius = min(size.width / 2, size.height) - stroke / 2;
    final center = Offset(size.width / 2, size.height - stroke / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, pi, pi, false, base..color = track);

    if (progress <= 0) return;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      // El degradé recorre solo el tramo pintado, así se ve aunque sea corto.
      ..shader = SweepGradient(
        colors: [start, end],
        startAngle: pi,
        endAngle: pi + max(pi * progress, 0.01),
      ).createShader(rect);
    canvas.drawArc(rect, pi, pi * progress, false, fill);
  }

  @override
  bool shouldRepaint(covariant _TodayArcPainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.start != start ||
      old.end != end;
}
