import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Color glowAmber = Color(0xFFFF9F43);
const Color glowRedPink = Color(0xFFFF3D7F);

@visibleForTesting
bool debugDisableAuroraDrift = false;

/// Función pura que calcula el tinte del resplandor según la relación
/// de gasto del mes respecto al presupuesto total:
/// - `< 0.8` o `null` (sin presupuestos): devuelve [base] sin mezcla.
/// - `0.8` a `1.0`: se mezcla gradualmente hacia ámbar ([glowAmber]).
/// - `>= 1.0`: devuelve rojo-rosa ([glowRedPink]).
Color glowTint(Color base, double? spentRatio) {
  if (spentRatio == null || spentRatio < 0.8) {
    return base;
  }
  if (spentRatio >= 1.0) {
    return glowRedPink;
  }
  final t = (spentRatio - 0.8) / 0.2;
  return Color.lerp(base, glowAmber, t)!;
}

final monthGlowPulseProvider =
    NotifierProvider<MonthGlowPulseNotifier, int>(MonthGlowPulseNotifier.new);

class MonthGlowPulseNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void pulse() {
    state++;
  }
}

/// Resplandor aurora ambiental de mes (maqueta A sutil, dos manchas).
/// Cada mancha se pinta una sola vez con [CustomPaint] ([isComplex: true],
/// [willChange: false]) dentro de un [RepaintBoundary], y la deriva lenta
/// (~22 s y ~26 s, ida y vuelta) se aplica ÚNICAMENTE mediante [Transform]
/// (traslación + escala) por encima de la capa cacheada, sin repintar el
/// degradado en cada cuadro. Con [MediaQuery.disableAnimations] quedan quietas.
/// El pulso al guardar un movimiento anima la escala de 1.0 -> 1.08 -> 1.0 (~500 ms).
class MonthGlow extends StatefulWidget {
  final Color color;
  final Object? pulseTrigger;
  final bool? animateDrift;

  const MonthGlow({
    super.key,
    required this.color,
    this.pulseTrigger,
    this.animateDrift,
  });

  @override
  State<MonthGlow> createState() => _MonthGlowState();
}

class _MonthGlowState extends State<MonthGlow>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _drift1Controller;
  late AnimationController _drift2Controller;

  late Animation<double> _pulseAnimation;
  late Animation<double> _drift1Curved;
  late Animation<double> _drift2Curved;

  Color? _previousColor;
  late Color _currentColor;

  bool get _shouldDrift {
    if (widget.animateDrift != null) return widget.animateDrift!;
    if (debugDisableAuroraDrift) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _currentColor = widget.color;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 60.0,
      ),
    ]).animate(_pulseController);

    _drift1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    );
    _drift1Curved = CurvedAnimation(
      parent: _drift1Controller,
      curve: Curves.easeInOut,
    );

    _drift2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    );
    _drift2Curved = CurvedAnimation(
      parent: _drift2Controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.disableAnimationsOf(context);
    if (disable || !_shouldDrift) {
      if (_drift1Controller.isAnimating) _drift1Controller.stop();
      if (_drift2Controller.isAnimating) _drift2Controller.stop();
      if (disable && _pulseController.isAnimating) _pulseController.stop();
    } else {
      if (!_drift1Controller.isAnimating) {
        _drift1Controller.repeat(reverse: true);
      }
      if (!_drift2Controller.isAnimating) {
        _drift2Controller.repeat(reverse: true);
      }
    }
  }

  @override
  void didUpdateWidget(MonthGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateDrift != oldWidget.animateDrift) {
      final disable = MediaQuery.disableAnimationsOf(context);
      if (disable || !_shouldDrift) {
        if (_drift1Controller.isAnimating) _drift1Controller.stop();
        if (_drift2Controller.isAnimating) _drift2Controller.stop();
      } else {
        if (!_drift1Controller.isAnimating) {
          _drift1Controller.repeat(reverse: true);
        }
        if (!_drift2Controller.isAnimating) {
          _drift2Controller.repeat(reverse: true);
        }
      }
    }

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
      _fadeController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() {
            _previousColor = null;
          });
        }
      });
    }

    if (widget.pulseTrigger != oldWidget.pulseTrigger &&
        widget.pulseTrigger != null) {
      _triggerPulse();
    }
  }

  void _triggerPulse() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _pulseController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _drift1Controller.dispose();
    _drift2Controller.dispose();
    super.dispose();
  }

  Widget _buildCachedSpot(Color c, bool isDark, {required double size, required double opacity}) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(size, size),
        isComplex: true,
        willChange: false,
        painter: _MonthGlowPainter(
          color: c,
          isDark: isDark,
          opacityMultiplier: opacity,
        ),
      ),
    );
  }

  Widget _buildAurora(Color c, bool isDark) {
    final spot1 = _buildCachedSpot(c, isDark, size: 470, opacity: 0.85);
    final spot2 = _buildCachedSpot(c, isDark, size: 470, opacity: 0.65);

    return AnimatedBuilder(
      animation: Listenable.merge([_drift1Controller, _drift2Controller]),
      builder: (context, _) {
        final disable = MediaQuery.disableAnimationsOf(context);
        final offset1 = disable
            ? Offset.zero
            : Offset(
                -14.0 + 28.0 * _drift1Curved.value,
                -10.0 + 20.0 * _drift1Curved.value,
              );
        final scale1 = disable ? 1.0 : (0.96 + 0.09 * _drift1Curved.value);

        final offset2 = disable
            ? Offset.zero
            : Offset(
                12.0 - 24.0 * _drift2Curved.value,
                -8.0 + 18.0 * _drift2Curved.value,
              );
        final scale2 = disable ? 1.0 : (1.04 - 0.10 * _drift2Curved.value);

        return Stack(
          children: [
            Transform.translate(
              offset: offset1,
              child: Transform.scale(
                scale: scale1,
                child: spot1,
              ),
            ),
            Transform.translate(
              offset: offset2,
              child: Transform.scale(
                scale: scale2,
                child: spot2,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentAurora = _buildAurora(_currentColor, isDark);

    final Widget content;
    if (_previousColor == null) {
      content = currentAurora;
    } else {
      final previousAurora = _buildAurora(_previousColor!, isDark);
      final curved = CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      );

      content = Stack(
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.0).animate(curved),
            child: previousAurora,
          ),
          FadeTransition(
            opacity: curved,
            child: currentAurora,
          ),
        ],
      );
    }

    return IgnorePointer(
      child: SizedBox(
        width: 470,
        height: 470,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: content,
        ),
      ),
    );
  }
}

class _MonthGlowPainter extends CustomPainter {
  final Color color;
  final bool isDark;
  final double opacityMultiplier;

  const _MonthGlowPainter({
    required this.color,
    required this.isDark,
    this.opacityMultiplier = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final alpha1 = (isDark ? 0.45 : 0.25) * opacityMultiplier;
    final alpha2 = (isDark ? 0.18 : 0.08) * opacityMultiplier;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha1),
          color.withValues(alpha: alpha2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 0.70],
      ).createShader(rect);
    canvas.drawCircle(rect.center, size.width / 2, paint);
  }

  @override
  bool shouldRepaint(_MonthGlowPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isDark != isDark ||
        oldDelegate.opacityMultiplier != opacityMultiplier;
  }
}
