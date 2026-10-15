import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/goals/domain/goal_progress.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:pockt/features/income/domain/period_summary.dart';

/// Resultado del cálculo de "Podés gastar hoy" (spec §7d).
class SafeToSpend {
  /// Monto diario disponible para gastar hoy (puede ser negativo).
  final int amount;

  /// Restante neto del período actual ("quedan").
  final int quedan;

  /// Suma de recurrentes de gasto pendientes antes del próximo cobro.
  final int pendingRecurring;

  /// Aporte de metas con fecha prorrateado a los días hasta el cobro.
  final int proratedGoals;

  /// Días que faltan hasta el cobro (o fin de mes si no hay esquema).
  final int daysUntilPay;

  /// Fecha objetivo de corte (cobro o fin de mes).
  final DateTime targetDate;

  /// Indica si el cálculo se hizo con un esquema de cobro configurado.
  final bool hasIncomeSchedule;

  const SafeToSpend({
    required this.amount,
    required this.quedan,
    required this.pendingRecurring,
    required this.proratedGoals,
    required this.daysUntilPay,
    required this.targetDate,
    required this.hasIncomeSchedule,
  });
}

/// Función pura que aplica la fórmula matemática de §7d:
/// (quedan − recurrentes pendientes − metas prorrateadas) ÷ max(1, díasHastaCobro).
int calculateSafeToSpend({
  required int remaining,
  int pendingRecurring = 0,
  int proratedGoals = 0,
  required int daysUntilPay,
}) {
  final effectiveDays = max(1, daysUntilPay);
  final net = remaining - pendingRecurring - proratedGoals;
  return (net / effectiveDays).round();
}

/// Función pura que calcula "Podés gastar hoy" según la especificación §7d.
///
/// Si [nextPayDate] es null, se asume sin esquema de cobro y se usa el fin de mes
/// del mes corriente de [todayLocal].
SafeToSpend safeToSpendToday({
  required DateTime todayLocal,
  required int remaining,
  DateTime? nextPayDate,
  List<RecurringRule> recurringRules = const [],
  List<GoalWithProgress> activeGoals = const [],
}) {
  final today = DateTime(todayLocal.year, todayLocal.month, todayLocal.day);
  final bool hasIncomeSchedule = nextPayDate != null;

  final DateTime targetDate;
  final int daysUntilPay;

  if (hasIncomeSchedule) {
    targetDate = DateTime(nextPayDate.year, nextPayDate.month, nextPayDate.day);
    daysUntilPay = max(0, targetDate.difference(today).inDays);
  } else {
    targetDate = DateTime(today.year, today.month + 1, 0);
    daysUntilPay = max(0, targetDate.difference(today).inDays);
  }

  // 1. Recurrentes pendientes hasta el próximo cobro (solo gastos activos)
  int pendingRecurring = 0;
  for (final rule in recurringRules) {
    if (!rule.active || rule.type != TxType.expense) continue;
    final due = DateTime(
      rule.nextDueDate.year,
      rule.nextDueDate.month,
      rule.nextDueDate.day,
    );

    // Debe vencer desde hoy hasta la fecha de corte
    final bool isDueBeforeCutoff;
    if (hasIncomeSchedule) {
      // Hasta antes del cobro (el cobro abre el nuevo período)
      isDueBeforeCutoff = !due.isBefore(today) && due.isBefore(targetDate);
    } else {
      // Sin esquema de cobro: hasta el fin de mes inclusive
      isDueBeforeCutoff = !due.isBefore(today) && !due.isAfter(targetDate);
    }

    if (isDueBeforeCutoff) {
      pendingRecurring += rule.amount;
    }
  }

  // 2. Aporte mensual necesario de metas con fecha prorrateado a esos días
  int proratedGoals = 0;
  for (final item in activeGoals) {
    if (item.goal.archived || item.progress.isCompleted) continue;
    if (item.goal.targetDate == null) continue;

    final reqPace = item.progress.requiredMonthlyPace;
    if (reqPace != null && reqPace > 0) {
      // 30.4375 días promedio por mes (constante estándar usada en goal_progress.dart)
      final prorated = (reqPace / 30.4375 * daysUntilPay).round();
      proratedGoals += prorated;
    }
  }

  // 3. Cálculo final
  final amount = calculateSafeToSpend(
    remaining: remaining,
    pendingRecurring: pendingRecurring,
    proratedGoals: proratedGoals,
    daysUntilPay: daysUntilPay,
  );

  return SafeToSpend(
    amount: amount,
    quedan: remaining,
    pendingRecurring: pendingRecurring,
    proratedGoals: proratedGoals,
    daysUntilPay: daysUntilPay,
    targetDate: targetDate,
    hasIncomeSchedule: hasIncomeSchedule,
  );
}

