/// Formatos de fecha en español (sin depender de la inicialización de `intl`).
/// Todas las funciones reciben fechas ya convertidas a la zona local.
library;

const List<String> _kWeekdaysLong = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

const List<String> _kWeekdaysShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

const List<String> _kMonthsLong = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const List<String> _kMonthsShort = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Diferencia en días calendario (independiente de la hora y del cambio de horario).
int _calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "Hoy · 14:32", "Ayer · 09:03" u otro día: "Lun 6 oct · 19:40"
/// (con el año si no es el año en curso).
String formatTxWhen(DateTime occurredLocal, DateTime nowLocal) {
  final diff = _calendarDaysBetween(occurredLocal, nowLocal);
  final time = _hhmm(occurredLocal);
  if (diff == 0) return 'Hoy · $time';
  if (diff == 1) return 'Ayer · $time';
  final weekday = _kWeekdaysShort[occurredLocal.weekday - 1];
  final month = _kMonthsShort[occurredLocal.month - 1];
  final year = occurredLocal.year == nowLocal.year ? '' : ' ${occurredLocal.year}';
  return '$weekday ${occurredLocal.day} $month$year · $time';
}

/// "Sábado 17 de octubre".
String formatLongDay(DateTime localDay) {
  final weekday = _kWeekdaysLong[localDay.weekday - 1];
  final month = _kMonthsLong[localDay.month - 1];
  return '$weekday ${localDay.day} de $month';
}

/// Encabezado de grupo por día: "Hoy", "Ayer" o la fecha larga
/// (con "de AAAA" si no es el año en curso).
String formatDayHeader(DateTime localDay, DateTime nowLocal) {
  final diff = _calendarDaysBetween(localDay, nowLocal);
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  final long = formatLongDay(localDay);
  return localDay.year == nowLocal.year ? long : '$long de ${localDay.year}';
}
