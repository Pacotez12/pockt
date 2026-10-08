import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

const kFallbackZone = 'America/Asuncion';
@Deprecated('Use kFallbackZone instead')
const kZone = kFallbackZone;

String _currentZoneName = kFallbackZone;

tz.Location get _localLocation {
  try {
    return tz.getLocation(_currentZoneName);
  } catch (_) {
    try {
      return tz.getLocation(kFallbackZone);
    } catch (_) {
      return tz.UTC;
    }
  }
}

void setLocalZone(String name) {
  try {
    tz.getLocation(name);
    _currentZoneName = name;
  } catch (_) {
    _currentZoneName = kFallbackZone;
  }
}

Future<void> initLocalZone() async {
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    setLocalZone(info.identifier);
  } catch (_) {
    setLocalZone(kFallbackZone);
  }
}

DateTime toLocal(DateTime utc) {
  return tz.TZDateTime.from(utc, _localLocation);
}

({DateTime startUtc, DateTime endUtc}) monthRangeUtc(int year, int month) {
  final loc = _localLocation;
  final startLocal = tz.TZDateTime(loc, year, month, 1, 0, 0);
  final nextMonth = month == 12 ? 1 : month + 1;
  final nextYear = month == 12 ? year + 1 : year;
  final endLocal = tz.TZDateTime(loc, nextYear, nextMonth, 1, 0, 0);
  return (startUtc: startLocal.toUtc(), endUtc: endLocal.toUtc());
}

({DateTime startUtc, DateTime endUtc}) dayRangeUtc(DateTime localDay) {
  final loc = _localLocation;
  final startLocal = tz.TZDateTime(
    loc,
    localDay.year,
    localDay.month,
    localDay.day,
    0,
    0,
  );
  final endLocal = tz.TZDateTime(
    loc,
    localDay.year,
    localDay.month,
    localDay.day + 1,
    0,
    0,
  );
  return (startUtc: startLocal.toUtc(), endUtc: endLocal.toUtc());
}

/// Combina un día local con la hora de [nowLocal]: si es hoy devuelve
/// [nowLocal]; si es otro día, ese día a la misma hora. Evita guardar
/// movimientos a las 00:00 cuando solo se eligió una fecha.
DateTime combineDayWithNow(DateTime localDay, DateTime nowLocal) {
  if (localDay.year == nowLocal.year &&
      localDay.month == nowLocal.month &&
      localDay.day == nowLocal.day) {
    return nowLocal;
  }
  return DateTime(
    localDay.year,
    localDay.month,
    localDay.day,
    nowLocal.hour,
    nowLocal.minute,
    nowLocal.second,
  );
}
