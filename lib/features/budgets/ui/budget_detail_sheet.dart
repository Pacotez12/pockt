import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/budgets/data/budgets_repository.dart';
import 'package:pockt/features/budgets/domain/budget_status.dart';
import 'package:pockt/features/budgets/ui/budget_limit_keypad_sheet.dart';
import 'package:pockt/features/budgets/ui/budget_ring_card.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/transactions/ui/tx_row.dart';

/// Hoja de detalle de un presupuesto para el mes actual.
class BudgetDetailSheet extends ConsumerStatefulWidget {
  final BudgetView budgetView;
  final int spent;
  final int year;
  final int month;
  final DatePeriod? period;

  const BudgetDetailSheet({
    super.key,
    required this.budgetView,
    required this.spent,
    required this.year,
    required this.month,
    this.period,
  });

  @override
  ConsumerState<BudgetDetailSheet> createState() => _BudgetDetailSheetState();
}

class _BudgetDetailSheetState extends ConsumerState<BudgetDetailSheet> {
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
    final status = budgetStatus(
      widget.spent,
      widget.budgetView.budget.monthlyLimit,
    );
    final effectiveColor = getBudgetEffectiveColor(
      status,
      widget.budgetView.category,
      colors,
      isDark,
    );
    final monthLabel = '${kBudgetMonthNames[widget.month - 1]} ${widget.year}';
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(color: colors.glassBorder, width: 1),
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
                            semanticLabel: 'Cerrar',
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
                      BudgetDetailSummaryCard(
                        spent: widget.spent,
                        monthlyLimit: widget.budgetView.budget.monthlyLimit,
                        status: status,
                        effectiveColor: effectiveColor,
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
                                  borderRadius: BorderRadius.circular(
                                    PocktRadii.xl,
                                  ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: colors.danger.withValues(
                                  alpha: isDark ? 0.18 : 0.10,
                                ),
                                borderRadius: BorderRadius.circular(
                                  PocktRadii.xl,
                                ),
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
                      const SizedBox(height: 12),

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
                            return ListView(
                              physics: const BouncingScrollPhysics(),
                              children: [
                                TxGroupCard(
                                  items: txs,
                                  subtitleBuilder: (view) => formatTxWhen(
                                    toLocal(view.tx.occurredAt),
                                    toLocal(DateTime.now()),
                                  ),
                                ),
                              ],
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
      pageBuilder: (context, _, _) => BudgetDetailSheet(
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
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    ),
  );
}
