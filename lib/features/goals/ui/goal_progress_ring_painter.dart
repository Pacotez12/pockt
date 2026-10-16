import 'dart:math';

import 'package:flutter/material.dart';

class GoalProgressRingPainter extends CustomPainter {
  final double percent;
  final Color trackColor;
  final Color startColor;
  final Color endColor;
  final double strokeWidth;

  const GoalProgressRingPainter({
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
  bool shouldRepaint(covariant GoalProgressRingPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor ||
        oldDelegate.trackColor != trackColor;
  }
}
