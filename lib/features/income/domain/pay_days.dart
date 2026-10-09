import 'dart:convert';
import 'package:pockt/features/income/domain/py_holidays.dart';

/// Helper para parsear reglas desde un JSON string o fallback.
List<PayDayRule> parsePayDayRules(String? rulesJson, List<int> payDays) {
  if (rulesJson != null && rulesJson.isNotEmpty) {
    try {
      final list = jsonDecode(rulesJson) as List;
      return list.map((e) => PayDayRule.parse(e.toString())).toList();
    } catch (_) {}
  }
  return payDays.map((d) => d == -1 ? PayDayRule.previous : PayDayRule.either).toList();
}

/// Helper para parsear payDays desde un JSON string.
List<int> parsePayDays(String payDaysJson) {
  try {
    return (jsonDecode(payDaysJson) as List)
        .map((e) => (e as num).toInt())
        .toList();
  } catch (_) {
    return const [];
  }
}

/// Modo de cobro: quincenal o mensual.
enum PayMode { biweekly, monthly }

/// Regla para determinar la fecha de cobro cuando cae en un día no hábil (fin de semana o feriado).
enum PayDayRule {
  /// Día hábil anterior.
  previous,

  /// Día hábil siguiente.
  next,

  /// Puede variar: el cobro es una ventana de rango [anterior, siguiente].
  either;

  static PayDayRule parse(String name) {
    return PayDayRule.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PayDayRule.either,
    );
  }
}

/// Ventana de cobro (un rango de fechas [earliest, latest]).
/// Si cae en día hábil o la regla no es `either`, [earliest] y [latest] coinciden.
class PayWindow {
  final DateTime earliest;
  final DateTime latest;

  const PayWindow({
    required this.earliest,
    required this.latest,
  });

  bool get isRange => earliest != latest;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayWindow &&
          runtimeType == other.runtimeType &&
          earliest == other.earliest &&
          latest == other.latest;

  @override
  int get hashCode => earliest.hashCode ^ latest.hashCode;

  @override
  String toString() =>
      isRange ? 'PayWindow($earliest - $latest)' : 'PayWindow($earliest)';
}

DateTime _findPreviousBusinessDay(DateTime date) {
  var d = date.subtract(const Duration(days: 1));
  while (!isBusinessDay(d)) {
    d = d.subtract(const Duration(days: 1));
  }
  return DateTime(d.year, d.month, d.day);
}

DateTime _findNextBusinessDay(DateTime date) {
  var d = date.add(const Duration(days: 1));
  while (!isBusinessDay(d)) {
    d = d.add(const Duration(days: 1));
  }
  return DateTime(d.year, d.month, d.day);
}

PayWindow resolvePayWindow(DateTime target, PayDayRule rule) {
  final clean = DateTime(target.year, target.month, target.day);
  if (isBusinessDay(clean)) {
    return PayWindow(earliest: clean, latest: clean);
  }

  final prev = _findPreviousBusinessDay(clean);
  final next = _findNextBusinessDay(clean);

  switch (rule) {
    case PayDayRule.previous:
      return PayWindow(earliest: prev, latest: prev);
    case PayDayRule.next:
      return PayWindow(earliest: next, latest: next);
    case PayDayRule.either:
      return PayWindow(earliest: prev, latest: next);
  }
}

/// Devuelve las ventanas de cobro de un mes según la lista [payDays] y sus [rules].
List<PayWindow> payWindowsInMonth(
  int year,
  int month,
  List<int> payDays,
  List<PayDayRule> rules,
) {
  if (payDays.isEmpty) {
    return const [];
  }

  final daysInMonth = DateTime(year, month + 1, 0).day;
  final windows = <PayWindow>[];

  for (var i = 0; i < payDays.length; i++) {
    final rawDay = payDays[i];
    final rule = (i < rules.length)
        ? rules[i]
        : (rawDay == -1 ? PayDayRule.previous : PayDayRule.either);

    final int day;
    if (rawDay == -1 || rawDay > daysInMonth) {
      day = daysInMonth;
    } else if (rawDay <= 0) {
      day = 1;
    } else {
      day = rawDay;
    }

    final targetDate = DateTime(year, month, day);
    windows.add(resolvePayWindow(targetDate, rule));
  }

  windows.sort((a, b) => a.earliest.compareTo(b.earliest));
  return windows;
}

