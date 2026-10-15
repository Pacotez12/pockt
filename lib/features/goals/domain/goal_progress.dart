import 'dart:math';

import 'package:pockt/core/db/app_database.dart';

/// Estado de una meta según la proyección de ritmo real vs fecha objetivo (spec §7d).
sealed class GoalStatus {
  const GoalStatus();

  const factory GoalStatus.noDate() = GoalStatusNoDate;
  const factory GoalStatus.onTrack() = GoalStatusOnTrack;
  const factory GoalStatus.late(int months) = GoalStatusLate;
}

class GoalStatusNoDate extends GoalStatus {
  const GoalStatusNoDate();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GoalStatusNoDate;

  @override
  int get hashCode => runtimeType.hashCode;
}

class GoalStatusOnTrack extends GoalStatus {
  const GoalStatusOnTrack();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GoalStatusOnTrack;

  @override
  int get hashCode => runtimeType.hashCode;
}

class GoalStatusLate extends GoalStatus {
  final int months;
  const GoalStatusLate(this.months);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalStatusLate && other.months == months);

  @override
  int get hashCode => months.hashCode;
}

/// Avance y ritmo calculado de una meta de ahorro (spec §7d).
class GoalProgress {
  final int saved;
  final double percent;
  final int remaining;
  final bool isCompleted;
  final int? requiredMonthlyPace;
  final double realDailyPace;
  final int realMonthlyPace;
  final DateTime? projectedFinishDate;
  final GoalStatus status;

  const GoalProgress({
    required this.saved,
    required this.percent,
    required this.remaining,
    required this.isCompleted,
    this.requiredMonthlyPace,
    required this.realDailyPace,
    required this.realMonthlyPace,
    this.projectedFinishDate,
    required this.status,
  });

  /// Días de atraso si se realiza un gasto de [amount] (spec §7d: monto ÷ ritmo diario real; null sin ritmo).
  int? delayDaysFor(int amount) {
    if (isCompleted || remaining <= 0) return 0;
    if (realDailyPace <= 0) return null;
    return (amount / realDailyPace).round();
  }
}

/// Calcula el avance de una meta a partir de sus aportes registrados.
GoalProgress calculateGoalProgress({
  required Goal goal,
  required List<GoalContribution> contributions,
  DateTime? now,
}) {
  final currentNow = now ?? DateTime.now();

  // Ahorrado = suma de aportes (los retiros son montos negativos)
  final saved = contributions.fold<int>(0, (sum, c) => sum + c.amount);
  final remaining = max(0, goal.targetAmount - saved);
  final isCompleted = goal.targetAmount > 0 ? saved >= goal.targetAmount : true;
  final double percent = goal.targetAmount > 0
      ? (saved / goal.targetAmount).clamp(0.0, 1.0)
      : 1.0;

  // Ritmo necesario por mes (si tiene fecha objetivo)
  int? requiredMonthlyPace;
  if (goal.targetDate != null) {
    if (remaining <= 0) {
      requiredMonthlyPace = 0;
    } else {
      final daysLeft = goal.targetDate!.difference(currentNow).inDays;
      if (daysLeft <= 0) {
        requiredMonthlyPace = remaining;
      } else {
        final monthsLeft = max(1.0, daysLeft / 30.4375);
        requiredMonthlyPace = (remaining / monthsLeft).ceil();
      }
    }
  }

  // Ritmo real: promedio de aportes de los últimos 90 días
  final windowStart = currentNow.subtract(const Duration(days: 90));
  final recentContributions = contributions.where(
    (c) => !c.date.isBefore(windowStart) && !c.date.isAfter(currentNow),
  );
  final netInWindow = recentContributions.fold<int>(
    0,
    (sum, c) => sum + c.amount,
  );

  final double realDailyPace = netInWindow > 0 ? netInWindow / 90.0 : 0.0;
  final int realMonthlyPace = (realDailyPace * 30.4375).round();

  // Fecha proyectada de finalización
  DateTime? projectedFinishDate;
  if (remaining <= 0) {
    projectedFinishDate = currentNow;
  } else if (realDailyPace > 0) {
    final daysNeeded = (remaining / realDailyPace).ceil();
    projectedFinishDate = currentNow.add(Duration(days: daysNeeded));
  }

  // Estado
  final GoalStatus status;
  if (goal.targetDate == null) {
    status = const GoalStatus.noDate();
  } else if (remaining <= 0) {
    status = const GoalStatus.onTrack();
  } else if (realDailyPace <= 0) {
    final target = goal.targetDate!;
    final daysDiff = currentNow.difference(target).inDays;
    final months = daysDiff > 0 ? max(1, (daysDiff / 30.4375).ceil()) : 1;
    status = GoalStatus.late(months);
  } else {
    if (projectedFinishDate != null &&
        !projectedFinishDate.isAfter(goal.targetDate!)) {
      status = const GoalStatus.onTrack();
    } else {
      final daysLate = projectedFinishDate != null
          ? projectedFinishDate.difference(goal.targetDate!).inDays
          : 30;
      final months = max(1, (daysLate / 30.4375).ceil());
      status = GoalStatus.late(months);
    }
  }

  return GoalProgress(
    saved: saved,
    percent: percent,
    remaining: remaining,
    isCompleted: isCompleted,
    requiredMonthlyPace: requiredMonthlyPace,
    realDailyPace: realDailyPace,
    realMonthlyPace: realMonthlyPace,
    projectedFinishDate: projectedFinishDate,
    status: status,
  );
}
