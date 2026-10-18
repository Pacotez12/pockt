import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/amounts_privacy.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/home/data/home_providers.dart';
import 'package:pockt/features/home/domain/category_arc_data.dart';
import 'package:pockt/features/home/ui/home_top_bar.dart';

/// Widget interactivo "Arco por categoría" (Inicio spec §7d-ter):
/// - Semicírculo proporcional por categoría, de mayor a menor de izquierda a derecha.
/// - Máximo 5 tramos (top 4 + "Otros").
/// - Centro reactivo al total y al tramo seleccionado.
/// - Lista de categorías debajo con cuadradito, nombre, % y monto alineados.
/// - Tocar un tramo o una fila resalta esa categoría y actualiza el centro.
class CategoryArc extends ConsumerStatefulWidget {
  final int year;
  final int month;
  final DateTime nowLocal;

  const CategoryArc({
    super.key,
    required this.year,
    required this.month,
    required this.nowLocal,
  });

  @override
  ConsumerState<CategoryArc> createState() => _CategoryArcState();
}

class _CategoryArcState extends ConsumerState<CategoryArc> {
  String? _selectedSegmentId;

  void _toggleSegment(String id) {
    Haptics.tick();
    setState(() {
      if (_selectedSegmentId == id) {
        _selectedSegmentId = null;
      } else {
        _selectedSegmentId = id;
      }
    });
  }

