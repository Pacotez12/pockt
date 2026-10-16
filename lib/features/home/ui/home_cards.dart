import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/amounts_privacy.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/backup/ui/backup_screen.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/goals/ui/goals_screen.dart';
import 'package:pockt/features/home/data/home_providers.dart';
import 'package:pockt/features/home/domain/heat_levels.dart';
import 'package:pockt/features/home/ui/day_detail_sheet.dart';
import 'package:pockt/features/home/ui/heat_calendar.dart';
import 'package:pockt/features/home/ui/home_month_card.dart';
import 'package:pockt/features/home/ui/month_glow.dart';
import 'package:pockt/features/income/domain/period_summary.dart';
import 'package:pockt/features/income/ui/carry_over_card.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/loans/ui/loans_screen.dart';
import 'package:pockt/features/recurring/ui/inbox_screen.dart';
import 'package:pockt/features/transactions/ui/tx_row.dart';

/// Resplandor de fondo colocado detrás de la tarjeta de Inicio.
class HomeGlowHost extends ConsumerWidget {
  final int year;
  final int month;
  final DateTime nowLocal;

  const HomeGlowHost({
    super.key,
    required this.year,
    required this.month,
    required this.nowLocal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final glowMode = ref.watch(glowModeProvider).value ?? GlowMode.subtle;
    final glowColor = ref.watch(
      homeGlowColorProvider((
        year: year,
        month: month,
        nowLocal: nowLocal,
        isDark: isDark,
        brandStart: colors.brandStart,
      )),
    );

    return Positioned(
      top: -140,
      left: (screenWidth - 470) / 2,
      child: MonthGlow(
        color: glowColor,
        pulseTrigger: ref.watch(monthGlowPulseProvider),
        mode: glowMode,
      ),
    );
  }
}

/// Tarjeta de préstamos y cuotas en el Inicio.
class HomeLoansCard extends ConsumerWidget {
  const HomeLoansCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final obscure = ref.watch(shouldObscureAmountsProvider);
    final loansAsync = ref.watch(activeLoansWithProgressProvider);

