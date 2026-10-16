import 'package:flutter/material.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';

/// Pastilla de categoría con Hero compartido entre el selector y el teclado.
class CategoryHeroPill extends StatelessWidget {
  final Category category;

  const CategoryHeroPill({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = Color(
      isDark ? category.colorDark : category.colorLight,
    );
    return HeroMode(
      enabled: !MediaQuery.disableAnimationsOf(context),
      child: Hero(
        tag: 'cat-${category.id}',
        createRectTween: (begin, end) =>
            SpringRectTween(begin: begin, end: end),
        flightShuttleBuilder:
            (
              flightContext,
              animation,
              flightDirection,
              fromHeroContext,
              toHeroContext,
            ) {
              final catColor = Color(
                isDark ? category.colorDark : category.colorLight,
              );
              final pillBg = categoryColor.withValues(
                alpha: isDark ? 0.22 : 0.14,
              );
              final targetBorderAlpha = isDark ? 0.6 : 0.4;
              final targetShadowAlpha = isDark ? 0.35 : 0.20;

              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final t = animation.value.clamp(0.0, 1.0);
                  final bg = Color.lerp(catColor, pillBg, t)!;
                  final radius = BorderRadius.circular(29.0 - 9.0 * t);
                  final borderAlpha = targetBorderAlpha * t;
                  final shadowAlpha = targetShadowAlpha * (1.0 - t);
                  final shadowOffset = Offset(0, 4.0 * (1.0 - t));

                  // Cross-fade: Version A (icono centrado oscuro) se desvanece de 0 a 0.45;
                  // Version B (fila con icono y texto nítido) entra de 0.35 a 0.8.
                  final alphaA = ((0.45 - t) / 0.45).clamp(0.0, 1.0);
                  final alphaB = ((t - 0.35) / 0.45).clamp(0.0, 1.0);

                  return RepaintBoundary(
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        key: ValueKey('hero-flight-cat-${category.id}'),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: radius,
                          border: borderAlpha > 0.01
                              ? Border.all(
                                  color: categoryColor.withValues(
                                    alpha: borderAlpha,
                                  ),
                                  width: 1,
                                )
                              : null,
                          boxShadow: shadowAlpha > 0.01
                              ? [
                                  BoxShadow(
                                    color: catColor.withValues(
                                      alpha: shadowAlpha,
                                    ),
                                    blurRadius: 14.0,
                                    offset: shadowOffset,
                                  ),
                                ]
                              : null,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          alignment: Alignment.center,
                          children: [
                            if (alphaA > 0.01)
                              Center(
                                child: categoryIcon(
                                  category.icon,
                                  size: 28,
                                  color: colors.keypadKey.withValues(
                                    alpha: alphaA,
                                  ),
                                ),
                              ),
                            if (alphaB > 0.01)
                              Center(
                                child: OverflowBox(
                                  maxWidth: double.infinity,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      categoryIcon(
                                        category.icon,
                                        size: 20,
                                        color: colors.textPrimary.withValues(
                                          alpha: alphaB,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        category.name,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: colors.textPrimary.withValues(
                                            alpha: alphaB,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: isDark ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(PocktRadii.xl),
              border: Border.all(
                color: categoryColor.withValues(alpha: isDark ? 0.6 : 0.4),
                width: 1,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  categoryIcon(
                    category.icon,
                    size: 20,
                    color: colors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
