import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pockt/core/design/tokens.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(16);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: radius,
        border: Border.all(
          color: colors.glassBorder,
          width: 1.0,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}

class GlassBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Border? border;

  const GlassBar({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final radius = borderRadius ?? BorderRadius.zero;

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: radius,
            border: border ??
                Border.all(
                  color: colors.glassBorder,
                  width: 1.0,
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}