/// Devuelve la primera ventana de cobro cuyo fin (`latest`) sea mayor o igual a [fromLocalDay].
PayWindow? nextPayWindow(
  DateTime fromLocalDay,
  List<int> payDays,
  List<PayDayRule> rules,
) {
  if (payDays.isEmpty) {
    return null;
  }

  final from = DateTime(fromLocalDay.year, fromLocalDay.month, fromLocalDay.day);
  var y = from.year;
  var m = from.month;

  for (var i = 0; i < 24; i++) {
    final windows = payWindowsInMonth(y, m, payDays, rules);
    for (final window in windows) {
      if (!window.latest.isBefore(from)) {
        return window;
      }
    }

    m++;
    if (m > 12) {
      y++;
      m = 1;
    }
  }

  return null;
}

/// Devuelve la última ventana de cobro cuyo inicio (`earliest`) sea menor o igual a [fromLocalDay].
PayWindow? previousPayWindow(
  DateTime fromLocalDay,
  List<int> payDays,
  List<PayDayRule> rules,
) {
  if (payDays.isEmpty) {
    return null;
  }

  final from = DateTime(fromLocalDay.year, fromLocalDay.month, fromLocalDay.day);
  var y = from.year;
  var m = from.month;

  for (var i = 0; i < 24; i++) {
    final windows = payWindowsInMonth(y, m, payDays, rules);
    for (final window in windows.reversed) {
      if (!window.earliest.isAfter(from)) {
        return window;
      }
    }

    m--;
    if (m < 1) {
      y--;
      m = 12;
    }
  }

  return null;
}

DateTime _legacyShift(DateTime date) {
  if (date.weekday == DateTime.saturday) {
    return DateTime(date.year, date.month, date.day - 1);
  } else if (date.weekday == DateTime.sunday) {
    return DateTime(date.year, date.month, date.day - 2);
  }
  return date;
}

/// Funciones de compatibilidad:
List<DateTime> payDaysInMonth(
  int year,
  int month,
  List<int> payDays, {
  required bool shiftToPreviousBusinessDay,
}) {
  if (payDays.isEmpty) return const [];
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final results = <DateTime>{};

  for (final rawDay in payDays) {
    final int day;
    if (rawDay == -1 || rawDay > daysInMonth) {
      day = daysInMonth;
    } else if (rawDay <= 0) {
      day = 1;
    } else {
      day = rawDay;
    }

    var date = DateTime(year, month, day);
    if (shiftToPreviousBusinessDay) {
      date = _legacyShift(date);
    }
    results.add(date);
  }

  final list = results.toList()..sort();
  return list;
}

DateTime? nextPayDay(
  DateTime fromLocalDay,
  List<int> payDays, {
  required bool shiftToPreviousBusinessDay,
}) {
  if (payDays.isEmpty) return null;
  final from = DateTime(fromLocalDay.year, fromLocalDay.month, fromLocalDay.day);
  var y = from.year;
  var m = from.month;

  for (var i = 0; i < 24; i++) {
    final daysInM = payDaysInMonth(
      y,
      m,
      payDays,
      shiftToPreviousBusinessDay: shiftToPreviousBusinessDay,
    );
    for (final payDay in daysInM) {
      if (!payDay.isBefore(from)) {
        return payDay;
      }
    }
    m++;
    if (m > 12) {
      y++;
      m = 1;
    }
  }
  return null;
}

DateTime? previousPayDay(
  DateTime fromLocalDay,
  List<int> payDays, {
  required bool shiftToPreviousBusinessDay,
}) {
  if (payDays.isEmpty) return null;
  final from = DateTime(fromLocalDay.year, fromLocalDay.month, fromLocalDay.day);
  var y = from.year;
  var m = from.month;

  for (var i = 0; i < 24; i++) {
    final daysInM = payDaysInMonth(
      y,
      m,
      payDays,
      shiftToPreviousBusinessDay: shiftToPreviousBusinessDay,
    );
    for (final payDay in daysInM.reversed) {
      if (!payDay.isAfter(from)) {
        return payDay;
      }
    }
    m--;
    if (m < 1) {
      y--;
      m = 12;
    }
  }
  return null;
}
