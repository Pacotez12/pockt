import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/reports/ui/views/report_shared_widgets.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/transactions/ui/tx_row.dart';

class CategoryTransactionsSheet extends ConsumerWidget {
  final Category category;
  final int year;
  final int month;
  final DateTime nowLocal;

  const CategoryTransactionsSheet({
    super.key,
    required this.category,
    required this.year,
    required this.month,
    required this.nowLocal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = Color(isDark ? category.colorDark : category.colorLight);
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(top: BorderSide(color: colors.glassBorder)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                                  '${kReportMonthNames[month - 1]} $year',
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
                              final hasMerchant =
                                  item.tx.merchant != null &&
                                  item.tx.merchant!.trim().isNotEmpty;
                              final hasNote =
                                  item.tx.note != null &&
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
