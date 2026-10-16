import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/budgets/data/budgets_repository.dart';
import 'package:pockt/features/budgets/domain/budget_status.dart';
import 'package:pockt/features/budgets/ui/add_budget_category_picker_sheet.dart';
import 'package:pockt/features/budgets/ui/budget_detail_sheet.dart';
import 'package:pockt/features/budgets/ui/budget_limit_keypad_sheet.dart';
import 'package:pockt/features/budgets/ui/budget_ring_card.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

export 'package:pockt/features/budgets/ui/add_budget_category_picker_sheet.dart';
export 'package:pockt/features/budgets/ui/budget_detail_sheet.dart';
export 'package:pockt/features/budgets/ui/budget_limit_keypad_sheet.dart';
export 'package:pockt/features/budgets/ui/budget_ring_card.dart';

/// Pantalla de Presupuestos.
///
/// Lista los presupuestos mensuales activos por categoría con sus anillos de progreso,
/// montos gastados y restantes, y alertas visuales/hápticas.
class BudgetsScreen extends ConsumerStatefulWidget {
  final int? initialYear;
  final int? initialMonth;
  final DateTime? nowLocal;

  const BudgetsScreen({
    super.key,
    this.initialYear,
    this.initialMonth,
    this.nowLocal,
  });

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  late int _year;
  late int _month;

  StreamSubscription<List<BudgetView>>? _budgetsSub;
  StreamSubscription<List<CategoryTotal>>? _totalsSub;
  MonthStartMode _monthStartMode = MonthStartMode.calendar;
  StreamSubscription<MonthStartMode>? _monthStartSub;
  IncomeSchedule? _schedule;
  StreamSubscription<IncomeSchedule?>? _scheduleSub;

  List<BudgetView> _budgets = const [];
  List<CategoryTotal> _categoryTotals = const [];

  final Map<String, BudgetLevel> _previousLevels = {};
  bool _hasInitialData = false;

  DateTime _getNow() => widget.nowLocal ?? toLocal(DateTime.now());

  DatePeriod get _currentPeriod {
    final now = _getNow();
    final isCurrent = _year == now.year && _month == now.month;
    final day = isCurrent ? now : DateTime(_year, _month, 15);
    return periodFor(day, mode: _monthStartMode, schedule: _schedule);
  }

  @override
  void initState() {
    super.initState();
    final now = _getNow();
    _year = widget.initialYear ?? now.year;
    _month = widget.initialMonth ?? now.month;
    _initSubscriptions();
  }

  @override
  void didUpdateWidget(BudgetsScreen oldWidget) {
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
    _budgetsSub?.cancel();
    _totalsSub?.cancel();
    _monthStartSub?.cancel();
    _scheduleSub?.cancel();
    super.dispose();
  }

  void _initMonthDataSubscriptions() {
    _totalsSub?.cancel();
    final txRepo = ref.read(transactionsRepositoryProvider);
    _totalsSub = txRepo
        .watchMonthCategoryTotals(_year, _month, period: _currentPeriod)
        .listen((totals) {
          _handleDataUpdate(totals: totals);
        });
  }

