import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/income/domain/pay_days.dart';

/// Modo de inicio del mes para cálculos de presupuesto, totales y reportes.
enum MonthStartMode {
  /// Mes calendario: del día 1 al último día del mes.
  calendar,

  /// Desde el cobro: empieza en la fecha real del cobro de fin de mes
  /// y termina el día anterior al siguiente cobro de fin de mes.
  payday;

  static MonthStartMode parse(String? value) {
    if (value == 'payday') return MonthStartMode.payday;
    return MonthStartMode.calendar;
  }
}

/// Rango cerrado de fechas que representa un período contable (mes calendario o período entre cobros).
class DatePeriod {
  /// Primer día del período (00:00:00 local).
  final DateTime start;

  /// Último día del período (00:00:00 local, inclusive).
  final DateTime end;

  const DatePeriod({
    required this.start,
    required this.end,
  });

  /// Instante UTC de inicio del primer día (para consultas `>= startUtc`).
  DateTime get startUtc => dayRangeUtc(start).startUtc;

  /// Instante UTC del final del último día (para consultas `< endUtc`).
  DateTime get endUtc => dayRangeUtc(end).endUtc;

  /// Cantidad de días incluidos en el período.
  int get daysCount => end.difference(start).inDays + 1;

  /// Indica si [date] cae dentro del período (comparando día calendario).
  bool contains(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DatePeriod &&
          start.year == other.start.year &&
          start.month == other.start.month &&
          start.day == other.start.day &&
          end.year == other.end.year &&
          end.month == other.end.month &&
          end.day == other.end.day;

  @override
  int get hashCode =>
      Object.hash(start.year, start.month, start.day, end.year, end.month, end.day);

  @override
  String toString() =>
      'DatePeriod(${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} .. ${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')})';
}

DateTime _endOfMonthPayDay(
  int year,
  int month,
  List<int> payDays,
  List<PayDayRule> rules,
) {
  final windows = payWindowsInMonth(year, month, payDays, rules);
  if (windows.isEmpty) {
    return DateTime(year, month, DateTime(year, month + 1, 0).day);
  }
  return windows.last.earliest;
}

/// Devuelve el período correspondiente a [day] según el modo [mode] y el esquema de cobro.
///
/// Con [MonthStartMode.calendar] devuelve el mes calendario de [day] (1/M .. último/M).
/// Con [MonthStartMode.payday] devuelve el rango que empieza en la fecha real del cobro
/// de fin de mes y termina el día anterior al siguiente cobro de fin de mes.
DatePeriod periodFor(
  DateTime day, {
  MonthStartMode mode = MonthStartMode.calendar,
  IncomeSchedule? schedule,
  List<int>? payDays,
  List<PayDayRule>? payDayRules,
}) {
  final cleanDay = DateTime(day.year, day.month, day.day);

  if (mode == MonthStartMode.calendar) {
    return DatePeriod(
      start: DateTime(cleanDay.year, cleanDay.month, 1),
      end: DateTime(cleanDay.year, cleanDay.month + 1, 0),
    );
  }

  final effectivePayDays = payDays ??
      (schedule != null ? parsePayDays(schedule.payDays) : const <int>[]);
  if (effectivePayDays.isEmpty) {
    return DatePeriod(
      start: DateTime(cleanDay.year, cleanDay.month, 1),
      end: DateTime(cleanDay.year, cleanDay.month + 1, 0),
    );
  }

  final effectiveRules = payDayRules ??
      (schedule != null
          ? parsePayDayRules(schedule.payDayRules, effectivePayDays)
          : effectivePayDays
              .map((d) => d == -1 ? PayDayRule.previous : PayDayRule.either)
              .toList());

  final pCurrent = _endOfMonthPayDay(
    cleanDay.year,
    cleanDay.month,
    effectivePayDays,
    effectiveRules,
  );

  if (cleanDay.isBefore(pCurrent)) {
    final prevMonth = cleanDay.month == 1 ? 12 : cleanDay.month - 1;
    final prevYear = cleanDay.month == 1 ? cleanDay.year - 1 : cleanDay.year;
    final start = _endOfMonthPayDay(prevYear, prevMonth, effectivePayDays, effectiveRules);
    final end = pCurrent.subtract(const Duration(days: 1));
    return DatePeriod(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day),
    );
  } else {
    final nextMonth = cleanDay.month == 12 ? 1 : cleanDay.month + 1;
    final nextYear = cleanDay.month == 12 ? cleanDay.year + 1 : cleanDay.year;
    final pNext = _endOfMonthPayDay(nextYear, nextMonth, effectivePayDays, effectiveRules);
    final start = pCurrent;
    final end = pNext.subtract(const Duration(days: 1));
    return DatePeriod(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day),
    );
  }
}
