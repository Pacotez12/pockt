import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

abstract final class PocktSprings {
  /// Spring firme con amortiguación crítica (sin rebote) para respuestas táctiles inmediatas.
  static final SpringDescription firm = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 300.0,
    ratio: 1.0,
  );

  /// Spring suave con rebote mínimo para transiciones de hojas y elementos físicos.
  static final SpringDescription soft = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 180.0,
    ratio: 0.85,
  );
}

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final HitTestBehavior behavior;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: 1.0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    if (!mounted) return;
    if (_reduceMotion) {
      _controller.value = 1.0;
      return;
    }

    final simulation = SpringSimulation(
      PocktSprings.firm,
      _controller.value,
      target,
      _controller.velocity,
    );
    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: widget.behavior,
      onPointerDown: (_) => _animateTo(0.96),
      onPointerUp: (_) => _animateTo(1.0),
      onPointerCancel: (_) => _animateTo(1.0),
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = _reduceMotion ? 1.0 : _controller.value;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(scale, scale, scale),
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Curve that maps normalized time [0.0, 1.0] to a SpringSimulation.
class SpringCurve extends Curve {
  final SpringDescription spring;
  final double durationSeconds;

  const SpringCurve({
    required this.spring,
    this.durationSeconds = 0.35,
  });

  @override
  double transformInternal(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    final sim = SpringSimulation(spring, 0.0, 1.0, 0.0);
    return sim.x(t * durationSeconds);
  }
}

/// RectTween that interpolates between two Rects using PocktSprings.soft.
class SpringRectTween extends Tween<Rect?> {
  SpringRectTween({super.begin, super.end});

  static final _curve = SpringCurve(spring: PocktSprings.soft);

  @override
  Rect? lerp(double t) {
    return Rect.lerp(begin, end, _curve.transform(t));
  }
}
