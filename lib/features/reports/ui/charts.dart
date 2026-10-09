import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/reports/data/reports_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

const List<String> _kMonthShort = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

/// Gráfico de anillo (donut) que muestra la distribución de gastos por categoría.
/// Anima la apertura de los arcos respetando [PocktSprings.soft] y reduce motion.
class CategoryDonutChart extends StatefulWidget {
  final List<CategoryTotal> totals;
  final int totalExpense;
  final bool isDark;

  const CategoryDonutChart({
    super.key,
    required this.totals,
    required this.totalExpense,
    required this.isDark,
  });

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _controller.value = 1.0;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant CategoryDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.totals != oldWidget.totals) {
      if (_reduceMotion) {
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Center(
      child: SizedBox(
        width: 210,
        height: 210,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = _reduceMotion
                ? 1.0
                : SpringCurve(spring: PocktSprings.soft)
                    .transform(_controller.value)
                    .clamp(0.0, 1.0);

            return Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(210, 210),
                  painter: _CategoryDonutPainter(
                    totals: widget.totals,
                    totalExpense: widget.totalExpense,
                    progress: progress,
                    isDark: widget.isDark,
                    glassBorder: colors.glassBorder,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatGs(widget.totalExpense),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryDonutPainter extends CustomPainter {
  final List<CategoryTotal> totals;
  final int totalExpense;
  final double progress;
  final bool isDark;
  final Color glassBorder;

  _CategoryDonutPainter({
    required this.totals,
    required this.totalExpense,
    required this.progress,
    required this.isDark,
    required this.glassBorder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 22.0;
    final radius = (size.width - strokeWidth) / 2;

    if (totalExpense <= 0 || totals.isEmpty) {
      final basePaint = Paint()
        ..color = glassBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, basePaint);
      return;
    }

    final rect = Rect.fromCircle(center: center, radius: radius);
    final count = totals.length;
    final gapAngle = count > 1 ? 0.04 : 0.0;
    final totalGap = gapAngle * count;
    final totalSweepAvailable = max(0.0, (2 * pi) - totalGap);

    var startAngle = -pi / 2;

    for (final item in totals) {
      if (item.total <= 0) continue;
      final sliceRatio = item.total / totalExpense;
      final sweepAngle = sliceRatio * totalSweepAvailable * progress;

      final catColor = Color(
        isDark ? item.category.colorDark : item.category.colorLight,
      );

      final paint = Paint()
        ..color = catColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryDonutPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.totals != totals ||
        oldDelegate.totalExpense != totalExpense ||
        oldDelegate.isDark != isDark;
  }
}

/// Gráfico de evolución de 6 o 12 meses: barras para gasto e ingreso y
/// línea/puntos para ahorro neto.
class EvolutionChart extends StatefulWidget {
  final List<MonthTotals> totals;
  final bool isDark;

  const EvolutionChart({
    super.key,
    required this.totals,
    required this.isDark,
  });

  @override
  State<EvolutionChart> createState() => _EvolutionChartState();
}

class _EvolutionChartState extends State<EvolutionChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _controller.value = 1.0;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant EvolutionChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.totals != oldWidget.totals) {
      if (_reduceMotion) {
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Container(
      key: const ValueKey('evolution-chart'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Leyenda
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: colors.danger, label: 'Gastos'),
              const SizedBox(width: 16),
              _LegendItem(color: colors.positive, label: 'Ingresos'),
              const SizedBox(width: 16),
              _LegendItem(
                color: colors.brandStart,
                label: 'Ahorro',
                isLine: true,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Gráfico
          SizedBox(
            height: 170,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final progress = _reduceMotion
                    ? 1.0
                    : SpringCurve(spring: PocktSprings.soft)
                        .transform(_controller.value)
                        .clamp(0.0, 1.0);

                return CustomPaint(
                  size: const Size.fromHeight(170),
                  painter: _EvolutionPainter(
                    totals: widget.totals,
                    progress: progress,
                    dangerColor: colors.danger,
                    positiveColor: colors.positive,
                    savingColor: colors.brandStart,
                    gridColor: colors.glassBorder,
                    sheetSurface: colors.sheetSurface,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Etiquetas de mes abajo
          Row(
            children: [
              for (final m in widget.totals)
                Expanded(
                  child: Center(
                    child: Text(
                      _kMonthShort[m.month - 1],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isLine;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isLine = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLine)
          Container(
            width: 12,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.5),
            ),
          )
        else
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _EvolutionPainter extends CustomPainter {
  final List<MonthTotals> totals;
  final double progress;
  final Color dangerColor;
  final Color positiveColor;
  final Color savingColor;
  final Color gridColor;
  final Color sheetSurface;

  _EvolutionPainter({
    required this.totals,
    required this.progress,
    required this.dangerColor,
    required this.positiveColor,
    required this.savingColor,
    required this.gridColor,
    required this.sheetSurface,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totals.isEmpty) return;

    var maxVal = 0;
    for (final m in totals) {
      if (m.expense > maxVal) maxVal = m.expense;
      if (m.income > maxVal) maxVal = m.income;
    }
    if (maxVal <= 0) maxVal = 1;

    // Líneas de referencia sutiles (fondo, 50%, 100%)
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, 0),
      Offset(size.width, 0),
      gridPaint,
    );

    final slotWidth = size.width / totals.length;
    final barWidth = (slotWidth * 0.28).clamp(6.0, 14.0);
    final barSpacing = 2.0;

    final savingPoints = <Offset>[];

    for (var i = 0; i < totals.length; i++) {
      final m = totals[i];
      final xCenter = (i + 0.5) * slotWidth;

      // Barra de gasto
      final expHeight =
          (m.expense / maxVal) * (size.height - 4) * progress;
      final expLeft = xCenter - barWidth - (barSpacing / 2);
      final expRect = Rect.fromLTWH(
        expLeft,
        size.height - expHeight,
        barWidth,
        expHeight,
      );
      if (expHeight > 0) {
        final expPaint = Paint()..color = dangerColor;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            expRect,
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
          ),
          expPaint,
        );
      }

      // Barra de ingreso
      final incHeight =
          (m.income / maxVal) * (size.height - 4) * progress;
      final incLeft = xCenter + (barSpacing / 2);
      final incRect = Rect.fromLTWH(
        incLeft,
        size.height - incHeight,
        barWidth,
        incHeight,
      );
      if (incHeight > 0) {
        final incPaint = Paint()..color = positiveColor;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            incRect,
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
          ),
          incPaint,
        );
      }

      // Punto de ahorro
      final savingVal = m.saving.clamp(0, maxVal);
      final savingY =
          size.height - ((savingVal / maxVal) * (size.height - 4) * progress);
      savingPoints.add(Offset(xCenter, savingY));
    }

    // Línea de ahorro conectando puntos
    if (savingPoints.length > 1) {
      final linePath = Path();
      linePath.moveTo(savingPoints.first.dx, savingPoints.first.dy);
      for (var i = 1; i < savingPoints.length; i++) {
        linePath.lineTo(savingPoints[i].dx, savingPoints[i].dy);
      }

      final linePaint = Paint()
        ..color = savingColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(linePath, linePaint);
    }

    // Dibujar círculos en puntos de ahorro
    final dotPaintFill = Paint()..color = savingColor;
    final dotPaintBorder = Paint()
      ..color = sheetSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final pt in savingPoints) {
      canvas.drawCircle(pt, 3.5, dotPaintFill);
      canvas.drawCircle(pt, 3.5, dotPaintBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _EvolutionPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.totals != totals ||
        oldDelegate.dangerColor != dangerColor ||
        oldDelegate.positiveColor != positiveColor ||
        oldDelegate.savingColor != savingColor;
  }
}

/// Fila del ranking de comercio con barra proporcional.
class MerchantBarRow extends StatelessWidget {
  final int rank;
  final MerchantTotal item;
  final int maxTotal;
  final bool? isDark;

  const MerchantBarRow({
    super.key,
    required this.rank,
    required this.item,
    required this.maxTotal,
    this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final ratio = maxTotal > 0 ? (item.total / maxTotal).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: colors.glassFill,
                  border: Border.all(color: colors.glassBorder),
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: rank <= 3 ? colors.brandStart : colors.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.merchant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${item.count} ${item.count == 1 ? 'compra' : 'compras'}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatGs(item.total),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Barra proporcional
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 5,
              width: double.infinity,
              color: colors.glassBorder,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.brandStart, colors.brandEnd],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
