/// Modo de cobro: quincenal o mensual.
enum PayMode { biweekly, monthly }

DateTime _shiftToPreviousBusinessDay(DateTime date) {
  if (date.weekday == DateTime.saturday) {
    return DateTime(date.year, date.month, date.day - 1);
  } else if (date.weekday == DateTime.sunday) {
    return DateTime(date.year, date.month, date.day - 2);
  }
  return date;
}

/// Devuelve los días de cobro de un mes según la lista [payDays].
///
/// Reglas:
/// - `-1` representa el último día del mes.
/// - Cualquier día mayor a la cantidad de días del mes se ajusta al último día.
/// - Si [shiftToPreviousBusinessDay] es true, si un día cae en fin de semana
///   se corre al viernes anterior (sábado -> -1 día, domingo -> -2 días).
/// - El resultado está ordenado cronológicamente y sin fechas repetidas.
List<DateTime> payDaysInMonth(
  int year,
  int month,
  List<int> payDays, {
  required bool shiftToPreviousBusinessDay,
}) {
  if (payDays.isEmpty) {
    return const [];
  }

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
      date = _shiftToPreviousBusinessDay(date);
    }
    results.add(date);
  }

  final list = results.toList()..sort();
  return list;
}

/// Devuelve el primer día de cobro mayor o igual a [fromLocalDay].
///
/// Si [payDays] está vacío, devuelve `null`.
/// Busca en el mes actual y meses subsiguientes hasta encontrar el próximo cobro.
DateTime? nextPayDay(
  DateTime fromLocalDay,
  List<int> payDays, {
  required bool shiftToPreviousBusinessDay,
}) {
  if (payDays.isEmpty) {
    return null;
  }

  final from = DateTime(fromLocalDay.year, fromLocalDay.month, fromLocalDay.day);
  var y = from.year;
  var m = from.month;

  // Buscamos hasta 24 meses hacia adelante
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

/// Devuelve el último día de cobro menor o igual a [fromLocalDay].
///
/// Si [payDays] está vacío, devuelve `null`.
/// Busca en el mes actual y meses anteriores hasta encontrar el último cobro.
DateTime? previousPayDay(
  DateTime fromLocalDay,
  List<int> payDays, {
  required bool shiftToPreviousBusinessDay,
}) {
  if (payDays.isEmpty) {
    return null;
  }

  final from = DateTime(fromLocalDay.year, fromLocalDay.month, fromLocalDay.day);
  var y = from.year;
  var m = from.month;

  // Buscamos hasta 24 meses hacia atrás
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

