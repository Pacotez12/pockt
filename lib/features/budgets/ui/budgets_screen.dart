import 'dart:async';
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
import 'package:pockt/features/budgets/data/budgets_repository.dart';
import 'package:pockt/features/budgets/domain/budget_status.dart';
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

Color _getCategoryColor(Category category, bool isDark) {
  return Color(isDark ? category.colorDark : category.colorLight);
}

Color _getEffectiveColor(
  BudgetStatus status,
  Category category,
  PocktColors colors,
  bool isDark,
) {
  if (status.level == BudgetLevel.over) {
    return colors.danger;
  } else if (status.level == BudgetLevel.warning) {
    return colors.warning;
  } else {
    return _getCategoryColor(category, isDark);
  }
}

/// Anillo de progreso de presupuesto por categoría.
///
/// Muestra un arco circular animado con [PocktSprings.soft] representando el ratio
/// consumido del presupuesto. Cambia de color según el estado (categoría, advertencia ≥ 80 %,
/// peligro ≥ 100 %).
class BudgetRing extends StatefulWidget {
  final double ratio;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? child;

  const BudgetRing({
    super.key,
    required this.ratio,
    required this.color,
    this.size = 58,
    this.strokeWidth = 5,
    this.child,
  });

  @override
  State<BudgetRing> createState() => _BudgetRingState();
}

