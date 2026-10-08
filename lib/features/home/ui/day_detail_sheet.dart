import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/transactions/ui/tx_row.dart';

/// Abre la hoja de detalle de un día local con Hero y animación de resorte.
Future<void> showDayDetail(BuildContext context, DateTime localDay) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, _) => DayDetailSheet(localDay: localDay),
      transitionsBuilder: (context, animation, _, child) {
        if (MediaQuery.disableAnimationsOf(context)) {
          return child;
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: SpringCurve(spring: PocktSprings.soft),
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Hoja de detalle de un día (spec §5.2.6 y mockup inicio-v1.html):
/// Título con fecha larga en español, total gastado, comparación con el día
/// promedio del mes, barras "En qué se fue" por categoría y lista de movimientos.
class DayDetailSheet extends ConsumerWidget {
  final DateTime localDay;

  const DayDetailSheet({super.key, required this.localDay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = ref.watch(transactionsRepositoryProvider);

    final dayStream = repo.watchDay(localDay);
    final monthDailyStream = repo.watchDailyExpenseTotals(localDay.year, localDay.month);

    final sheetHeight = min(MediaQuery.of(context).size.height * 0.85, 580.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tocar fuera cierra la hoja
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          // Hoja inferior con Hero
          Align(
            alignment: Alignment.bottomCenter,
            child: Hero(
              tag: 'day-sheet-${localDay.year}-${localDay.month}-${localDay.day}',
              createRectTween: (begin, end) => SpringRectTween(begin: begin, end: end),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: sheetHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF18181B).withValues(alpha: 0.96)
                        : Colors.white.withValues(alpha: 0.98),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: StreamBuilder<List<TxView>>(
                    stream: dayStream,
                    builder: (context, daySnapshot) {
                      final dayTxs = daySnapshot.data ?? const [];

                      return StreamBuilder<Map<int, int>>(
                        stream: monthDailyStream,
                        builder: (context, monthSnapshot) {
                          final dailyTotals = monthSnapshot.data ?? const {};
                          return _buildContent(
                            context,
                            dayTxs: dayTxs,
                            monthDailyTotals: dailyTotals,
                            colors: colors,
                            isDark: isDark,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required List<TxView> dayTxs,
    required Map<int, int> monthDailyTotals,
    required PocktColors colors,
    required bool isDark,
  }) {
    // Gastos del día
    final expenses = dayTxs.where((v) => v.tx.type == TxType.expense).toList();
    final dayExpenseTotal = expenses.fold<int>(0, (sum, v) => sum + v.tx.amount);

    // Días del mes con gasto y promedio
    final positiveDays = monthDailyTotals.entries.where((e) => e.value > 0).toList();
    final daysWithExpenseCount = positiveDays.length;
    final monthExpenseTotal = positiveDays.fold<int>(0, (sum, e) => sum + e.value);

    // Múltiplo y día más caro
    String? comparisonText;
    if (daysWithExpenseCount > 1 && dayExpenseTotal > 0) {
      final promedio = monthExpenseTotal / daysWithExpenseCount;
      if (promedio > 0) {
        final ratio = dayExpenseTotal / promedio;
        final ratioFormatted = ratio.toStringAsFixed(1).replaceAll('.', ',');
        final maxDayExpense = positiveDays.map((e) => e.value).fold<int>(0, max);
        final isMostExpensive = dayExpenseTotal >= maxDayExpense;

        final caroSuffix = isMostExpensive ? ' · tu día más caro del mes' : '';
        comparisonText = '↑ $ratioFormatted× tu día promedio$caroSuffix';
      }
    }

    // Categorías del día ("En qué se fue")
    final catTotalsMap = <String, ({Category category, int total})>{};
    for (final v in expenses) {
      final existing = catTotalsMap[v.category.id];
      if (existing == null) {
        catTotalsMap[v.category.id] = (category: v.category, total: v.tx.amount);
      } else {
        catTotalsMap[v.category.id] = (
          category: v.category,
          total: existing.total + v.tx.amount,
        );
      }
    }
    final categoryBreakdown = catTotalsMap.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Indicador de arrastre superior
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 120) {
              Navigator.of(context).pop();
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Center(
              child: Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.20),
                ),
              ),
            ),
          ),
        ),
        // Cuerpo con scroll
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fecha larga: "Sábado 17 de octubre"
                Text(
                  formatLongDay(localDay),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                // Total del día: "Gs. 612.000"
                Text(
                  formatGs(dayExpenseTotal),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.2,
                    color: colors.textPrimary,
                  ),
                ),
                if (comparisonText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    comparisonText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.brandStart,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                // "En qué se fue"
                if (categoryBreakdown.isNotEmpty) ...[
                  Text(
                    'En qué se fue',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final item in categoryBreakdown) ...[
                    _buildCategoryBarItem(
                      item: item,
                      dayTotal: dayExpenseTotal,
                      colors: colors,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 10),
                ],
                // "Movimientos"
                Text(
                  'Movimientos',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                if (dayTxs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Sin movimientos en este día',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                  )
                else
                  for (final view in dayTxs)
                    SwipeableTxRow(
                      view: view,
                      subtitle: _rowSubtitle(view),
                    ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBarItem({
    required ({Category category, int total}) item,
    required int dayTotal,
    required PocktColors colors,
    required bool isDark,
  }) {
    final catColor = Color(isDark ? item.category.colorDark : item.category.colorLight);
    final ratio = dayTotal > 0 ? (item.total / dayTotal).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                categoryIcon(item.category.icon, size: 16, color: catColor),
                const SizedBox(width: 6),
                Text(
                  item.category.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            Text(
              formatGs(item.total, symbol: false),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: colors.glassFill,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: catColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _rowSubtitle(TxView view) {
    final localTime = toLocal(view.tx.occurredAt);
    final timeStr =
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    final merchant = view.tx.merchant?.trim();
    if (merchant != null && merchant.isNotEmpty) {
      return '${view.category.name} · $timeStr';
    }
    return timeStr;
  }
}
