import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
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
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/home/domain/heat_levels.dart';
import 'package:pockt/features/home/ui/day_detail_sheet.dart';
import 'package:pockt/features/home/ui/heat_calendar.dart';
import 'package:pockt/features/home/ui/month_glow.dart';
import 'package:pockt/features/income/domain/period_summary.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/recurring/ui/inbox_screen.dart';
import 'package:pockt/features/settings/ui/settings_screen.dart';
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
  StreamSubscription<List<SuggestionView>>? _suggestionsSub;
  StreamSubscription<IncomeSchedule?>? _scheduleSub;
  StreamSubscription<DateTime?>? _lastSalarySub;
  StreamSubscription<int>? _payIncomeSub;
  StreamSubscription<int>? _payExpenseSub;

  int _monthTotal = 0;
  int _previousTotal = 0;
  int _incomeSincePay = 0;
  int _expenseSincePay = 0;
  DateTime? _lastSalaryDate;
  IncomeSchedule? _schedule;
  List<CategoryTotal> _categoryTotals = const [];
  Map<int, int> _dailyTotals = const {};
  List<TxView> _recentTxs = const [];
  List<SuggestionView> _pendingSuggestions = const [];

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
        widget.initialMonth != oldWidget.initialMonth ||
        widget.nowLocal != oldWidget.nowLocal) {
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
    _suggestionsSub?.cancel();
    _scheduleSub?.cancel();
    _lastSalarySub?.cancel();
    _payIncomeSub?.cancel();
    _payExpenseSub?.cancel();
    super.dispose();
  }

  void _updatePaySubscriptions(IncomeSchedule? sched) {
    _lastSalarySub?.cancel();
    _lastSalarySub = null;
    _payIncomeSub?.cancel();
    _payExpenseSub?.cancel();
    _payIncomeSub = null;
    _payExpenseSub = null;

    if (sched == null) {
      if (mounted) {
        setState(() {
          _lastSalaryDate = null;
          _incomeSincePay = 0;
          _expenseSincePay = 0;
        });
      }
      return;
    }

    final payDays = parsePayDays(sched.payDays);
    final rules = parsePayDayRules(sched.payDayRules, payDays);

    final prevWindow = previousPayWindow(
      _getNow(),
      payDays,
      rules,
    );

    if (prevWindow == null) {
      if (mounted) {
        setState(() {
          _lastSalaryDate = null;
          _incomeSincePay = 0;
          _expenseSincePay = 0;
        });
      }
      return;
    }

    final repo = ref.read(transactionsRepositoryProvider);
    _lastSalarySub = repo
        .watchLastConfirmedSalaryDate(
          categoryId: sched.categoryId,
          beforeOrOnLocalDay: _getNow(),
        )
        .listen((salaryDate) {
      _lastSalaryDate = salaryDate;
      DateTime periodStart = prevWindow.earliest;
      if (salaryDate != null) {
        final cleanSalary = DateTime(salaryDate.year, salaryDate.month, salaryDate.day);
        if (!cleanSalary.isBefore(prevWindow.earliest)) {
          periodStart = cleanSalary;
        }
      }

      _payIncomeSub?.cancel();
      _payExpenseSub?.cancel();

      _payIncomeSub = repo.watchTotalSince(periodStart, TxType.income).listen((income) {
        if (mounted) {
          setState(() {
            _incomeSincePay = income;
          });
        }
      });

      _payExpenseSub = repo.watchTotalSince(periodStart, TxType.expense).listen((expense) {
        if (mounted) {
          setState(() {
            _expenseSincePay = expense;
          });
        }
      });
    });
  }

  void _initSubscriptions() {
    _monthTotalSub?.cancel();
    _categoryTotalsSub?.cancel();
    _dailyTotalsSub?.cancel();
    _recentSub?.cancel();
    _suggestionsSub?.cancel();
    _scheduleSub?.cancel();
    _lastSalarySub?.cancel();
    _payIncomeSub?.cancel();
    _payExpenseSub?.cancel();

    final repo = ref.read(transactionsRepositoryProvider);
    final suggestionsRepo = ref.read(suggestionsRepositoryProvider);
    final scheduleRepo = ref.read(incomeScheduleRepositoryProvider);

    _scheduleSub = scheduleRepo.watchCurrent().listen((sched) {
      if (mounted) {
        setState(() {
          _schedule = sched;
        });
        _updatePaySubscriptions(sched);
      }
    });

    _suggestionsSub = suggestionsRepo.watchPending().listen((items) {
      if (mounted) {
        setState(() {
          _pendingSuggestions = items;
        });
      }
    });

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

    final pLine = periodLine(
      todayLocal: _getNow(),
      schedule: _schedule,
      incomeSincePay: _incomeSincePay,
      expenseSincePay: _expenseSincePay,
      lastConfirmedSalaryDate: _lastSalaryDate,
      expectedForPeriod: _schedule != null
          ? expectedAmountForPeriod(_schedule!, _getNow())
          : null,
    );

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
                  if (pLine != null) ...[
                    const SizedBox(height: 10),
                    _buildPeriodLine(context, pLine),
                  ],
                  if (_pendingSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildPendingCard(context),
                  ],
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
        Pressable(
          key: const ValueKey('home-settings-button'),
          onTap: () {
            Haptics.tick();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
              ),
            );
          },
          child: Container(
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
          RepaintBoundary(
            child: TweenAnimationBuilder<int>(
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

  Widget _buildPendingCard(BuildContext context) {
    final colors = context.pockt;
    final count = _pendingSuggestions.length;
    final names = _pendingSuggestions
        .map((s) => (s.suggestion.merchant?.isNotEmpty == true)
            ? s.suggestion.merchant!
            : (s.category?.name ?? ''))
        .where((name) => name.isNotEmpty)
        .take(2)
        .join(', ');

    final countText = count == 1 ? '1 por confirmar' : '$count por confirmar';

    return Pressable(
      key: const ValueKey('pending-suggestions-card'),
      onTap: () {
        Haptics.tick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const InboxScreen(),
          ),
        );
      },
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors.brandStart,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.brandStart.withValues(alpha: 0.8),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: countText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                  children: [
                    if (names.isNotEmpty)
                      TextSpan(
                        text: ' · $names',
                        style: TextStyle(
                          color: colors.textSecondary.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
                key: const ValueKey('pending-suggestions-text'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              uiIcon('chevron-right'),
              size: 16,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodLine(BuildContext context, PeriodLine line) {
    final colors = context.pockt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        key: const ValueKey('period-line'),
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                text: '${line.label} · quedan ',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: colors.textSecondary.withValues(alpha: 0.75),
                ),
                children: [
                  TextSpan(
                    text: line.isEstimate
                        ? '~${formatGs(line.remaining)} '
                        : formatGs(line.remaining),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: line.remaining < 0
                          ? colors.danger
                          : colors.textPrimary,
                    ),
                  ),
                  if (line.isEstimate)
                    TextSpan(
                      text: '(estimado)',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
              key: const ValueKey('period-line-remaining'),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            line.payDayText,
            key: const ValueKey('period-line-payday'),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: colors.textSecondary.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

