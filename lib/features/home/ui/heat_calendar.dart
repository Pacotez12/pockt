import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/home/ui/day_detail_sheet.dart';
import 'package:pockt/features/home/ui/home_top_bar.dart';

/// Calendario de calor mensual ("Tus días").
/// Grilla lunes→domingo o domingo→sábado con niveles de intensidad 0..4 según gasto.
class HeatCalendar extends StatelessWidget {
  final int year;
  final int month;
  final Map<int, int> levels;
  final DateTime todayLocal;
  final ValueChanged<int> onDayTap;
  final WeekStart weekStart;

  const HeatCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.levels,
    required this.todayLocal,
    required this.onDayTap,
    this.weekStart = WeekStart.monday,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingEmptyCount = weekStart == WeekStart.monday
        ? (firstDayOfMonth.weekday - 1)
        : (firstDayOfMonth.weekday % 7);

    final totalCells = leadingEmptyCount + daysInMonth;
    final monthName = kMonthNames[month - 1].toLowerCase();
    final monthLabel = year == todayLocal.year ? monthName : '$monthName $year';

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: "Tus días" + leyenda menos -> más
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text.rich(
                key: const ValueKey('heat-calendar-title'),
                TextSpan(
                  text: 'Tus días',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  children: [
                    TextSpan(
                      text: ' · $monthLabel',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'menos',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      for (var i = 0; i <= 4; i++) ...[
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: colors.heat[i],
                            gradient: i == 4
                                ? LinearGradient(
                                    colors: [colors.brandStart, colors.brandEnd],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      Text(
                        'más',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Encabezado de días de la semana
          Row(
            children: weekStart == WeekStart.monday
                ? const [
                    _WeekdayHeader('L'),
                    _WeekdayHeader('M'),
                    _WeekdayHeader('M'),
                    _WeekdayHeader('J'),
                    _WeekdayHeader('V'),
                    _WeekdayHeader('S'),
                    _WeekdayHeader('D'),
                  ]
                : const [
                    _WeekdayHeader('D'),
                    _WeekdayHeader('L'),
                    _WeekdayHeader('M'),
                    _WeekdayHeader('M'),
                    _WeekdayHeader('J'),
                    _WeekdayHeader('V'),
                    _WeekdayHeader('S'),
                  ],
          ),
          const SizedBox(height: 6),
          // Grilla de celdas
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: 1.0,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              if (index < leadingEmptyCount) {
                return const HeatCalendarDayCell(
                  day: null,
                  level: 0,
                  isToday: false,
                  isFuture: false,
                );
              }

              final day = index - leadingEmptyCount + 1;
              final isToday =
                  year == todayLocal.year &&
                  month == todayLocal.month &&
                  day == todayLocal.day;
              final isFuture =
                  year > todayLocal.year ||
                  (year == todayLocal.year && month > todayLocal.month) ||
                  (year == todayLocal.year &&
                      month == todayLocal.month &&
                      day > todayLocal.day);

              final level = levels[day] ?? 0;

              return HeatCalendarDayCell(
                day: day,
                year: year,
                month: month,
                level: level,
                isToday: isToday,
                isFuture: isFuture,
                onTap: isFuture ? null : () => onDayTap(day),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String label;

  const _WeekdayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: colors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Celda individual del calendario de calor.
class HeatCalendarDayCell extends StatelessWidget {
  final int? day;
  final int? year;
  final int? month;
  final int level;
  final bool isToday;
  final bool isFuture;
  final VoidCallback? onTap;

  const HeatCalendarDayCell({
    super.key,
    required this.day,
    this.year,
    this.month,
    required this.level,
    required this.isToday,
    required this.isFuture,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (day == null) {
      return const SizedBox.shrink();
    }

    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color textColor;
    if (isFuture) {
      textColor = colors.textTertiary.withValues(alpha: 0.35);
    } else if (level >= 1) {
      // Número en blanco o negro según cuál contraste más con el fondo de la celda.
      final bg = level == 4 ? colors.brandStart : colors.heat[level];
      textColor = _contrast(Colors.white, bg) >= _contrast(Colors.black, bg)
          ? Colors.white
          : Colors.black;
    } else {
      textColor = isDark
          ? colors.textPrimary.withValues(alpha: 0.85)
          : colors.textPrimary;
    }

    Widget cellContent = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PocktRadii.s),
        color: isFuture ? Colors.transparent : colors.heat[level.clamp(0, 4)],
        gradient: !isFuture && level == 4
            ? LinearGradient(
                colors: [colors.brandStart, colors.brandEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        border: isToday
            ? Border.all(color: colors.textPrimary, width: 2.0)
            : null,
      ),
      alignment: Alignment.bottomRight,
      padding: const EdgeInsets.only(right: 3, bottom: 2),
      child: Text(
        '$day',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: isToday || level == 4 ? FontWeight.w700 : FontWeight.w500,
          color: textColor,
        ),
      ),
    );

    if (isFuture) {
      cellContent = CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: colors.glassBorder,
          radius: 7,
        ),
        child: cellContent,
      );
    }

    Widget cellWidget = cellContent;
    if (day != null && !isFuture && year != null && month != null) {
      cellWidget = HeroMode(
        enabled: !MediaQuery.disableAnimationsOf(context),
        child: Hero(
          tag: 'day-sheet-$year-$month-$day',
          createRectTween: (begin, end) =>
              SpringRectTween(begin: begin, end: end),
          flightShuttleBuilder:
              (
                flightContext,
                animation,
                flightDirection,
                fromHeroContext,
                toHeroContext,
              ) => buildDayDetailFlightShuttle(
                flightContext,
                animation,
                flightDirection,
                fromHeroContext,
                toHeroContext,
                colors,
                isDark,
              ),
          child: Material(color: Colors.transparent, child: cellWidget),
        ),
      );
    }

    return Pressable(onTap: onTap, child: cellWidget);
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  static const double _strokeWidth = 1.0;
  static const double _dashWidth = 3.0;
  static const double _dashSpace = 3.0;

  _DashedBorderPainter({required this.color, this.radius = 7});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + _dashWidth <= metric.length)
            ? _dashWidth
            : metric.length - distance;
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += _dashWidth + _dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}