  void _initSubscriptions() {
    _budgetsSub?.cancel();
    _monthStartSub?.cancel();
    _scheduleSub?.cancel();

    final budgetsRepo = ref.read(budgetsRepositoryProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final scheduleRepo = ref.read(incomeScheduleRepositoryProvider);

    _monthStartSub = settingsRepo
        .watch(SettingsKeys.periodMonthStart)
        .map(MonthStartMode.parse)
        .listen((mode) {
          if (mounted && mode != _monthStartMode) {
            setState(() {
              _monthStartMode = mode;
            });
            _initMonthDataSubscriptions();
          }
        });

    _scheduleSub = scheduleRepo.watchCurrent().listen((sched) {
      if (mounted) {
        final schedChanged =
            _schedule?.id != sched?.id ||
            _schedule?.payDays != sched?.payDays ||
            _schedule?.payDayRules != sched?.payDayRules;
        setState(() {
          _schedule = sched;
        });
        if (schedChanged && _monthStartMode == MonthStartMode.payday) {
          _initMonthDataSubscriptions();
        }
      }
    });

    _budgetsSub = budgetsRepo.watchAll().listen((budgets) {
      _handleDataUpdate(budgets: budgets);
    });

    _initMonthDataSubscriptions();
  }

  void _handleDataUpdate({
    List<BudgetView>? budgets,
    List<CategoryTotal>? totals,
  }) {
    if (budgets != null) _budgets = budgets;
    if (totals != null) _categoryTotals = totals;

    final spentMap = {
      for (final ct in _categoryTotals) ct.category.id: ct.total,
    };

    if (!_hasInitialData) {
      for (final bv in _budgets) {
        final spent = spentMap[bv.category.id] ?? 0;
        final status = budgetStatus(spent, bv.budget.monthlyLimit);
        _previousLevels[bv.category.id] = status.level;
      }
      _hasInitialData = true;
    } else {
      for (final bv in _budgets) {
        final spent = spentMap[bv.category.id] ?? 0;
        final status = budgetStatus(spent, bv.budget.monthlyLimit);
        final prev = _previousLevels[bv.category.id];
        triggerBudgetThresholdAlert(prev, status.level);
        _previousLevels[bv.category.id] = status.level;
      }
    }

    _previousLevels.removeWhere(
      (catId, _) => !_budgets.any((b) => b.category.id == catId),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showAddBudgetDialog(BuildContext context) async {
    final existingIds = _budgets.map((b) => b.category.id).toSet();
    final selectedCat = await showAddBudgetCategoryPicker(
      context,
      existingCategoryIds: existingIds,
    );
    if (selectedCat != null && context.mounted) {
      await showBudgetLimitKeypad(
        context,
        category: selectedCat,
        initialLimit: 0,
      );
    }
  }

  Future<void> _showDetailSheet(
    BuildContext context, {
    required BudgetView budgetView,
    required int spent,
  }) async {
    await showBudgetDetailSheet(
      context,
      budgetView: budgetView,
      spent: spent,
      year: _year,
      month: _month,
      period: _currentPeriod,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final spentMap = {
      for (final ct in _categoryTotals) ct.category.id: ct.total,
    };

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTopBar(context),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _budgets.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _budgets.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _budgets.length) {
                          return const SizedBox(height: 120);
                        }
                        final bv = _budgets[index];
                        final spent = spentMap[bv.category.id] ?? 0;
                        return BudgetCard(
                          budgetView: bv,
                          spent: spent,
                          onTap: () => _showDetailSheet(
                            context,
                            budgetView: bv,
                            spent: spent,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final colors = context.pockt;
    final monthLabel = '${kBudgetMonthNames[_month - 1]} $_year';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Presupuestos',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                monthLabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Pressable(
          semanticLabel: 'Agregar presupuesto',
          onTap: () => _showAddBudgetDialog(context),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.glassFill,
              shape: BoxShape.circle,
              border: Border.all(color: colors.glassBorder, width: 1),
            ),
            child: Center(
              child: Icon(uiIcon('plus'), size: 20, color: colors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.pockt;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.glassFill,
                shape: BoxShape.circle,
                border: Border.all(color: colors.glassBorder, width: 1),
              ),
              child: Center(
                child: Icon(
                  uiIcon('chart-pie-slice'),
                  size: 32,
                  color: colors.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin presupuestos',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Asigná límites mensuales a tus gastos para mantener el control de tus finanzas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Pressable(
              onTap: () => _showAddBudgetDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PocktRadii.xl),
                  gradient: LinearGradient(
                    colors: [colors.brandStart, colors.brandEnd],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.brandEnd.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Crear primer presupuesto',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
