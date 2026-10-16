import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/reports/data/reports_repository.dart';
import 'package:pockt/features/reports/ui/charts.dart';

class MerchantsView extends ConsumerWidget {
  final int year;
  final int month;
  final bool isDark;

  const MerchantsView({
    super.key,
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
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${list.length} ${list.length == 1 ? 'comercio' : 'comercios'}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  Text(
                    formatGs(list.fold<int>(0, (s, e) => s + e.total)),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
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
                        color: colors.glassBorder,
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
