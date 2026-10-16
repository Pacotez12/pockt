import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/events/data/events_repository.dart';

class EventCategoryBreakdownCard extends StatelessWidget {
  final EventDetail detail;

  const EventCategoryBreakdownCard({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    if (detail.categoryBreakdown.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        borderRadius: BorderRadius.circular(PocktRadii.l),
        child: Center(
          child: Text(
            'Todavía no hay gastos asignados a este evento.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
        ),
      );
    }
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: BorderRadius.circular(PocktRadii.l),
      child: Column(
        children: detail.categoryBreakdown.map((item) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final catColor = Color(
            isDark ? item.category.colorDark : item.category.colorLight,
          );

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: catColor.withValues(alpha: 0.2),
                      ),
                      child: Center(
                        child: categoryIcon(
                          item.category.icon,
                          size: 16,
                          color: catColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.category.name,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      formatGs(item.total),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.percentage.toStringAsFixed(0)} %',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (item.percentage / 100).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: colors.glassBorder,
                    valueColor: AlwaysStoppedAnimation(catColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class EventTransactionsList extends StatelessWidget {
  final EventDetail detail;

  const EventTransactionsList({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    if (detail.transactions.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        borderRadius: BorderRadius.circular(PocktRadii.l),
        child: Center(
          child: Text(
            'Sin movimientos',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: detail.transactions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = detail.transactions[index];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final catColor = Color(
          isDark ? row.category.colorDark : row.category.colorLight,
        );

        final label =
            row.tx.merchant != null && row.tx.merchant!.trim().isNotEmpty
            ? row.tx.merchant!
            : row.category.name;

        final note = row.tx.note != null && row.tx.note!.trim().isNotEmpty
            ? row.tx.note!
            : DateFormat('dd/MM HH:mm').format(row.tx.occurredAt.toLocal());

        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          borderRadius: BorderRadius.circular(PocktRadii.m),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: catColor.withValues(alpha: 0.2),
                ),
                child: Center(
                  child: categoryIcon(
                    row.category.icon,
                    size: 18,
                    color: catColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      note,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: PocktType.caption,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                formatGs(row.tx.amount),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
