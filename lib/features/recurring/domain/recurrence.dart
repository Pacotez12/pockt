/// Frecuencia de recurrencia: mensual, semanal o anual.
enum RecurrenceFrequency { monthly, weekly, yearly }

/// Devuelve la siguiente fecha de ocurrencia estrictamente posterior a [afterLocalDay].
///
/// Si [frequency] es:
/// - [RecurrenceFrequency.monthly]: usa [dayOfMonth] (por defecto [afterLocalDay.day]).
///   Si [dayOfMonth] es mayor al largo del mes, se ajusta al último día del mes.
/// - [RecurrenceFrequency.weekly]: usa [dayOfWeek] (1 = lunes .. 7 = domingo; por defecto [afterLocalDay.weekday]).
/// - [RecurrenceFrequency.yearly]: usa [monthOfYear] y [dayOfMonth] (por defecto mes y día de [afterLocalDay]).
DateTime nextOccurrence(
  DateTime afterLocalDay, {
  required RecurrenceFrequency frequency,
  int? dayOfMonth,
  int? dayOfWeek,
  int? monthOfYear,
}) {
  final after = DateTime(afterLocalDay.year, afterLocalDay.month, afterLocalDay.day);

  switch (frequency) {
    case RecurrenceFrequency.weekly:
      final targetWeekday = dayOfWeek ?? after.weekday;
      var delta = targetWeekday - after.weekday;
      if (delta <= 0) {
        delta += 7;
      }
      return DateTime(after.year, after.month, after.day + delta);

    case RecurrenceFrequency.monthly:
      final targetDay = dayOfMonth ?? after.day;

      // Primero probamos en el mismo mes si todavía no pasó
      final currentMonthDays = DateTime(after.year, after.month + 1, 0).day;
      final currentClamped = targetDay.clamp(1, currentMonthDays);
      final currentCandidate = DateTime(after.year, after.month, currentClamped);
      if (currentCandidate.isAfter(after)) {
        return currentCandidate;
      }

      // Si no, avanzamos mes a mes
      var y = after.year;
      var m = after.month + 1;
      while (true) {
        if (m > 12) {
          y++;
          m = 1;
        }
        final daysInM = DateTime(y, m + 1, 0).day;
        final clamped = targetDay.clamp(1, daysInM);
        final candidate = DateTime(y, m, clamped);
        if (candidate.isAfter(after)) {
          return candidate;
        }
        m++;
      }

    case RecurrenceFrequency.yearly:
      final targetMonth = monthOfYear ?? after.month;
      final targetDay = dayOfMonth ?? after.day;

      // Primero probamos en el mismo año si todavía no pasó
      final currentYearDays = DateTime(after.year, targetMonth + 1, 0).day;
      final currentClamped = targetDay.clamp(1, currentYearDays);
      final currentCandidate = DateTime(after.year, targetMonth, currentClamped);
      if (currentCandidate.isAfter(after)) {
        return currentCandidate;
      }

      // Si no, avanzamos año a año
      var y = after.year + 1;
      while (true) {
        final daysInM = DateTime(y, targetMonth + 1, 0).day;
        final clamped = targetDay.clamp(1, daysInM);
        final candidate = DateTime(y, targetMonth, clamped);
        if (candidate.isAfter(after)) {
          return candidate;
        }
        y++;
      }
  }
}

/// Devuelve todas las fechas vencidas desde [nextDueDate] hasta [todayLocal] inclusive.
///
/// Si [nextDueDate] es posterior a [todayLocal], devuelve lista vacía.
List<DateTime> dueOccurrences(
  DateTime nextDueDate,
  DateTime todayLocal, {
  required RecurrenceFrequency frequency,
  int? dayOfMonth,
  int? dayOfWeek,
  int? monthOfYear,
}) {
  final due = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
  final today = DateTime(todayLocal.year, todayLocal.month, todayLocal.day);

  if (due.isAfter(today)) {
    return const [];
  }

  final occurrences = <DateTime>[];
  var current = due;
  while (!current.isAfter(today)) {
    occurrences.add(current);
    current = nextOccurrence(
      current,
      frequency: frequency,
      dayOfMonth: dayOfMonth,
      dayOfWeek: dayOfWeek,
      monthOfYear: monthOfYear,
    );
  }
  return occurrences;
}
