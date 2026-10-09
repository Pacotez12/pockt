import 'dart:math';

/// Resultado de la comparación entre el mes actual y el mes anterior.
class Comparison {
  final int current;
  final int previous;
  final double? changePct;

  const Comparison({
    required this.current,
    required this.previous,
    this.changePct,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Comparison &&
          runtimeType == other.runtimeType &&
          current == other.current &&
          previous == other.previous &&
          changePct == other.changePct;

  @override
  int get hashCode => Object.hash(current, previous, changePct);

  @override
  String toString() =>
      'Comparison(current: $current, previous: $previous, changePct: $changePct)';
}

/// Compara los gastos del mes actual desde el día 1 hasta [todayLocal.day]
/// contra el mes anterior desde el día 1 hasta el mismo día (o el último día del mes
/// anterior si este es más corto).
Comparison compareToPreviousMonth({
  required DateTime todayLocal,
  required Map<DateTime, int> dailyExpenseByLocalDay,
}) {
  final curYear = todayLocal.year;
  final curMonth = todayLocal.month;
  final curDay = todayLocal.day;

  final prevYear = curMonth == 1 ? curYear - 1 : curYear;
  final prevMonth = curMonth == 1 ? 12 : curMonth - 1;
  final daysInPrevMonth = DateTime(prevYear, prevMonth + 1, 0).day;
  final prevTargetDay = min(curDay, daysInPrevMonth);

  // Normalizar mapa por fecha Y-M-D para evitar desfases de hora/minuto
  final normalizedMap = <(int, int, int), int>{};
  for (final entry in dailyExpenseByLocalDay.entries) {
    final key = (entry.key.year, entry.key.month, entry.key.day);
    normalizedMap[key] = (normalizedMap[key] ?? 0) + entry.value;
  }

  var currentTotal = 0;
  for (var d = 1; d <= curDay; d++) {
    currentTotal += normalizedMap[(curYear, curMonth, d)] ?? 0;
  }

  var previousTotal = 0;
  for (var d = 1; d <= prevTargetDay; d++) {
    previousTotal += normalizedMap[(prevYear, prevMonth, d)] ?? 0;
  }

  final double? changePct = previousTotal == 0
      ? null
      : ((currentTotal - previousTotal) / previousTotal) * 100.0;

  return Comparison(
    current: currentTotal,
    previous: previousTotal,
    changePct: changePct,
  );
}
