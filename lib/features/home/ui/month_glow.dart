import 'package:flutter/material.dart';

/// Resplandor ambiental de mes pintado con degradado radial (sin BackdropFilter ni ImageFilter).
/// Pintado en un [CustomPaint] con [isComplex: true] y [willChange: false] dentro de
/// un [RepaintBoundary] para que el motor de renderizado guarde en caché de raster
/// la textura de 470 dp en lugar de reevaluar el shader de degradado en cada cuadro.
/// La transición entre colores de mes se anima mediante fundido cruzado (~900 ms).
class MonthGlow extends StatefulWidget {
  final Color color;

  const MonthGlow({super.key, required this.color});

  @override
  State<MonthGlow> createState() => _MonthGlowState();
}

class _MonthGlowState extends State<MonthGlow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Color? _previousColor;
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.color;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(MonthGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color != oldWidget.color) {
      if (MediaQuery.disableAnimationsOf(context)) {
        setState(() {
          _currentColor = widget.color;
          _previousColor = null;
        });
        return;
      }
      _previousColor = _currentColor;
      _currentColor = widget.color;
      _controller.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() {
            _previousColor = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildGlowLayer(Color c, bool isDark) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(470, 470),
        isComplex: true,
        willChange: false,
        painter: _MonthGlowPainter(color: c, isDark: isDark),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentGlow = _buildGlowLayer(_currentColor, isDark);

    if (_previousColor == null) {
      return IgnorePointer(
        child: SizedBox(
          width: 470,
          height: 470,
          child: currentGlow,
        ),
      );
    }

    final previousGlow = _buildGlowLayer(_previousColor!, isDark);

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    return IgnorePointer(
      child: SizedBox(
        width: 470,
        height: 470,
        child: Stack(
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.0).animate(curved),
              child: previousGlow,
            ),
            FadeTransition(
              opacity: curved,
              child: currentGlow,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthGlowPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  const _MonthGlowPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: isDark ? 0.50 : 0.28),
          color.withValues(alpha: isDark ? 0.20 : 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 0.70],
      ).createShader(rect);
    canvas.drawCircle(rect.center, size.width / 2, paint);
  }

  @override
  bool shouldRepaint(_MonthGlowPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isDark != isDark;
  }
}