class _BudgetRingState extends State<BudgetRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _oldRatio = 0.0;

  @override
  void initState() {
    super.initState();
    _oldRatio = widget.ratio;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = AlwaysStoppedAnimation(widget.ratio);
  }

  @override
  void didUpdateWidget(BudgetRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ratio != widget.ratio) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _oldRatio = widget.ratio;
        return;
      }
      _oldRatio = _animation.value;
      _controller.reset();
      _animation = Tween<double>(begin: _oldRatio, end: widget.ratio).animate(
        CurvedAnimation(
          parent: _controller,
          curve: SpringCurve(spring: PocktSprings.soft),
        ),
      );
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final effectiveRatio = reduceMotion ? widget.ratio : _animation.value;
            return CustomPaint(
              painter: _RingPainter(
                ratio: effectiveRatio,
                color: widget.color,
                strokeWidth: widget.strokeWidth,
              ),
              child: Center(child: widget.child),
            );
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double ratio;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.ratio,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track de fondo sutil
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (ratio <= 0.0) return;

    final sweepAngle = (ratio.clamp(0.0, 1.0)) * 2 * pi;

    // Resplandor sutil cuando cruza a advertencia o exceso
    if (ratio >= 0.8) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth + 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        glowPaint,
      );
    }

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.ratio != ratio ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

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
        final schedChanged = _schedule?.id != sched?.id ||
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

    final spentMap = {for (final ct in _categoryTotals) ct.category.id: ct.total};

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

        if (prev != null) {
          if (prev != BudgetLevel.over && status.level == BudgetLevel.over) {
            Haptics.danger();
          } else if (prev == BudgetLevel.ok && status.level == BudgetLevel.warning) {
            Haptics.warning();
          }
        }
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
    final spentMap = {for (final ct in _categoryTotals) ct.category.id: ct.total};

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
                        return _buildBudgetCard(
                          context,
                          budgetView: bv,
                          spent: spent,
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
    final monthLabel = '${_kMonthNames[_month - 1]} $_year';

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
              child: Icon(
                uiIcon('plus'),
                size: 20,
                color: colors.textPrimary,
              ),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
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

  Widget _buildBudgetCard(
    BuildContext context, {
    required BudgetView budgetView,
    required int spent,
  }) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = budgetStatus(spent, budgetView.budget.monthlyLimit);
    final effectiveColor = _getEffectiveColor(
      status,
      budgetView.category,
      colors,
      isDark,
    );

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      child: Pressable(
        onTap: () => _showDetailSheet(
          context,
          budgetView: budgetView,
          spent: spent,
        ),
        child: Row(
          children: [
            BudgetRing(
              ratio: status.ratio,
              color: effectiveColor,
              size: 58,
              strokeWidth: 5,
              child: categoryIcon(
                budgetView.category.icon,
                size: 22,
                color: effectiveColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        budgetView.category.name,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: effectiveColor.withValues(alpha: isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: effectiveColor.withValues(alpha: isDark ? 0.40 : 0.25),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${(status.ratio * 100).round()} %',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: effectiveColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        formatGs(spent),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        ' de ${formatGs(budgetView.budget.monthlyLimit)}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: colors.textTertiary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.remaining >= 0
                        ? 'Quedan ${formatGs(status.remaining)}'
                        : 'Excedido por ${formatGs(-status.remaining)}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: status.level == BudgetLevel.over
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: status.level == BudgetLevel.over
                          ? colors.danger
                          : (status.level == BudgetLevel.warning
                              ? colors.warning
                              : colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja de detalle de un presupuesto para el mes actual.
class _BudgetDetailSheet extends ConsumerStatefulWidget {
  final BudgetView budgetView;
  final int spent;
  final int year;
  final int month;
  final DatePeriod? period;

  const _BudgetDetailSheet({
    required this.budgetView,
    required this.spent,
    required this.year,
    required this.month,
    this.period,
  });

  @override
  ConsumerState<_BudgetDetailSheet> createState() => _BudgetDetailSheetState();
}

class _BudgetDetailSheetState extends ConsumerState<_BudgetDetailSheet> {
  Future<void> _onEditLimit() async {
    final edited = await showBudgetLimitKeypad(
      context,
      category: widget.budgetView.category,
      initialLimit: widget.budgetView.budget.monthlyLimit,
    );
    if (edited == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _onRemoveLimit() async {
    await ref
        .read(budgetsRepositoryProvider)
        .remove(widget.budgetView.category.id);
    Haptics.tick();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = budgetStatus(widget.spent, widget.budgetView.budget.monthlyLimit);
    final effectiveColor = _getEffectiveColor(
      status,
      widget.budgetView.category,
      colors,
      isDark,
    );
    final monthLabel = '${_kMonthNames[widget.month - 1]} ${widget.year}';
    final effectivePeriod =
        widget.period ?? periodFor(DateTime(widget.year, widget.month, 15));
    final startOfMonth = effectivePeriod.start;
    final endOfMonth = effectivePeriod.end;

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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: colors.glassBorder,
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 32,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.textTertiary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Cabecera con categoría y botón cerrar
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: effectiveColor.withValues(
                                alpha: isDark ? 0.22 : 0.12,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: categoryIcon(
                              widget.budgetView.category.icon,
                              size: 24,
                              color: effectiveColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.budgetView.category.name,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  monthLabel,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Pressable(
                            onTap: () => Navigator.of(context).pop(),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                uiIcon('x'),
                                size: 20,
                                color: colors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Tarjeta de resumen
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: CustomPaint(
                                painter: _RingPainter(
                                  ratio: status.ratio,
                                  color: effectiveColor,
                                  strokeWidth: 6,
                                ),
                                child: Center(
                                  child: Text(
                                    '${(status.ratio * 100).round()}%',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: effectiveColor,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gastado: ${formatGs(widget.spent)}',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tope: ${formatGs(widget.budgetView.budget.monthlyLimit)}',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: colors.textSecondary,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    status.remaining >= 0
                                        ? 'Quedan: ${formatGs(status.remaining)}'
                                        : 'Excedido: ${formatGs(-status.remaining)}',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: status.level == BudgetLevel.over
                                          ? colors.danger
                                          : (status.level == BudgetLevel.warning
                                              ? colors.warning
                                              : colors.positive),
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Botones de acción: Editar tope y Quitar tope
                      Row(
                        children: [
                          Expanded(
                            child: Pressable(
                              onTap: _onEditLimit,
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: colors.glassFill,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: colors.glassBorder,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      uiIcon('pencil-simple'),
                                      size: 16,
                                      color: colors.textPrimary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Editar tope',
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
                          const SizedBox(width: 10),
                          Pressable(
                            onTap: _onRemoveLimit,
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: colors.danger.withValues(
                                  alpha: isDark ? 0.18 : 0.10,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: colors.danger.withValues(
                                    alpha: isDark ? 0.35 : 0.25,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    uiIcon('trash'),
                                    size: 16,
                                    color: colors.danger,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Quitar tope',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Título de lista de movimientos
                      Text(
                        'Movimientos del mes',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Lista de movimientos
                      Expanded(
                        child: StreamBuilder<List<TxView>>(
                          stream: ref
                              .watch(transactionsRepositoryProvider)
                              .watchFiltered(
                                categoryIds: {widget.budgetView.category.id},
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
                              physics: const BouncingScrollPhysics(),
                              itemCount: txs.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                return SwipeableTxRow(
                                  view: txs[index],
                                  subtitle: formatTxWhen(
                                    toLocal(txs[index].tx.occurredAt),
                                    toLocal(DateTime.now()),
                                  ),
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
          ),
        ],
      ),
    );
  }
}

/// Hoja con teclado numérico para fijar o editar el tope mensual de una categoría.
class _BudgetLimitKeypadSheet extends ConsumerStatefulWidget {
  final Category category;
  final int initialLimit;

  const _BudgetLimitKeypadSheet({
    required this.category,
    required this.initialLimit,
  });

  @override
  ConsumerState<_BudgetLimitKeypadSheet> createState() =>
      _BudgetLimitKeypadSheetState();
}

class _BudgetLimitKeypadSheetState
    extends ConsumerState<_BudgetLimitKeypadSheet> {
  late String _digits;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _digits = widget.initialLimit > 0 ? widget.initialLimit.toString() : '';
  }

  void _onKey(String key) {
    Haptics.key();
    setState(() {
      _digits = keypadAppend(_digits, key);
    });
  }

  Future<void> _onSave() async {
    final amount = keypadValue(_digits);
    if (amount <= 0 || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(budgetsRepositoryProvider)
          .setLimit(widget.category.id, amount);
      Haptics.save();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = _getCategoryColor(widget.category, isDark);
    final amount = keypadValue(_digits);
    final canSave = amount > 0 && !_isSaving;

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
              decoration: BoxDecoration(
                color: colors.sheetSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: colors.glassBorder,
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 32,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.textTertiary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Pastilla de categoría
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(
                            alpha: isDark ? 0.22 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: categoryColor.withValues(
                              alpha: isDark ? 0.45 : 0.30,
                            ),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            categoryIcon(
                              widget.category.icon,
                              size: 18,
                              color: colors.textPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.category.name,
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
                      const SizedBox(height: 12),

                      // Monto formateado
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatGs(amount),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.0,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tope mensual para ${widget.category.name}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Grilla de teclado
                      _KeypadGrid(onKey: _onKey),
                      const SizedBox(height: 14),

                      // Botón Guardar tope
                      Pressable(
                        onTap: canSave ? _onSave : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: canSave ? 1.0 : 0.4,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: categoryColor,
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: Center(
                              child: Text(
                                'Guardar tope',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: categoryColor.computeLuminance() > 0.5
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _KeypadGrid extends StatelessWidget {
  final ValueChanged<String> onKey;

  const _KeypadGrid({required this.onKey});

  static const List<String> _keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '000',
    '0',
    '⌫',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(
                  child: _KeypadBtn(
                    label: _keys[row * 3 + col],
                    onTap: () => onKey(_keys[row * 3 + col]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _KeypadBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KeypadBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Pressable(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: colors.glassFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.glassBorder, width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: label == '000' ? 18 : 22,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja para seleccionar una categoría de gasto sin presupuesto asignado.
class _AddBudgetCategoryPickerSheet extends ConsumerWidget {
  final Set<String> existingCategoryIds;

  const _AddBudgetCategoryPickerSheet({
    required this.existingCategoryIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                maxHeight: MediaQuery.of(context).size.height * 0.70,
              ),
              decoration: BoxDecoration(
                color: colors.sheetSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: colors.glassBorder,
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 32,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.textTertiary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nuevo presupuesto',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Elegí una categoría para asignarle un tope',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Pressable(
                            onTap: () => Navigator.of(context).pop(),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                uiIcon('x'),
                                size: 20,
                                color: colors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: StreamBuilder<List<Category>>(
                          stream: ref
                              .watch(categoriesRepositoryProvider)
                              .watchActive(CategoryKind.expense),
                          builder: (context, snapshot) {
                            final allCategories = snapshot.data ?? const [];
                            final available = allCategories
                                .where((c) => !existingCategoryIds.contains(c.id))
                                .toList();

                            if (available.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    'Todas las categorías de gasto ya tienen un presupuesto asignado.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: colors.textTertiary,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: available.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final cat = available[index];
                                final catColor = _getCategoryColor(cat, isDark);

                                return Pressable(
                                  onTap: () => Navigator.of(context).pop(cat),
                                  child: GlassCard(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: catColor.withValues(
                                              alpha: isDark ? 0.22 : 0.12,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: categoryIcon(
                                            cat.icon,
                                            size: 20,
                                            color: catColor,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            cat.name,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          uiIcon('caret-right'),
                                          size: 16,
                                          color: colors.textTertiary,
                                        ),
                                      ],
                                    ),
                                  ),
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
          ),
        ],
      ),
    );
  }
}

Future<bool?> showBudgetDetailSheet(
  BuildContext context, {
  required BudgetView budgetView,
  required int spent,
  required int year,
  required int month,
  DatePeriod? period,
}) {
  return Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, _) => _BudgetDetailSheet(
        budgetView: budgetView,
        spent: spent,
        year: year,
        month: month,
        period: period,
      ),
      transitionsBuilder: (context, animation, _, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: SpringCurve(spring: PocktSprings.soft),
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    ),
  );
}

Future<bool?> showBudgetLimitKeypad(
  BuildContext context, {
  required Category category,
  required int initialLimit,
}) {
  return Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, _) => _BudgetLimitKeypadSheet(
        category: category,
        initialLimit: initialLimit,
      ),
      transitionsBuilder: (context, animation, _, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: SpringCurve(spring: PocktSprings.soft),
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    ),
  );
}

Future<Category?> showAddBudgetCategoryPicker(
  BuildContext context, {
  required Set<String> existingCategoryIds,
}) {
  return Navigator.of(context).push<Category>(
    PageRouteBuilder<Category>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, _) => _AddBudgetCategoryPickerSheet(
        existingCategoryIds: existingCategoryIds,
      ),
      transitionsBuilder: (context, animation, _, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: SpringCurve(spring: PocktSprings.soft),
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    ),
  );
}
