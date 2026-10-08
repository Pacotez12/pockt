import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/home/domain/heat_levels.dart';
import 'package:pockt/features/home/ui/day_detail_sheet.dart';
import 'package:pockt/features/home/ui/heat_calendar.dart';
import 'package:pockt/features/home/ui/month_glow.dart';
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

/// Pantalla principal: Inicio con selector de mes, total animado,
/// resplandor ambiental, barra segmentada por categoría, calendario de calor
/// y últimos movimientos.
class HomeScreen extends ConsumerStatefulWidget {
  final int? initialYear;
  final int? initialMonth;
  final DateTime? nowLocal;

  const HomeScreen({
    super.key,
    this.initialYear,
    this.initialMonth,
    this.nowLocal,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int _year;
  late int _month;

  StreamSubscription<int>? _monthTotalSub;
  StreamSubscription<List<CategoryTotal>>? _categoryTotalsSub;
  StreamSubscription<Map<int, int>>? _dailyTotalsSub;
  StreamSubscription<List<TxView>>? _recentSub;

  int _monthTotal = 0;
  int _previousTotal = 0;
  List<CategoryTotal> _categoryTotals = const [];
  Map<int, int> _dailyTotals = const {};
  List<TxView> _recentTxs = const [];

  DateTime _getNow() => widget.nowLocal ?? toLocal(DateTime.now());

  @override
  void initState() {
    super.initState();
    final now = _getNow();
    _year = widget.initialYear ?? now.year;
    _month = widget.initialMonth ?? now.month;
    _initSubscriptions();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialYear != oldWidget.initialYear ||
        widget.initialMonth != oldWidget.initialMonth) {
      final now = _getNow();
      _year = widget.initialYear ?? now.year;
      _month = widget.initialMonth ?? now.month;
      _initSubscriptions();
    }
  }

  @override
  void dispose() {
    _monthTotalSub?.cancel();
    _categoryTotalsSub?.cancel();
    _dailyTotalsSub?.cancel();
    _recentSub?.cancel();
    super.dispose();
  }

  void _initSubscriptions() {
    _monthTotalSub?.cancel();
    _categoryTotalsSub?.cancel();
    _dailyTotalsSub?.cancel();
    _recentSub?.cancel();

    final repo = ref.read(transactionsRepositoryProvider);

    _monthTotalSub = repo.watchMonthTotal(_year, _month, TxType.expense).listen((total) {
      if (mounted) {
        setState(() {
          _previousTotal = _monthTotal;
          _monthTotal = total;
        });
      }
    });

    _categoryTotalsSub = repo.watchMonthCategoryTotals(_year, _month).listen((totals) {
      if (mounted) {
        setState(() {
          _categoryTotals = totals;
        });
      }
    });

    _dailyTotalsSub = repo.watchDailyExpenseTotals(_year, _month).listen((daily) {
      if (mounted) {
        setState(() {
          _dailyTotals = daily;
        });
      }
    });

    _recentSub = repo.watchRecent(limit: 5).listen((recent) {
      if (mounted) {
        setState(() {
          _recentTxs = recent;
        });
      }
    });
  }

  void _changeMonth(int delta) {
    Haptics.tick();
    setState(() {
      var newMonth = _month + delta;
      var newYear = _year;
      if (newMonth > 12) {
        newMonth = 1;
        newYear++;
      } else if (newMonth < 1) {
        newMonth = 12;
        newYear--;
      }
      _month = newMonth;
      _year = newYear;
      _initSubscriptions();
    });
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v < -150) {
      _changeMonth(1);
    } else if (v > 150) {
      _changeMonth(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final glowColor = _categoryTotals.isNotEmpty
        ? Color(
            isDark
                ? _categoryTotals.first.category.colorDark
                : _categoryTotals.first.category.colorLight,
          )
        : colors.brandStart;

    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Resplandor ambiental de mes en el fondo
          Positioned(
            top: -140,
            left: (screenWidth - 470) / 2,
            child: MonthGlow(color: glowColor),
          ),
          // Contenido con scroll
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  _buildTopBar(context),
                  const SizedBox(height: 20),
                  _buildSpendingTotal(context),
                  const SizedBox(height: 16),
                  _buildSegmentedBar(context),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onHorizontalDragEnd: _handleHorizontalSwipe,
                    child: HeatCalendar(
                      year: _year,
                      month: _month,
                      levels: heatLevels(_dailyTotals),
                      todayLocal: _getNow(),
                      onDayTap: (day) {
                        showDayDetail(context, DateTime(_year, _month, day));
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRecentTransactions(context),
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final colors = context.pockt;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PopupMenuButton<int>(
          initialValue: _month,
          tooltip: 'Elegir mes',
          onSelected: (m) {
            if (m != _month) {
              Haptics.tick();
              setState(() {
                _month = m;
                _initSubscriptions();
              });
            }
          },
          itemBuilder: (context) => [
            for (int m = 1; m <= 12; m++)
              PopupMenuItem(
                value: m,
                child: Text(
                  _kMonthNames[m - 1],
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: m == _month ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: colors.glassFill,
              border: Border.all(color: colors.glassBorder),
            ),
            child: Text(
              '${_kMonthNames[_month - 1]} ▾',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.glassFill,
            border: Border.all(color: colors.glassBorder),
          ),
          child: Center(
            child: Icon(
              uiIcon('gear'),
              size: 16,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpendingTotal(BuildContext context) {
    final colors = context.pockt;
    final monthNameLower = _kMonthNames[_month - 1].toLowerCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gastado en $monthNameLower',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<int>(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            tween: IntTween(begin: _previousTotal, end: _monthTotal),
            builder: (context, animatedValue, _) {
              return Text(
                formatGs(animatedValue),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.5,
                  color: colors.textPrimary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedBar(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_categoryTotals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: colors.glassFill,
          ),
        ),
      );
    }

    final sum = _categoryTotals.fold<int>(0, (acc, c) => acc + c.total);
    if (sum <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: colors.glassFill,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          for (int i = 0; i < _categoryTotals.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              flex: (_categoryTotals[i].total * 1000 ~/ sum).clamp(1, 1000),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: Color(
                    isDark
                        ? _categoryTotals[i].category.colorDark
                        : _categoryTotals[i].category.colorLight,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context) {
    final colors = context.pockt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            'Últimos movimientos',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          borderRadius: BorderRadius.circular(24),
          child: _recentTxs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Sin movimientos aún',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final item in _recentTxs)
                      SwipeableTxRow(
                        view: item,
                        subtitle: formatTxWhen(toLocal(item.tx.occurredAt), _getNow()),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
