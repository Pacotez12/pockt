import 'package:timezone/timezone.dart' as tz;

const kZone = 'America/Asuncion';

tz.Location get _asuncionLocation => tz.getLocation(kZone);

DateTime toLocal(DateTime utc) {
  return tz.TZDateTime.from(utc, _asuncionLocation);
}

({DateTime startUtc, DateTime endUtc}) monthRangeUtc(int year, int month) {
  final loc = _asuncionLocation;
  final startLocal = tz.TZDateTime(loc, year, month, 1, 0, 0);
  final nextMonth = month == 12 ? 1 : month + 1;
  final nextYear = month == 12 ? year + 1 : year;
  final endLocal = tz.TZDateTime(loc, nextYear, nextMonth, 1, 0, 0);
  return (startUtc: startLocal.toUtc(), endUtc: endLocal.toUtc());
}

({DateTime startUtc, DateTime endUtc}) dayRangeUtc(DateTime localDay) {
  final loc = _asuncionLocation;
  final startLocal = tz.TZDateTime(loc, localDay.year, localDay.month, localDay.day, 0, 0);
  final endLocal = tz.TZDateTime(loc, localDay.year, localDay.month, localDay.day + 1, 0, 0);
  return (startUtc: startLocal.toUtc(), endUtc: endLocal.toUtc());
}
