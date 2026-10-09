import 'package:flutter/material.dart';
import 'package:pockt/core/design/wordmark.dart';

/// Controlador y overlay de la animación de apertura (Apertura 2: "El orbe se convierte en el Inicio").
///
/// Características:
/// - Continúa el splash nativo del sistema sin corte visual.
/// - Rebote físico del orbe con [PocktSprings.soft] / curveada elástica.
/// - Logotipo [PocktWordmark] aparece debajo con fundido y leve ascenso.
/// - El orbe se disuelve mientras su resplandor viaja arriba y se posiciona
///   en la ubicación de `MonthGlow` del Inicio.
/// - El Inicio (`child`) entra con fundido y suave ascenso.
/// - Duración total ~1.1 s.
/// - Solo en arranque en frío (primer montaje).
/// - Tocar la pantalla la saltea de inmediato.
/// - Con [MediaQueryData.disableAnimations] se muestra directo sin animación.
class PocktSplash extends StatefulWidget {
  final Widget child;

  const PocktSplash({
    super.key,
    required this.child,
  });

  /// Bandera estática para asegurar que la animación solo corra en arranque en frío.
  static bool hasShownSplash = false;

  /// Método para resetear la bandera durante pruebas.
  static void resetForTesting() {
    hasShownSplash = false;
  }

  @override
  State<PocktSplash> createState() => _PocktSplashState();
}

