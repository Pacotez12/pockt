import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/reports/data/reports_repository.dart';
import 'package:pockt/features/reports/domain/compare.dart';
import 'package:pockt/features/reports/ui/charts.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/transactions/ui/tx_row.dart';

const List<String> _kMonthNames = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// Pantalla de Reportes con 4 vistas deslizables:
/// 1) Mes por categoría (donut y lista con apertura de movimientos)
/// 2) Evolución (barras gasto/ingreso y línea de ahorro, selector 6/12)
/// 3) Comparación (vs mes anterior a esta altura y por categoría)
/// 4) Por comercio (ranking y barras proporcionales)
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
                  _CategoriesView(
                    year: _year,
                    month: _month,
                    nowLocal: _now,
                    isDark: isDark,
                  ),
                  _EvolutionView(
                    months: _evolutionMonths,
                    todayLocal: _activeReferenceDate,
                    isDark: isDark,
                    onMonthsChanged: (m) => setState(() => _evolutionMonths = m),
                  ),
                  _ComparisonView(
                    year: _year,
                    month: _month,
                    todayLocal: _activeReferenceDate,
                    isDark: isDark,
                  ),
                  _MerchantsView(
                    year: _year,
                    month: _month,
                    isDark: isDark,
                  ),
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
                        '${_kMonthNames[m - 1]} $_year',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight:
                              m == _month ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: colors.glassFill,
                    border: Border.all(color: colors.glassBorder),
                  ),
                  child: Text(
                    '${_kMonthNames[_month - 1]} $_year ▾',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.glassFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.glassBorder),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _tabTitles.length; i++)
              Expanded(
                child: Pressable(
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
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      color: _currentPage == i
                          ? colors.glassBorder
                          : Colors.transparent,
                    ),
                    child: Center(
                      child: Text(
                        _tabTitles[i],
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: _currentPage == i
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _currentPage == i
                              ? colors.textPrimary
                              : colors.textTertiary,
                        ),
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

// -----------------------------------------------------------------------------
// VISTA 1: Mes por categoría
// -----------------------------------------------------------------------------

class _CategoriesView extends ConsumerWidget {
  final int year;
  final int month;
  final DateTime nowLocal;
  final bool isDark;

  const _CategoriesView({
    required this.year,
    required this.month,
    required this.nowLocal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(reportsRepositoryProvider);
    final mode =
        ref.watch(monthStartModeProvider).value ?? MonthStartMode.calendar;
    final schedule = ref.watch(currentIncomeScheduleProvider).value;
    final isCurrent = year == nowLocal.year && month == nowLocal.month;
    final period = periodFor(
      isCurrent ? nowLocal : DateTime(year, month, 15),
      mode: mode,
      schedule: schedule,
    );

    return StreamBuilder<List<CategoryTotal>>(
      stream: repo.watchMonthByCategory(year, month, period: period),
      builder: (context, snapshot) {
        final totals = snapshot.data ?? const [];
        final totalExpense = totals.fold<int>(0, (sum, t) => sum + t.total);

        if (totals.isEmpty || totalExpense <= 0) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  uiIcon('chart-pie-slice'),
                  size: 44,
                  color: colors.textTertiary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Sin gastos este mes',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          physics: const BouncingScrollPhysics(),
          children: [
            CategoryDonutChart(
              totals: totals,
              totalExpense: totalExpense,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
            Text(
              'Por categoría',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < totals.length; i++) ...[
                    _CategoryRow(
                      item: totals[i],
                      totalExpense: totalExpense,
                      isDark: isDark,
                      onTap: () => _openCategoryTransactions(
                        context,
                        totals[i].category,
                      ),
                    ),
                    if (i < totals.length - 1)
                      Divider(
                        height: 1,
                        color: colors.glassBorder.withValues(alpha: 0.5),
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _openCategoryTransactions(BuildContext context, Category category) {
    Haptics.tick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetContext) => _CategoryTransactionsSheet(
        category: category,
        year: year,
        month: month,
        nowLocal: nowLocal,
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryTotal item;
  final int totalExpense;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.item,
    required this.totalExpense,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final catColor =
        Color(isDark ? item.category.colorDark : item.category.colorLight);
    final pct = totalExpense > 0
        ? (item.total / totalExpense * 100).toStringAsFixed(1)
        : '0.0';

    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: catColor.withValues(alpha: isDark ? 0.20 : 0.14),
              ),
              child: Center(
                child: categoryIcon(item.category.icon, size: 16, color: catColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.category.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    '$pct %',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
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
            const SizedBox(width: 4),
            Icon(
              uiIcon('caret-right'),
              size: 14,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTransactionsSheet extends ConsumerWidget {
  final Category category;
  final int year;
  final int month;
  final DateTime nowLocal;

  const _CategoryTransactionsSheet({
    required this.category,
    required this.year,
    required this.month,
    required this.nowLocal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor =
        Color(isDark ? category.colorDark : category.colorLight);
    final mode =
        ref.watch(monthStartModeProvider).value ?? MonthStartMode.calendar;
    final schedule = ref.watch(currentIncomeScheduleProvider).value;
    final isCurrent = year == nowLocal.year && month == nowLocal.month;
    final period = periodFor(
      isCurrent ? nowLocal : DateTime(year, month, 15),
      mode: mode,
      schedule: schedule,
    );
    final startOfMonth = period.start;
    final endOfMonth = period.end;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              decoration: BoxDecoration(
                color: colors.sheetSurface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: colors.glassBorder)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Manija
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 12),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.glassBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Encabezado
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: catColor.withValues(
                                alpha: isDark ? 0.20 : 0.14,
                              ),
                            ),
                            child: Center(
                              child: categoryIcon(
                                category.icon,
                                size: 18,
                                color: catColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.name,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${_kMonthNames[month - 1]} $year',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: colors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: colors.glassBorder),
                    // Lista de transacciones filtradas
                    Expanded(
                      child: StreamBuilder<List<TxView>>(
                        stream: ref
                            .watch(transactionsRepositoryProvider)
                            .watchFiltered(
                              categoryIds: {category.id},
                              type: TxType.expense,
                              fromLocal: startOfMonth,
                              toLocal: endOfMonth,
                            ),
                        builder: (context, snapshot) {
                          final txs = snapshot.data ?? const [];
                          if (txs.isEmpty) {
                            return Center(
                              child: Text(
                                'Sin movimientos este mes',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: colors.textTertiary,
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            physics: const BouncingScrollPhysics(),
                            itemCount: txs.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = txs[index];
                              final hasMerchant = item.tx.merchant != null &&
                                  item.tx.merchant!.trim().isNotEmpty;
                              final hasNote = item.tx.note != null &&
                                  item.tx.note!.trim().isNotEmpty;

                              final subtitle = (hasMerchant && hasNote)
                                  ? item.tx.note!.trim()
                                  : formatTxWhen(
                                      toLocal(item.tx.occurredAt),
                                      nowLocal,
                                    );

                              return SwipeableTxRow(
                                view: item,
                                subtitle: subtitle,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// VISTA 2: Evolución
// -----------------------------------------------------------------------------

class _EvolutionView extends ConsumerWidget {
  final int months;
  final DateTime todayLocal;
  final bool isDark;
  final ValueChanged<int> onMonthsChanged;

  const _EvolutionView({
    required this.months,
    required this.todayLocal,
    required this.isDark,
    required this.onMonthsChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(reportsRepositoryProvider);

    return StreamBuilder<List<MonthTotals>>(
      stream: repo.watchEvolution(months: months, todayLocal: todayLocal),
      builder: (context, snapshot) {
        final totals = snapshot.data ?? const [];
        final hasData = totals.any((m) => m.expense > 0 || m.income > 0);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          physics: const BouncingScrollPhysics(),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Evolución',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: colors.glassFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      _PeriodChip(
                        label: '6 meses',
                        selected: months == 6,
                        onTap: () {
                          Haptics.tick();
                          onMonthsChanged(6);
                        },
                      ),
                      _PeriodChip(
                        label: '12 meses',
                        selected: months == 12,
                        onTap: () {
                          Haptics.tick();
                          onMonthsChanged(12);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 80),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        uiIcon('chart-bar'),
                        size: 44,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sin movimientos en este período',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              EvolutionChart(
                totals: totals,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _buildEvolutionSummary(colors, totals),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEvolutionSummary(
    PocktColors colors,
    List<MonthTotals> totals,
  ) {
    var sumExp = 0;
    var sumInc = 0;
    for (final m in totals) {
      sumExp += m.expense;
      sumInc += m.income;
    }
    final count = max(1, totals.length);
    final avgExp = (sumExp / count).round();
    final avgInc = (sumInc / count).round();
    final netSaving = sumInc - sumExp;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Promedio mensual de gasto',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                formatGs(avgExp),
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Promedio mensual de ingreso',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                formatGs(avgInc),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: colors.positive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: colors.glassBorder),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ahorro neto del período',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                formatGs(netSaving),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: netSaving >= 0 ? colors.brandStart : colors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? colors.glassBorder : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? colors.textPrimary : colors.textTertiary,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// VISTA 3: Comparación
// -----------------------------------------------------------------------------

class _ComparisonView extends ConsumerWidget {
  final int year;
  final int month;
  final DateTime todayLocal;
  final bool isDark;

  const _ComparisonView({
    required this.year,
    required this.month,
    required this.todayLocal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(reportsRepositoryProvider);

    return StreamBuilder<Comparison>(
      stream: repo.watchComparison(todayLocal: todayLocal),
      builder: (context, snapshot) {
        final comp = snapshot.data;
        if (comp == null || (comp.current == 0 && comp.previous == 0)) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  uiIcon('trend-up'),
                  size: 44,
                  color: colors.textTertiary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Sin datos para comparar',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        final prevMonth = month == 1 ? 12 : month - 1;
        final prevYear = month == 1 ? year - 1 : year;
        final prevMonthName = _kMonthNames[prevMonth - 1].toLowerCase();

        String headline;
        if (comp.changePct == null) {
          headline =
              'Gastaste ${formatGs(comp.current)} este mes · sin gastos en $prevMonthName a esta altura';
        } else {
          final pct = comp.changePct!.round();
          if (pct > 0) {
            headline =
                'Este mes gastaste $pct % más que en $prevMonthName a esta altura';
          } else if (pct < 0) {
            headline =
                'Este mes gastaste ${pct.abs()} % menos que en $prevMonthName a esta altura';
          } else {
            headline =
                'Este mes gastaste lo mismo que en $prevMonthName a esta altura';
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          physics: const BouncingScrollPhysics(),
          children: [
            Text(
              'Comparación',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _StatPill(
                          label: 'Mes actual (${_kMonthNames[month - 1]})',
                          amount: comp.current,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatPill(
                          label: 'Mes anterior ($prevMonthName)',
                          amount: comp.previous,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Comparación por categoría',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _CategoryComparisonSection(
              curYear: year,
              curMonth: month,
              prevYear: prevYear,
              prevMonth: prevMonth,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;

  const _StatPill({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatGs(amount),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryComparisonSection extends ConsumerWidget {
  final int curYear;
  final int curMonth;
  final int prevYear;
  final int prevMonth;
  final bool isDark;

  const _CategoryComparisonSection({
    required this.curYear,
    required this.curMonth,
    required this.prevYear,
    required this.prevMonth,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(reportsRepositoryProvider);

    return StreamBuilder<List<CategoryTotal>>(
      stream: repo.watchMonthByCategory(curYear, curMonth),
      builder: (context, curSnap) {
        return StreamBuilder<List<CategoryTotal>>(
          stream: repo.watchMonthByCategory(prevYear, prevMonth),
          builder: (context, prevSnap) {
            final curList = curSnap.data ?? const [];
            final prevList = prevSnap.data ?? const [];

            final map = <String, ({Category category, int cur, int prev})>{};
            for (final c in curList) {
              map[c.category.id] = (
                category: c.category,
                cur: c.total,
                prev: 0,
              );
            }
            for (final p in prevList) {
              final existing = map[p.category.id];
              if (existing != null) {
                map[p.category.id] = (
                  category: existing.category,
                  cur: existing.cur,
                  prev: p.total,
                );
              } else {
                map[p.category.id] = (
                  category: p.category,
                  cur: 0,
                  prev: p.total,
                );
              }
            }

            final items = map.values.toList()
              ..sort((a, b) => max(b.cur, b.prev).compareTo(max(a.cur, a.prev)));

            if (items.isEmpty) {
              return const SizedBox.shrink();
            }

            return GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _CategoryComparisonRow(
                      category: items[i].category,
                      cur: items[i].cur,
                      prev: items[i].prev,
                      isDark: isDark,
                    ),
                    if (i < items.length - 1)
                      Divider(
                        height: 1,
                        color: colors.glassBorder.withValues(alpha: 0.5),
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CategoryComparisonRow extends StatelessWidget {
  final Category category;
  final int cur;
  final int prev;
  final bool isDark;

  const _CategoryComparisonRow({
    required this.category,
    required this.cur,
    required this.prev,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final catColor = Color(isDark ? category.colorDark : category.colorLight);

    String changeLabel;
    Color changeColor;
    if (prev == 0 && cur > 0) {
      changeLabel = 'Nuevo';
      changeColor = colors.brandStart;
    } else if (prev > 0 && cur == 0) {
      changeLabel = '-100 %';
      changeColor = colors.positive;
    } else if (prev > 0) {
      final pct = (((cur - prev) / prev) * 100).round();
      if (pct > 0) {
        changeLabel = '+$pct %';
        changeColor = colors.danger;
      } else if (pct < 0) {
        changeLabel = '$pct %';
        changeColor = colors.positive;
      } else {
        changeLabel = '0 %';
        changeColor = colors.textTertiary;
      }
    } else {
      changeLabel = '0 %';
      changeColor = colors.textTertiary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: catColor.withValues(alpha: isDark ? 0.20 : 0.14),
            ),
            child: Center(
              child: categoryIcon(category.icon, size: 16, color: catColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  'Antes: ${formatGs(prev)}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatGs(cur),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: colors.textPrimary,
                ),
              ),
              Text(
                changeLabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: changeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// VISTA 4: Por comercio
// -----------------------------------------------------------------------------

class _MerchantsView extends ConsumerWidget {
  final int year;
  final int month;
  final bool isDark;

  const _MerchantsView({
    required this.year,
    required this.month,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(reportsRepositoryProvider);
    final mode =
        ref.watch(monthStartModeProvider).value ?? MonthStartMode.calendar;
    final schedule = ref.watch(currentIncomeScheduleProvider).value;
    final nowLocal = toLocal(DateTime.now());
    final isCurrent = year == nowLocal.year && month == nowLocal.month;
    final period = periodFor(
      isCurrent ? nowLocal : DateTime(year, month, 15),
      mode: mode,
      schedule: schedule,
    );

    return StreamBuilder<List<MerchantTotal>>(
      stream: repo.watchByMerchant(year, month, period: period),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const [];
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  uiIcon('storefront'),
                  size: 44,
                  color: colors.textTertiary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Sin comercios registrados este mes',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        final maxTotal = list.first.total;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          physics: const BouncingScrollPhysics(),
          children: [
            Text(
              'Por comercio',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    MerchantBarRow(
                      rank: i + 1,
                      item: list[i],
                      maxTotal: maxTotal,
                      isDark: isDark,
                    ),
                    if (i < list.length - 1)
                      Divider(
                        height: 1,
                        color: colors.glassBorder.withValues(alpha: 0.5),
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
