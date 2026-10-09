import 'package:flutter/material.dart';
import 'package:pockt/core/design/tokens.dart';

/// Painter para el punto-orbe al final del logotipo.
///
/// Diámetro de 0.22 * size, degradado radial del orbe:
/// #ffb07a (offset 0.0) -> #ff6a52 (offset 0.5) -> #e8306f (offset 1.0)
/// con centro en 35% x / 30% y y halo suave alrededor.
class OrbDotPainter extends CustomPainter {
  const OrbDotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Halo suave (soft glow similar a box-shadow: 0 0 .35em rgba(255,106,82,.7))
    final glowPaint = Paint()
      ..color = const Color(0xB3FF6A52) // rgba(255, 106, 82, 0.70)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.8);
    canvas.drawCircle(center, radius * 0.9, glowPaint);

    // Orbe con degradado radial
    final orbRect = Rect.fromCircle(center: center, radius: radius);
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.4), // 35% cx, 30% cy
      radius: 0.8,
      colors: const [
        Color(0xFFFFB07A),
        Color(0xFFFF6A52),
        Color(0xFFE8306F),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final orbPaint = Paint()..shader = gradient.createShader(orbRect);
    canvas.drawCircle(center, radius, orbPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter vectorial del orbe de marca completo (108x108 escala).
class PocktOrbPainter extends CustomPainter {
  final bool showGlow;

  const PocktOrbPainter({this.showGlow = true});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 108.0;
    final center = Offset(size.width / 2, size.height / 2);

    if (showGlow) {
      final glowRadius = 38.0 * scale;
      final glowRect = Rect.fromCircle(center: center, radius: glowRadius);
      final glowGradient = RadialGradient(
        center: Alignment.center,
        radius: 0.5,
        colors: [
          const Color(0xFFFF7A45).withValues(alpha: 0.70),
          const Color(0xFFFF3D7F).withValues(alpha: 0.25),
          const Color(0xFFFF3D7F).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      );
      final glowPaint = Paint()..shader = glowGradient.createShader(glowRect);
      canvas.drawCircle(center, glowRadius, glowPaint);
    }

    // Orbe
    final orbRadius = 26.0 * scale;
    final orbRect = Rect.fromCircle(center: center, radius: orbRadius);
    final orbGradient = RadialGradient(
      center: const Alignment(-0.3, -0.4), // cx .35, cy .3
      radius: 0.8,
      colors: const [
        Color(0xFFFFB07A),
        Color(0xFFFF6A52),
        Color(0xFFE8306F),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    final orbPaint = Paint()..shader = orbGradient.createShader(orbRect);
    canvas.drawCircle(center, orbRadius, orbPaint);

    // Abertura del bolsillo
    final path = Path()
      ..moveTo(40.0 * scale, 50.0 * scale)
      ..arcToPoint(
        Offset(68.0 * scale, 50.0 * scale),
        radius: Radius.circular(16.0 * scale),
        clockwise: true,
      );

    final pocketPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 5.0 * scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, pocketPaint);
  }

  @override
  bool shouldRepaint(covariant PocktOrbPainter oldDelegate) =>
      oldDelegate.showGlow != showGlow;
}

/// Widget del orbe de marca completo.
class PocktOrb extends StatelessWidget {
  final double size;
  final bool showGlow;

  const PocktOrb({
    super.key,
    this.size = 120.0,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: PocktOrbPainter(showGlow: showGlow),
      ),
    );
  }
}

/// Logotipo "pockt" oficial (Opción D: minúsculas con punto-orbe de luz).
///
/// Texto 'pockt' Inter peso 800, tracking -0.06*size, color del token de texto
/// primario, con punto-orbe pintado con [OrbDotPainter] (diámetro 0.22*size)
/// alineado a la línea de base.
class PocktWordmark extends StatelessWidget {
  final double size;
  final Color? color;

  const PocktWordmark({
    super.key,
    this.size = 32.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? context.pockt.textPrimary;
    final dotSize = 0.22 * size;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          'pockt',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: size,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.06 * size,
            color: textColor,
            height: 1.0,
          ),
        ),
        SizedBox(width: 0.05 * size),
        Baseline(
          baseline: dotSize + (0.06 * size),
          baselineType: TextBaseline.alphabetic,
          child: SizedBox(
            width: dotSize,
            height: dotSize,
            child: const CustomPaint(
              painter: OrbDotPainter(),
            ),
          ),
        ),
      ],
    );
  }
}