    return loansAsync.maybeWhen(
      data: (loansWithProgress) {
        if (loansWithProgress.isEmpty) return const SizedBox.shrink();

        int totalOwe = 0;
        int totalLent = 0;
        for (final item in loansWithProgress) {
          if (item.loan.direction == LoanDirection.owe) {
            totalOwe += item.progress.balance;
          } else {
            totalLent += item.progress.balance;
          }
        }

        final dues =
            loansWithProgress.where((item) => item.loan.dueDay != null).toList()
              ..sort(
                (a, b) => (a.progress.daysUntilNextDue ?? 99999).compareTo(
                  b.progress.daysUntilNextDue ?? 99999,
                ),
              );
        final topDues = dues.take(3).toList();

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Pressable(
            key: const ValueKey('home-loans-card'),
            onTap: () {
              Haptics.tick();
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const LoansScreen()));
            },
            child: GlassCard(
              borderRadius: BorderRadius.circular(PocktRadii.xl),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: colors
                              .brandAt(0)
                              .withValues(alpha: isDark ? 0.2 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            uiIcon('hand-coins'),
                            size: 15,
                            color: colors.brandAt(0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Préstamos y cuotas',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        uiIcon('caret-right'),
                        size: 14,
                        color: colors.textSecondary.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (totalOwe > 0 || totalLent == 0)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Debés',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                obscure ? '••••' : formatGs(totalOwe),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  color: colors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (totalLent > 0)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Te deben',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                obscure ? '••••' : formatGs(totalLent),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  color: colors.positive,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (topDues.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, color: colors.glassBorder),
                    const SizedBox(height: 10),
                    ...topDues.map((item) {
                      final dueDays = item.progress.daysUntilNextDue;
                      String dueBadge;
                      Color badgeColor = colors.textSecondary;
                      if (dueDays != null) {
                        if (dueDays < 0) {
                          dueBadge = 'Vencido';
                          badgeColor = colors.danger;
                        } else if (dueDays == 0) {
                          dueBadge = 'Vence hoy';
                          badgeColor = colors.warning;
                        } else if (dueDays == 1) {
                          dueBadge = 'Vence mañana';
                          badgeColor = colors.warning;
                        } else if (dueDays <= 5) {
                          dueBadge = 'Vence en $dueDays días';
                          badgeColor = colors.warning;
                        } else {
                          dueBadge = 'Día ${item.loan.dueDay}';
                        }
                      } else {
                        dueBadge = 'Día ${item.loan.dueDay}';
                      }

                      final installment =
                          item.loan.installmentAmount ?? item.progress.balance;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.loan.name,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(
                                  alpha: isDark ? 0.15 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(
                                  PocktRadii.s,
                                ),
                              ),
                              child: Text(
                                dueBadge,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              obscure ? '••••' : formatGs(installment),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
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
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Tarjeta de metas de ahorro en el Inicio.
class HomeGoalsCard extends ConsumerWidget {
  const HomeGoalsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final obscure = ref.watch(shouldObscureAmountsProvider);
    final goalsAsync = ref.watch(activeGoalsWithProgressProvider);

    return goalsAsync.maybeWhen(
      data: (goalsWithProgress) {
        if (goalsWithProgress.isEmpty) return const SizedBox.shrink();

        final displayGoals = goalsWithProgress.take(2).toList();
        final totalSaved = goalsWithProgress.fold<int>(
          0,
          (sum, item) => sum + item.progress.saved,
        );

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Pressable(
            key: const ValueKey('home-goals-card'),
            semanticLabel: 'Ver metas',
            onTap: () {
              Haptics.tick();
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const GoalsScreen()));
            },
            child: GlassCard(
              borderRadius: BorderRadius.circular(PocktRadii.xl),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: colors
                              .brandAt(0)
                              .withValues(alpha: isDark ? 0.2 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            uiIcon('target'),
                            size: 15,
                            color: colors.brandAt(0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Metas',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: PocktType.body,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        obscure ? '••••' : formatGs(totalSaved),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.brandAt(0),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        uiIcon('caret-right'),
                        size: 14,
                        color: colors.textTertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...displayGoals.map((item) {
                    final goal = item.goal;
                    final progress = item.progress;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      uiIcon(goal.icon),
                                      size: 14,
                                      color: colors.brandAt(0),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        goal.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: PocktType.caption,
                                          fontWeight: FontWeight.w600,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                obscure
                                    ? '••••'
                                    : '${(progress.percent * 100).toInt()} %',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(PocktRadii.s),
                            child: SizedBox(
                              height: 5,
                              child: Stack(
                                children: [
                                  Container(color: colors.glassBorder),
                                  FractionallySizedBox(
                                    widthFactor: progress.percent.clamp(
                                      0.0,
                                      1.0,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            colors.brandStart,
                                            colors.brandEnd,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Tarjeta de sugerencias pendientes en el Inicio.
class HomePendingSuggestionsCard extends ConsumerWidget {
  const HomePendingSuggestionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final pending =
        ref.watch(homePendingSuggestionsProvider).value ?? const [];
    if (pending.isEmpty) return const SizedBox.shrink();

    final count = pending.length;
    final names = pending
        .map(
          (s) => (s.suggestion.merchant?.isNotEmpty == true)
              ? s.suggestion.merchant!
              : (s.category?.name ?? ''),
        )
        .where((name) => name.isNotEmpty)
        .take(2)
        .join(', ');

    final countText = count == 1 ? '1 por confirmar' : '$count por confirmar';

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Pressable(
        key: const ValueKey('pending-suggestions-card'),
        onTap: () {
          Haptics.tick();
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const InboxScreen()));
        },
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          borderRadius: BorderRadius.circular(PocktRadii.l),
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
              Icon(uiIcon('chevron-right'), size: 16, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sección de últimos movimientos registrados.
class HomeRecentTransactionsCard extends ConsumerWidget {
  final DateTime nowLocal;

  const HomeRecentTransactionsCard({
    super.key,
    required this.nowLocal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final recent = ref.watch(homeRecentMovementsProvider).value ?? const [];

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
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
          TxGroupCard(
            entries: recent,
            cardRadius: 24,
            subtitleBuilder: (item) =>
                formatTxWhen(toLocal(item.tx.occurredAt), nowLocal),
            contribSubtitleBuilder: (item) =>
                formatTxWhen(toLocal(item.contribution.date), nowLocal),
            emptyPlaceholder: Text(
              'Sin movimientos aún',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de copia de seguridad pendiente.
class HomeOverdueBackupBanner extends StatelessWidget {
  final bool never;

  const HomeOverdueBackupBanner({
    super.key,
    this.never = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Pressable(
      key: const ValueKey('backup-overdue-banner'),
      onTap: () {
        Haptics.tick();
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const BackupScreen()));
      },
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: BorderRadius.circular(PocktRadii.l),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors.warning,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.warning.withValues(alpha: 0.8),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                never
                    ? 'Activá la copia de seguridad'
                    : 'Copia de seguridad pendiente (hace más de 5 días)',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.warning,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(uiIcon('caret-right'), size: 16, color: colors.warning),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de período / saldo arrastrado cuando el layout no usa el arco o hay saldo arrastrado pendiente de decisión.
class HomePeriodCard extends ConsumerWidget {
  final PeriodLine? periodLine;
  final DateTime? payPeriodStart;
  final IncomeSchedule? schedule;
  final bool arcHome;

  const HomePeriodCard({
    super.key,
    required this.periodLine,
    required this.payPeriodStart,
    required this.schedule,
    required this.arcHome,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pLine = periodLine;
    if (pLine == null) return const SizedBox.shrink();

    final decided = ref.watch(carryOverDecidedProvider).value;
    final showCarryCard =
        pLine.carryOver > 0 &&
        payPeriodStart != null &&
        !carryOverDecided(decided, payPeriodStart!);

    // Con el Arco de hoy, la línea del período vive en la tarjeta del mes.
    if (arcHome && !showCarryCard) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!arcHome)
            HomePeriodLine(
              line: pLine,
              scheduleMode: schedule?.mode,
            ),
          if (showCarryCard) ...[
            if (!arcHome) const SizedBox(height: 12),
            CarryOverCard(
              amount: pLine.carryOver,
              periodStart: payPeriodStart!,
              monthly: schedule?.mode.toLowerCase() == 'monthly',
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta del calendario de calor.
class HomeCalendarCard extends ConsumerWidget {
  final int year;
  final int month;
  final DateTime todayLocal;
  final WeekStart weekStart;
  final GestureDragEndCallback onHorizontalSwipe;

  const HomeCalendarCard({
    super.key,
    required this.year,
    required this.month,
    required this.todayLocal,
    required this.weekStart,
    required this.onHorizontalSwipe,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyTotals =
        ref
            .watch(
              homeDailyTotalsProvider((
                year: year,
                month: month,
                nowLocal: todayLocal,
              )),
            )
            .value ??
        const {};

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GestureDetector(
        onHorizontalDragEnd: onHorizontalSwipe,
        child: HeatCalendar(
          year: year,
          month: month,
          levels: heatLevels(dailyTotals),
          todayLocal: todayLocal,
          weekStart: weekStart,
          onDayTap: (day) {
            showDayDetail(context, DateTime(year, month, day));
          },
        ),
      ),
    );
  }
}