class _PocktSplashState extends State<PocktSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _shouldAnimate = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    if (!PocktSplash.hasShownSplash) {
      _shouldAnimate = true;
      PocktSplash.hasShownSplash = true;
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shouldAnimate && MediaQuery.disableAnimationsOf(context)) {
      _shouldAnimate = false;
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    if (_controller.isCompleted) return;
    _controller.stop();
    _controller.value = 1.0;
    setState(() {});
  }

  double _evaluateOrbScale(double t) {
    if (t <= 0.45) {
      // 0.0 .. 0.45: spring bounce de 0.85 -> 1.04 -> 1.0
      final p = (t / 0.45).clamp(0.0, 1.0);
      final spring = Curves.easeOutBack.transform(p);
      return 0.85 + (1.0 - 0.85) * spring;
    } else {
      // 0.45 .. 1.0: se expande a 3.2 mientras se disuelve
      final p = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
      final expand = const Cubic(0.65, 0.0, 0.35, 1.0).transform(p);
      return 1.0 + (3.2 - 1.0) * expand;
    }
  }

  double _evaluateOrbOpacity(double t) {
    if (t <= 0.45) {
      return 1.0;
    }
    final p = ((t - 0.45) / 0.40).clamp(0.0, 1.0);
    return 1.0 - const Cubic(0.65, 0.0, 0.35, 1.0).transform(p);
  }

  Offset _evaluateGlowCenter(double t, Size screenSize) {
    final startCenter = Offset(screenSize.width / 2, screenSize.height * 0.44);
    // Coordenadas donde se ubica el MonthGlow en el Inicio (top: -140, tamaño: 470x470)
    final endCenter = Offset(screenSize.width / 2, -140.0 + (470.0 / 2));

    if (t <= 0.35) {
      return startCenter;
    }
    final p = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
    final curveP = const Cubic(0.65, 0.0, 0.35, 1.0).transform(p);
    return Offset.lerp(startCenter, endCenter, curveP)!;
  }

  double _evaluateGlowSize(double t) {
    const startSize = 280.0;
    const endSize = 470.0;
    if (t <= 0.35) {
      return startSize;
    }
    final p = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
    final curveP = const Cubic(0.65, 0.0, 0.35, 1.0).transform(p);
    return startSize + (endSize - startSize) * curveP;
  }

  double _evaluateGlowOpacity(double t) {
    if (t <= 0.25) {
      final p = (t / 0.25).clamp(0.0, 1.0);
      return Curves.easeOut.transform(p);
    }
    return 1.0;
  }

  double _evaluateWordmarkOpacity(double t) {
    if (t < 0.20) return 0.0;
    if (t <= 0.40) {
      return ((t - 0.20) / 0.20).clamp(0.0, 1.0);
    }
    if (t <= 0.55) return 1.0;
    if (t <= 0.80) {
      return 1.0 - ((t - 0.55) / 0.25).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  double _evaluateWordmarkOffset(double t) {
    if (t < 0.20) return 8.0;
    if (t <= 0.40) {
      final p = ((t - 0.20) / 0.20).clamp(0.0, 1.0);
      return 8.0 * (1.0 - Curves.easeOut.transform(p));
    }
    return 0.0;
  }

  double _evaluateChildOpacity(double t) {
    if (t < 0.55) return 0.0;
    final p = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
    return Curves.easeOut.transform(p);
  }

  double _evaluateChildOffset(double t) {
    if (t < 0.55) return 12.0;
    final p = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
    return 12.0 * (1.0 - Curves.easeOutCubic.transform(p));
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldAnimate || _controller.value >= 1.0) {
      return widget.child;
    }

    final media = MediaQuery.of(context);
    final screenSize = media.size;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _skip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          if (t >= 1.0) {
            return widget.child;
          }

          final childOpacity = _evaluateChildOpacity(t);
          final childOffset = _evaluateChildOffset(t);

          final orbScale = _evaluateOrbScale(t);
          final orbOpacity = _evaluateOrbOpacity(t);

          final glowCenter = _evaluateGlowCenter(t, screenSize);
          final glowSize = _evaluateGlowSize(t);
          final glowOpacity = _evaluateGlowOpacity(t);

          final wordmarkOpacity = _evaluateWordmarkOpacity(t);
          final wordmarkOffset = _evaluateWordmarkOffset(t);

          const orbBaseSize = 110.0;
          final orbCenterY = screenSize.height * 0.44;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Fondo negro idéntico al splash del sistema
              const ColoredBox(color: Colors.black),

              // Contenido de la app que entra gradualmente
              if (childOpacity > 0.0)
                Positioned.fill(
                  child: Opacity(
                    opacity: childOpacity,
                    child: Transform.translate(
                      offset: Offset(0, childOffset),
                      child: widget.child,
                    ),
                  ),
                ),

              // Resplandor del orbe viajando hacia el MonthGlow del Inicio
              if (orbOpacity > 0.0 || t < 1.0)
                Positioned(
                  left: glowCenter.dx - (glowSize / 2),
                  top: glowCenter.dy - (glowSize / 2),
                  child: IgnorePointer(
                    child: Container(
                      width: glowSize,
                      height: glowSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFF8A3D)
                                .withValues(alpha: 0.65 * glowOpacity),
                            const Color(0xFFFF3D7F)
                                .withValues(alpha: 0.25 * glowOpacity),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 0.75],
                        ),
                      ),
                    ),
                  ),
                ),

              // Orbe central con rebote spring y posterior disolución
              if (orbOpacity > 0.0)
                Positioned(
                  left: (screenSize.width - orbBaseSize) / 2,
                  top: orbCenterY - (orbBaseSize / 2),
                  child: IgnorePointer(
                    child: Transform.scale(
                      scale: orbScale,
                      child: Opacity(
                        opacity: orbOpacity,
                        child: const PocktOrb(
                          size: orbBaseSize,
                          showGlow: false,
                        ),
                      ),
                    ),
                  ),
                ),

              // Logotipo 'pockt' que aparece debajo del orbe
              if (wordmarkOpacity > 0.0)
                Positioned(
                  left: 0,
                  right: 0,
                  top: orbCenterY + (orbBaseSize / 2) + 20,
                  child: Center(
                    child: IgnorePointer(
                      child: Transform.translate(
                        offset: Offset(0, wordmarkOffset),
                        child: Opacity(
                          opacity: wordmarkOpacity,
                          child: const PocktWordmark(
                            size: 34,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
