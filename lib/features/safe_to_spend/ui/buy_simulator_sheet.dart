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
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/safe_to_spend/domain/safe_to_spend.dart';
import 'package:pockt/features/safe_to_spend/domain/tone.dart';

/// Abre la hoja modal del simulador «¿Lo compro?» (spec §7d, opción A).
Future<void> showBuySimulatorSheet(
  BuildContext context, {
  Category? initialCategory,
  SafeToSpend? initialSafeToSpend,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _BuySimulatorSheet(
      initialCategory: initialCategory,
      initialSafeToSpend: initialSafeToSpend,
    ),
  );
}

class _BuySimulatorSheet extends ConsumerStatefulWidget {
  final Category? initialCategory;
  final SafeToSpend? initialSafeToSpend;

  const _BuySimulatorSheet({this.initialCategory, this.initialSafeToSpend});

  @override
  ConsumerState<_BuySimulatorSheet> createState() => _BuySimulatorSheetState();
}

class _BuySimulatorSheetState extends ConsumerState<_BuySimulatorSheet> {
  Category? _selectedCategory;
  String _digits = '0';
  int _lastToneMessageIndex = 0;

  int get _enteredAmount => int.tryParse(_digits) ?? 0;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    if (_selectedCategory == null) {
      _loadDefaultCategory();
    }
  }

  Future<void> _loadDefaultCategory() async {
    final catRepo = ref.read(categoriesRepositoryProvider);
    final cats = await catRepo.watchActive(CategoryKind.expense).first;
    if (cats.isNotEmpty && mounted) {
      setState(() => _selectedCategory = cats.first);
    }
  }

  void _handleKey(String key) {
    Haptics.tick();
    setState(() {
      if (key == '⌫') {
        if (_digits.isNotEmpty) {
          _digits = _digits.length > 1
              ? _digits.substring(0, _digits.length - 1)
              : '0';
        }
      } else {
        if (_digits.length < 11) {
          if (_digits == '0') {
            _digits = (key == '000' || key == '00') ? '0' : key;
          } else {
            _digits += key;
          }
        }
      }
      _lastToneMessageIndex++;
    });
  }

  Future<void> _pickCategory() async {
    Haptics.tick();
    final picked = await showCategoryPickerSheet(context, type: TxType.expense);
    if (picked != null && mounted) {
      setState(() {
        _selectedCategory = picked;
        _lastToneMessageIndex++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tone = ref.watch(toneLevelProvider).value ?? ToneLevel.normal;

    // Obtener SafeToSpend actual (override de pruebas o del provider)
    final safeToSpendAsync = widget.initialSafeToSpend != null
        ? AsyncData(widget.initialSafeToSpend!)
        : ref.watch(safeToSpendProvider);

    final safeToSpend =
        safeToSpendAsync.value ??
        SafeToSpend(
          amount: 0,
          quedan: 0,
          pendingRecurring: 0,
          proratedGoals: 0,
          daysUntilPay: 1,
          targetDate: DateTime.now(),
          hasIncomeSchedule: false,
        );

    final goalsWithProgress = ref
        .watch(goalsRepositoryProvider)
        .watchActiveWithProgress();

    return StreamBuilder<List<GoalWithProgress>>(
      stream: goalsWithProgress,
      builder: (context, goalsSnap) {
        final activeGoals = goalsSnap.data ?? const [];

        return FutureBuilder<int?>(
          future: _getCategoryBudgetLimit(_selectedCategory?.id),
          builder: (context, budgetLimitSnap) {
            final categoryLimit = budgetLimitSnap.data;

            return FutureBuilder<int>(
              future: _getCategorySpentThisMonth(_selectedCategory?.id),
              builder: (context, categorySpentSnap) {
                final categorySpent = categorySpentSnap.data ?? 0;

                // Cálculos antes -> después
                final currentSafe = safeToSpend.amount;
                final afterSafe = calculateSafeToSpend(
                  remaining: safeToSpend.quedan - _enteredAmount,
                  pendingRecurring: safeToSpend.pendingRecurring,
                  proratedGoals: safeToSpend.proratedGoals,
                  daysUntilPay: safeToSpend.daysUntilPay,
                );

                final int? currentBudgetRemaining = categoryLimit != null
                    ? categoryLimit - categorySpent
                    : null;
                final int? afterBudgetRemaining = currentBudgetRemaining != null
                    ? currentBudgetRemaining - _enteredAmount
                    : null;

                // Metas con fecha
                final goalsWithDate = activeGoals
                    .where(
                      (g) =>
                          g.goal.targetDate != null && !g.progress.isCompleted,
                    )
                    .toList();

                int maxDelay = 0;
                for (final g in goalsWithDate) {
                  final delay = g.progress.delayDaysFor(_enteredAmount) ?? 0;
                  if (delay > maxDelay) {
                    maxDelay = delay;
                  }
                }

                final situation = determineBuySituation(
                  safeToSpendAfter: afterSafe,
                  budgetRemainingAfter: afterBudgetRemaining,
                  maxGoalDelayDays: maxDelay,
                );

                final message = _enteredAmount <= 0
                    ? 'Escribí un monto'
                    : getBuyMessage(
                        tone: tone,
                        situation: situation,
                        variantIndex: _lastToneMessageIndex,
                      );

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.90,
                  ),
                  decoration: BoxDecoration(
                    color: colors.sheetSurface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(PocktRadii.xl),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      // Manija superior
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
                      const SizedBox(height: 12),

                      // Encabezado
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '¿Lo compro?',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: PocktType.title,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Simulá el impacto antes de gastar',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: PocktType.caption,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Selector de categoría
                            if (_selectedCategory != null)
                              Builder(
                                builder: (context) {
                                  final catColor = Color(
                                    isDark
                                        ? _selectedCategory!.colorDark
                                        : _selectedCategory!.colorLight,
                                  );
                                  return Pressable(
                                    semanticLabel:
                                        'Elegir categoría ${_selectedCategory!.name}',
                                    onTap: _pickCategory,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: catColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(
                                          PocktRadii.xl,
                                        ),
                                        border: Border.all(
                                          color: catColor.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          categoryIcon(
                                            _selectedCategory!.icon,
                                            size: 14,
                                            color: catColor,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _selectedCategory!.name,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: PocktType.caption,
                                              fontWeight: FontWeight.w600,
                                              color: catColor,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            uiIcon('caret-down'),
                                            size: 12,
                                            color: catColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Monto grande
                      Center(
                        child: Text(
                          formatGs(_enteredAmount),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.0,
                            color: colors.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Sección antes -> después y mensaje en área con scroll
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Mensaje de tono
                              Container(
                                key: const ValueKey('buy-simulator-message'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.glassFill,
                                  borderRadius: BorderRadius.circular(
                                    PocktRadii.m,
                                  ),
                                  border: Border.all(color: colors.glassBorder),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      uiIcon('sparkle'),
                                      size: 18,
                                      color: _enteredAmount <= 0
                                          ? colors.textSecondary
                                          : (situation == BuySituation.withinDay
                                                ? colors.brandStart
                                                : (situation ==
                                                          BuySituation
                                                              .breaksBudget
                                                      ? colors.danger
                                                      : colors.warning)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        message,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: PocktType.caption,
                                          fontWeight: FontWeight.w500,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Tarjeta de comparación antes -> después
                              GlassCard(
                                borderRadius: BorderRadius.circular(
                                  PocktRadii.l,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Column(
                                  children: [
                                    // Podés gastar hoy
                                    _buildComparisonRow(
                                      context,
                                      label: 'Podés gastar hoy',
                                      beforeText:
                                          '${formatGs(currentSafe)} / día',
                                      afterText: '${formatGs(afterSafe)} / día',
                                      crossedLimit:
                                          currentSafe >= 0 && afterSafe < 0,
                                      limitWarningColor: colors.danger,
                                    ),

                                    // Presupuesto categoría
                                    if (currentBudgetRemaining != null &&
                                        afterBudgetRemaining != null) ...[
                                      Divider(
                                        height: 16,
                                        color: colors.glassBorder,
                                      ),
                                      _buildComparisonRow(
                                        context,
                                        label:
                                            'Presupuesto ${_selectedCategory?.name ?? ""}',
                                        beforeText: formatGs(
                                          currentBudgetRemaining,
                                        ),
                                        afterText: formatGs(
                                          afterBudgetRemaining,
                                        ),
                                        crossedLimit: afterBudgetRemaining < 0,
                                        limitWarningColor: colors.danger,
                                      ),
                                    ],

                                    // Metas con fecha
                                    if (goalsWithDate.isNotEmpty) ...[
                                      Divider(
                                        height: 16,
                                        color: colors.glassBorder,
                                      ),
                                      ...goalsWithDate.map((g) {
                                        final delay =
                                            g.progress.delayDaysFor(
                                              _enteredAmount,
                                            ) ??
                                            0;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      uiIcon(g.goal.icon),
                                                      size: 14,
                                                      color:
                                                          colors.textSecondary,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        g.goal.name,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontFamily: 'Inter',
                                                          fontSize:
                                                              PocktType.caption,
                                                          color: colors
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                delay > 0
                                                    ? '+$delay días de atraso'
                                                    : 'Sin atraso',
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: PocktType.caption,
                                                  fontWeight: FontWeight.w600,
                                                  color: delay > 0
                                                      ? colors.warning
                                                      : colors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Teclado numérico
                              _buildKeypad(context, isDark: isDark),
                              const SizedBox(height: 14),

                              // Botones de acción
                              Row(
                                children: [
                                  // No, gracias
                                  Expanded(
                                    child: Pressable(
                                      key: const ValueKey(
                                        'buy-simulator-cancel',
                                      ),
                                      semanticLabel: 'No, gracias',
                                      onTap: () {
                                        Haptics.tick();
                                        Navigator.of(context).pop();
                                      },
                                      child: Container(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: colors.glassFill,
                                          borderRadius: BorderRadius.circular(
                                            PocktRadii.l,
                                          ),
                                          border: Border.all(
                                            color: colors.glassBorder,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'No, gracias',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Lo compro
                                  Expanded(
                                    child: Pressable(
                                      key: const ValueKey(
                                        'buy-simulator-confirm',
                                      ),
                                      semanticLabel: 'Lo compro',
                                      onTap: () {
                                        Haptics.save();
                                        Navigator.of(context).pop();
                                        if (_selectedCategory != null) {
                                          showEntryFlow(
                                            context,
                                            initialCategoryId:
                                                _selectedCategory!.id,
                                            initialAmount: _enteredAmount > 0
                                                ? _enteredAmount
                                                : null,
                                          );
                                        }
                                      },
                                      child: Container(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              colors.brandStart,
                                              colors.brandEnd,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            PocktRadii.l,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: colors.brandStart
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'Lo compro',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildComparisonRow(
    BuildContext context, {
    required String label,
    required String beforeText,
    required String afterText,
    required bool crossedLimit,
    required Color limitWarningColor,
  }) {
    final colors = context.pockt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: PocktType.caption,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    beforeText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: PocktType.caption,
                      color: colors.textTertiary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
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
                      Icon(
                        uiIcon('caret-right'),
                        size: 12,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        afterText,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: PocktType.caption,
                          fontWeight: FontWeight.w700,
                          color: crossedLimit
                              ? limitWarningColor
                              : colors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad(BuildContext context, {required bool isDark}) {
    final colors = context.pockt;
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '000', '0', '⌫'];

    return Column(
      children: [
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) const SizedBox(height: 6),
          Row(
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 6),
                Expanded(
                  child: Pressable(
                    semanticLabel: keys[row * 3 + col] == '⌫'
                        ? 'Borrar'
                        : 'Tecla ${keys[row * 3 + col]}',
                    onTap: () => _handleKey(keys[row * 3 + col]),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(PocktRadii.m),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        keys[row * 3 + col],
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: keys[row * 3 + col] == '000' ? 16 : 20,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Future<int?> _getCategoryBudgetLimit(String? categoryId) async {
    if (categoryId == null) return null;
    final db = ref.read(databaseProvider);
    final budget = await (db.select(
      db.budgets,
    )..where((b) => b.categoryId.equals(categoryId))).getSingleOrNull();
    if (budget == null || budget.monthlyLimit <= 0) return null;
    return budget.monthlyLimit;
  }

  Future<int> _getCategorySpentThisMonth(String? categoryId) async {
    if (categoryId == null) return 0;
    final now = DateTime.now();
    final txRepo = ref.read(transactionsRepositoryProvider);
    final totals = await txRepo
        .watchMonthCategoryTotals(now.year, now.month)
        .first;
    for (final ct in totals) {
      if (ct.category.id == categoryId) {
        return ct.total;
      }
    }
    return 0;
  }
}