  void _clearSelection() {
    if (_selectedSegmentId != null) {
      Haptics.tick();
      setState(() {
        _selectedSegmentId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final obscure = ref.watch(shouldObscureAmountsProvider);
    final reduceMotion = ref.watch(motionReduceProvider).value ?? false;
    final monthNameLower = kMonthNames[widget.month - 1].toLowerCase();

    final categoryTotals = ref.watch(
          homeCategoryTotalsProvider((
            year: widget.year,
            month: widget.month,
            nowLocal: widget.nowLocal,
          )),
        ).value ??
        const [];

    final monthTotal = ref.watch(
          homeMonthTotalProvider((
            year: widget.year,
            month: widget.month,
            nowLocal: widget.nowLocal,
          )),
        ).value ??
        0;

    final segments = buildCategoryArcSegments(
      categoryTotals: categoryTotals,
    );

    final isEmpty = segments.isEmpty || monthTotal <= 0;

    // Accesibilidad Semantics
    final String semanticLabel;
    if (isEmpty) {
      semanticLabel = 'Todavía no gastaste en $monthNameLower';
    } else {
      final parts = segments
          .map((s) => '${s.name} ${s.percentage} por ciento')
          .join(', ');
      semanticLabel =
          'Gastado en $monthNameLower, ${formatGs(monthTotal)}. $parts';
    }

    final CategoryArcSegment? selectedSegment = _selectedSegmentId == null
        ? null
        : segments.where((s) => s.id == _selectedSegmentId).firstOrNull;

    return Semantics(
      container: true,
      label: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Área del arco y textos centrales
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              if (isEmpty) return;
              _handleArcTap(details.localPosition, segments, monthTotal);
            },
            child: SizedBox(
              height: 164,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _CategoryArcPainter(
                          segments: segments,
                          totalAmount: monthTotal,
                          selectedSegmentId: _selectedSegmentId,
                          isDark: isDark,
                          trackColor: colors.glassBorder.withValues(
                            alpha: isDark ? 0.20 : 0.12,
                          ),
                          reduceMotion: reduceMotion,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 54,
                    left: 20,
                    right: 20,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_selectedSegmentId != null) {
                          _clearSelection();
                        } else {
                          ref.read(amountsRevealedProvider.notifier).toggle();
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Todavía no gastaste en $monthNameLower',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                          ] else if (selectedSegment != null) ...[
                            Text(
                              '${selectedSegment.name} en $monthNameLower',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              obscure ? '••••' : formatGs(selectedSegment.amount),
                              key: obscure
                                  ? const ValueKey('spending-total-obscured')
                                  : null,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.0,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${selectedSegment.percentage} % de lo gastado',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: colors.textTertiary,
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Gastado en $monthNameLower',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              obscure ? '••••' : formatGs(monthTotal),
                              key: obscure
                                  ? const ValueKey('spending-total-obscured')
                                  : null,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.0,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lista de tramos (solo si hay gastos)
          if (!isEmpty) ...[
            const SizedBox(height: 12),
            Column(
              children: [
                for (final seg in segments)
                  _buildCategoryRow(
                    context,
                    segment: seg,
                    isSelected: _selectedSegmentId == seg.id,
                    isDimmed:
                        _selectedSegmentId != null && _selectedSegmentId != seg.id,
                    isDark: isDark,
                    obscure: obscure,
                    onTap: () => _toggleSegment(seg.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handleArcTap(
    Offset localPosition,
    List<CategoryArcSegment> segments,
    int totalAmount,
  ) {
    if (segments.isEmpty || totalAmount <= 0) return;

    const double width = 284.0;
    const double height = 164.0;
    const double cx = width / 2;
    const double cy = height - 14;
    const double radius = 122.0;

    final dx = localPosition.dx - cx;
    final dy = localPosition.dy - cy;
    final dist = math.sqrt(dx * dx + dy * dy);

    // Si toca dentro del centro, limpiar selección
    if (dist < radius - 24) {
      _clearSelection();
      return;
    }

    // Toco sobre el arco (margen +- 20px)
    if (dy <= 0 && (dist - radius).abs() <= 24) {
      final angle = math.atan2(dy, dx); // [-pi, 0]
      final normalized = -angle; // [pi (izq) .. 0 (der)]

      const gap = 0.05;
      final totalGaps = (segments.length - 1) * gap;
      final available = math.pi - totalGaps;

      double currentStart = math.pi;
      for (final seg in segments) {
        final sweep = available * (seg.amount / totalAmount);
        final segmentEnd = currentStart - sweep;

        if (normalized <= currentStart + gap / 2 &&
            normalized >= segmentEnd - gap / 2) {
          _toggleSegment(seg.id);
          return;
        }
        currentStart = segmentEnd - gap;
      }
    }

    _clearSelection();
  }

  Widget _buildCategoryRow(
    BuildContext context, {
    required CategoryArcSegment segment,
    required bool isSelected,
    required bool isDimmed,
    required bool isDark,
    required bool obscure,
    required VoidCallback onTap,
  }) {
    final colors = context.pockt;
    final color = Color(isDark ? segment.colorDark : segment.colorLight);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(PocktRadii.m),
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: isDimmed ? 0.40 : 1.0,
            child: Row(
              children: [
                // Cuadradito de color
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                // Nombre
                Expanded(
                  child: Text(
                    segment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                // Porcentaje
                SizedBox(
                  width: 44,
                  child: Text(
                    '${segment.percentage} %',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: colors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Monto en Gs.
                SizedBox(
                  width: 104,
                  child: Text(
                    obscure ? '••••' : formatGs(segment.amount),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryArcPainter extends CustomPainter {
  final List<CategoryArcSegment> segments;
  final int totalAmount;
  final String? selectedSegmentId;
  final bool isDark;
  final Color trackColor;
  final bool reduceMotion;

  const _CategoryArcPainter({
    required this.segments,
    required this.totalAmount,
    required this.selectedSegmentId,
    required this.isDark,
    required this.trackColor,
    required this.reduceMotion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double radius = 122.0;
    final double cx = size.width / 2;
    final double cy = size.height - 14;
    final center = Offset(cx, cy);

    // Estado vacío: pista de fondo
    if (segments.isEmpty || totalAmount <= 0) {
      final trackPaint = Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi,
        false,
        trackPaint,
      );
      return;
    }

    if (segments.length == 1) {
      final seg = segments.first;
      final isSelected = selectedSegmentId == seg.id;
      final strokeWidth = isSelected ? 14.0 : 12.0;
      final color = Color(isDark ? seg.colorDark : seg.colorLight);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi,
        false,
        paint,
      );
      return;
    }

    // Múltiples tramos. En el canvas el ángulo crece en sentido horario:
    // de π (izquierda) a 2π (derecha) pasando por 3π/2 recorre la mitad de arriba.
    const double gapAngle = 0.05;
    final double totalGaps = (segments.length - 1) * gapAngle;
    final double availableAngle = math.pi - totalGaps;

    double currentStart = math.pi;

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final isSelected = selectedSegmentId == seg.id;
      final isDimmed = selectedSegmentId != null && !isSelected;
      final strokeWidth = isSelected ? 14.0 : 12.0;
      final baseColor = Color(isDark ? seg.colorDark : seg.colorLight);
      final color = baseColor.withValues(alpha: isDimmed ? 0.22 : 1.0);

      final sweep = availableAngle * (seg.amount / totalAmount);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentStart,
        sweep,
        false,
        paint,
      );

      // Redondeo del extremo exterior izquierdo (primer tramo)
      if (i == 0) {
        final tipPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(cx - radius, cy),
          strokeWidth / 2,
          tipPaint,
        );
      }

      // Redondeo del extremo exterior derecho (último tramo)
      if (i == segments.length - 1) {
        final tipPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(cx + radius, cy),
          strokeWidth / 2,
          tipPaint,
        );
      }

      currentStart = currentStart + sweep + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryArcPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.totalAmount != totalAmount ||
        oldDelegate.selectedSegmentId != selectedSegmentId ||
        oldDelegate.isDark != isDark ||
        oldDelegate.trackColor != trackColor;
  }
}
