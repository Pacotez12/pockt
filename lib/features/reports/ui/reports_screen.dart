import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/reports/ui/views/ant_expenses_view.dart';
import 'package:pockt/features/reports/ui/views/categories_view.dart';
import 'package:pockt/features/reports/ui/views/comparison_view.dart';
import 'package:pockt/features/reports/ui/views/evolution_view.dart';
import 'package:pockt/features/reports/ui/views/merchants_view.dart';
import 'package:pockt/features/reports/ui/views/report_shared_widgets.dart';

/// Pantalla de Reportes con 5 vistas deslizables:
/// 1) Mes por categoría (donut y lista con apertura de movimientos)
/// 2) Evolución (barras gasto/ingreso y línea de ahorro, selector 6/12)
/// 3) Comparación (vs mes anterior a esta altura y por categoría)
/// 4) Por comercio (ranking y barras proporcionales)
/// 5) Gastos hormiga
class ReportsScreen extends ConsumerStatefulWidget {
  final DateTime? nowLocal;
  final int? initialYear;
  final int? initialMonth;

  const ReportsScreen({
    super.key,
    this.nowLocal,
    this.initialYear,
    this.initialMonth,
  });

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late int _year;
  late int _month;
  late final PageController _pageController;
  int _currentPage = 0;
  int _evolutionMonths = 6;

  static const List<String> _tabTitles = [
    'Categorías',
    'Evolución',
    'Comparación',
    'Por comercio',
    'Hormiga',
  ];

  DateTime get _now => widget.nowLocal ?? DateTime.now();

  DateTime get _activeReferenceDate {
    final now = _now;
    if (_year == now.year && _month == now.month) {
      return now;
    }
    final daysInM = DateTime(_year, _month + 1, 0).day;
    final day = min(now.day, daysInM);
    return DateTime(_year, _month, day, now.hour, now.minute);
  }

  @override
  void initState() {
    super.initState();
    final now = widget.nowLocal ?? DateTime.now();
    _year = widget.initialYear ?? now.year;
    _month = widget.initialMonth ?? now.month;
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _changeMonth(int delta) {
    Haptics.tick();
    setState(() {
      var newMonth = _month + delta;
      var newYear = _year;
      if (newMonth < 1) {
        newMonth = 12;
        newYear--;
      } else if (newMonth > 12) {
        newMonth = 1;
        newYear++;
      }
      _month = newMonth;
      _year = newYear;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(colors),
            const SizedBox(height: 8),
            _buildTabSelector(colors),
            const SizedBox(height: 8),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  CategoriesView(
                    year: _year,
                    month: _month,
                    nowLocal: _now,
                    isDark: isDark,
                  ),
                  EvolutionView(
                    months: _evolutionMonths,
                    todayLocal: _activeReferenceDate,
                    isDark: isDark,
                    onMonthsChanged: (m) =>
                        setState(() => _evolutionMonths = m),
                  ),
                  ComparisonView(
                    year: _year,
                    month: _month,
                    todayLocal: _activeReferenceDate,
                    isDark: isDark,
                  ),
                  MerchantsView(year: _year, month: _month, isDark: isDark),
                  AntExpensesView(year: _year, month: _month, isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(PocktColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Reportes',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Pressable(
                semanticLabel: 'Mes anterior',
                onTap: () => _changeMonth(-1),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.glassFill,
                    border: Border.all(color: colors.glassBorder),
                  ),
                  child: Center(
                    child: Icon(
                      uiIcon('arrow-left'),
                      size: 14,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<int>(
                initialValue: _month,
                tooltip: 'Elegir mes',
                onSelected: (m) {
                  if (m != _month) {
                    Haptics.tick();
                    setState(() {
                      _month = m;
                    });
                  }
                },
                itemBuilder: (context) => [
                  for (int m = 1; m <= 12; m++)
                    PopupMenuItem(
                      value: m,
                      child: Text(
                        '${kReportMonthNames[m - 1]} $_year',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: m == _month
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PocktRadii.l),
                    color: colors.glassFill,
                    border: Border.all(color: colors.glassBorder),
                  ),
                  child: Text(
                    '${kReportMonthNames[_month - 1]} $_year ▾',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Pressable(
                semanticLabel: 'Mes siguiente',
                onTap: () => _changeMonth(1),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.glassFill,
                    border: Border.all(color: colors.glassBorder),
                  ),
                  child: Center(
                    child: Icon(
                      uiIcon('caret-right'),
                      size: 14,
                      color: colors.textSecondary,
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

  Widget _buildTabSelector(PocktColors colors) {
    // Las 5 pestañas no entran en un teléfono: se desplazan, y los bordes se
    // desvanecen para que el corte se lea como "hay más" y no como un error.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      // Máscara: solo importa la opacidad, el tono se ignora.
      shaderCallback: (rect) => LinearGradient(
        colors: [
          colors.textPrimary.withValues(alpha: 0),
          colors.textPrimary,
          colors.textPrimary,
          colors.textPrimary.withValues(alpha: 0),
        ],
        stops: const [0, 0.05, 0.9, 1],
      ).createShader(rect),
      child: _buildTabScroller(colors),
    );
  }

  Widget _buildTabScroller(PocktColors colors) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.glassFill,
          borderRadius: BorderRadius.circular(PocktRadii.xl),
          border: Border.all(color: colors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _tabTitles.length; i++)
              Pressable(
                onTap: () {
                  Haptics.tick();
                  _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PocktRadii.m),
                    color: _currentPage == i
                        ? colors.brandStart.withValues(alpha: 0.18)
                        : Colors.transparent,
                    border: _currentPage == i
                        ? Border.all(
                            color: colors.brandStart.withValues(alpha: 0.35),
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      _tabTitles[i],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: _currentPage == i
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _currentPage == i
                            ? colors.brandStart
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
