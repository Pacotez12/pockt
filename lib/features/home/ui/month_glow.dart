import 'package:flutter/material.dart';

/// Resplandor ambiental de mes pintado con degradado radial (sin BackdropFilter ni ImageFilter).
/// Color animado lentamente con [TweenAnimationBuilder] (~900 ms).
class MonthGlow extends StatelessWidget {
  final Color color;

  const MonthGlow({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      tween: ColorTween(end: color),
      builder: (context, animatedColor, _) {
        final c = animatedColor ?? color;
        return IgnorePointer(
          child: Container(
            width: 470,
            height: 470,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  c.withValues(alpha: isDark ? 0.50 : 0.28),
                  c.withValues(alpha: isDark ? 0.20 : 0.10),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.42, 0.70],
              ),
            ),
          ),
        );
      },
    );
  }
}
