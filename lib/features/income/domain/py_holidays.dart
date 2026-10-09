/// Feriados nacionales de la República del Paraguay y cálculo de días hábiles.
library;

/// Calcula el Domingo de Pascua para un año gregoriano usando el algoritmo de Meeus / Jones / Butcher.
DateTime easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

/// Determina si una fecha dada es un feriado nacional en Paraguay.
///
/// Feriados fijos:
/// - 1 de enero: Año Nuevo
/// - 1 de marzo: Día de los Héroes de la Patria
/// - 1 de mayo: Día del Trabajador
/// - 14 y 15 de mayo: Día de la Independencia Nacional
/// - 12 de junio: Día de la Paz del Chaco
/// - 15 de agosto: Fundación de Asunción
/// - 29 de septiembre: Victoria de Boquerón
/// - 8 de diciembre: Día de la Virgen de Caacupé
/// - 25 de diciembre: Navidad
///
/// Feriados móviles:
/// - Jueves Santo y Viernes Santo (calculados desde la Pascua).
bool isPyHoliday(DateTime day) {
  final m = day.month;
  final d = day.day;

  // Feriados fijos
  if (m == 1 && d == 1) return true;
  if (m == 3 && d == 1) return true;
  if (m == 5 && (d == 1 || d == 14 || d == 15)) return true;
  if (m == 6 && d == 12) return true;
  if (m == 8 && d == 15) return true;
  if (m == 9 && d == 29) return true;
  if (m == 12 && (d == 8 || d == 25)) return true;

  // Jueves y Viernes Santo
  final easter = easterSunday(day.year);
  final viernesSanto = easter.subtract(const Duration(days: 2));
  final juevesSanto = easter.subtract(const Duration(days: 3));

  if (m == viernesSanto.month && d == viernesSanto.day) return true;
  if (m == juevesSanto.month && d == juevesSanto.day) return true;

  return false;
}

/// Determina si una fecha es día hábil en Paraguay (lunes a viernes y no feriado nacional).
bool isBusinessDay(DateTime d) {
  if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
    return false;
  }
  return !isPyHoliday(d);
}