/// Provider reactivo que provee el cálculo de "Podés gastar hoy" combinando
/// ingresos, gastos, aportes a metas, reglas recurrentes y metas activas.
final safeToSpendProvider = StreamProvider<SafeToSpend>((ref) {
  final db = ref.watch(databaseProvider);
  final schedRepo = ref.watch(incomeScheduleRepositoryProvider);
  final goalsRepo = ref.watch(goalsRepositoryProvider);

  return db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          db.transactions,
          db.goals,
          db.goalContributions,
          db.recurringRules,
          db.incomeSchedules,
          db.salaryDeductions,
        },
      )
      .watch()
      .asyncMap((_) async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final sched =
            await (db.select(db.incomeSchedules)
                  ..where((t) => t.effectiveFrom.isSmallerOrEqualValue(today))
                  ..orderBy([(t) => OrderingTerm.desc(t.effectiveFrom)])
                  ..limit(1))
                .getSingleOrNull();

        final recurring = await (db.select(
          db.recurringRules,
        )..where((r) => r.active.equals(true))).get();

        // Metas activas con progreso
        final activeGoalsList =
            await (db.select(db.goals)
                  ..where((g) => g.archived.equals(false))
                  ..orderBy([(g) => OrderingTerm.asc(g.createdAt)]))
                .get();
        final allContributions = await db.select(db.goalContributions).get();
        final contribsByGoal = <String, List<GoalContribution>>{};
        for (final c in allContributions) {
          contribsByGoal.putIfAbsent(c.goalId, () => []).add(c);
        }
        final activeGoals = activeGoalsList.map((g) {
          final contribs = contribsByGoal[g.id] ?? const [];
          final progress = calculateGoalProgress(
            goal: g,
            contributions: contribs,
            now: now,
          );
          return GoalWithProgress(
            goal: g,
            progress: progress,
            contributions: contribs,
          );
        }).toList();

        if (sched == null) {
          final effectivePeriod = periodFor(DateTime(now.year, now.month, 1));
          final sumAmount = db.transactions.amount.sum();
          final incRow =
              await (db.selectOnly(db.transactions)
                    ..addColumns([sumAmount])
                    ..where(
                      db.transactions.deletedAt.isNull() &
                          db.transactions.type.equalsValue(TxType.income) &
                          db.transactions.occurredAt.isBiggerOrEqualValue(
                            effectivePeriod.startUtc,
                          ) &
                          db.transactions.occurredAt.isSmallerThanValue(
                            effectivePeriod.endUtc,
                          ),
                    ))
                  .getSingle();
          final monthIncome = incRow.read(sumAmount) ?? 0;

          final expRow =
              await (db.selectOnly(db.transactions)
                    ..addColumns([sumAmount])
                    ..where(
                      db.transactions.deletedAt.isNull() &
                          db.transactions.type.equalsValue(TxType.expense) &
                          db.transactions.occurredAt.isBiggerOrEqualValue(
                            effectivePeriod.startUtc,
                          ) &
                          db.transactions.occurredAt.isSmallerThanValue(
                            effectivePeriod.endUtc,
                          ),
                    ))
                  .getSingle();
          final monthExpense = expRow.read(sumAmount) ?? 0;

          final monthContribs = await goalsRepo.getContributionsTotalSince(
            DateTime(now.year, now.month, 1),
          );

          final remaining = monthIncome - monthExpense - monthContribs;
          return safeToSpendToday(
            todayLocal: today,
            remaining: remaining,
            nextPayDate: null,
            recurringRules: recurring,
            activeGoals: activeGoals,
          );
        } else {
          final payDays = parsePayDays(sched.payDays);
          final rules = parsePayDayRules(sched.payDayRules, payDays);
          final prevWindow = previousPayWindow(today, payDays, rules);
          final nextWin = nextPayWindow(today, payDays, rules);

          DateTime periodStart =
              prevWindow?.earliest ?? DateTime(now.year, now.month, 1);

          final salaryTx =
              await (db.select(db.transactions)
                    ..where((t) {
                      var pred =
                          t.deletedAt.isNull() &
                          t.type.equalsValue(TxType.income) &
                          (t.source.equalsValue(TxSource.incomeSchedule) |
                              t.categoryId.equals(sched.categoryId));
                      final endUtc = dayRangeUtc(today).endUtc;
                      pred = pred & t.occurredAt.isSmallerThanValue(endUtc);
                      return pred;
                    })
                    ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
                    ..limit(1))
                  .getSingleOrNull();

          DateTime? salaryDate;
          if (salaryTx != null) {
            salaryDate = salaryTx.occurredAt;
            final cleanSalary = DateTime(
              salaryDate.year,
              salaryDate.month,
              salaryDate.day,
            );
            if (prevWindow != null &&
                !cleanSalary.isBefore(prevWindow.earliest)) {
              periodStart = cleanSalary;
            }
          }

          final startUtc = dayRangeUtc(periodStart).startUtc;
          final sumAmount = db.transactions.amount.sum();

          final incRow =
              await (db.selectOnly(db.transactions)
                    ..addColumns([sumAmount])
                    ..where(
                      db.transactions.deletedAt.isNull() &
                          db.transactions.type.equalsValue(TxType.income) &
                          db.transactions.occurredAt.isBiggerOrEqualValue(
                            startUtc,
                          ),
                    ))
                  .getSingle();
          final incomeSincePay = incRow.read(sumAmount) ?? 0;

          final expRow =
              await (db.selectOnly(db.transactions)
                    ..addColumns([sumAmount])
                    ..where(
                      db.transactions.deletedAt.isNull() &
                          db.transactions.type.equalsValue(TxType.expense) &
                          db.transactions.occurredAt.isBiggerOrEqualValue(
                            startUtc,
                          ),
                    ))
                  .getSingle();
          final expenseSincePay = expRow.read(sumAmount) ?? 0;

          final contribsSincePay = await goalsRepo.getContributionsTotalSince(
            periodStart,
          );
          final deductions = await schedRepo.getDeductionsFor(sched.id);

          final pLine = periodLine(
            todayLocal: today,
            schedule: sched,
            incomeSincePay: incomeSincePay,
            expenseSincePay: expenseSincePay,
            contributionsSincePay: contribsSincePay,
            carryOver: await schedRepo.carryOverBefore(periodStart),
            lastConfirmedSalaryDate: salaryDate,
            deductions: deductions,
            expectedForPeriod: expectedAmountForPeriod(
              sched,
              today,
              deductions: deductions,
            ),
          );

          final remaining =
              pLine?.remaining ??
              (incomeSincePay - expenseSincePay - contribsSincePay);
          return safeToSpendToday(
            todayLocal: today,
            remaining: remaining,
            nextPayDate: nextWin?.earliest,
            recurringRules: recurring,
            activeGoals: activeGoals,
          );
        }
      });
});
