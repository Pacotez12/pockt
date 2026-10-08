import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() {
    setLocalZone('America/Asuncion');
  });

  test('kFallbackZone is America/Asuncion', () {
    expect(kFallbackZone, 'America/Asuncion');
  });

  test('toLocal convierte UTC a hora local de Asunción por defecto', () {
    final location = tz.getLocation(kFallbackZone);
    final localDt = tz.TZDateTime(location, 2026, 10, 31, 23, 30);
    final utc = localDt.toUtc();
    final converted = toLocal(utc);
    expect(converted.year, 2026);
    expect(converted.month, 10);
    expect(converted.day, 31);
    expect(converted.hour, 23);
    expect(converted.minute, 30);
  });

  test('monthRangeUtc genera rango UTC con fin exclusivo', () {
    final range = monthRangeUtc(2026, 10);
    final startLocal = toLocal(range.startUtc);
    final endLocal = toLocal(range.endUtc);
    expect(startLocal.year, 2026);
    expect(startLocal.month, 10);
    expect(startLocal.day, 1);
    expect(startLocal.hour, 0);
    expect(startLocal.minute, 0);
    expect(endLocal.year, 2026);
    expect(endLocal.month, 11);
    expect(endLocal.day, 1);
    expect(endLocal.hour, 0);
    expect(endLocal.minute, 0);
  });

  test('dayRangeUtc genera rango UTC con fin exclusivo para un día local', () {
    final day = DateTime(2026, 10, 15);
    final range = dayRangeUtc(day);
    final startLocal = toLocal(range.startUtc);
    final endLocal = toLocal(range.endUtc);
    expect(startLocal.year, 2026);
    expect(startLocal.month, 10);
    expect(startLocal.day, 15);
    expect(startLocal.hour, 0);
    expect(endLocal.year, 2026);
    expect(endLocal.month, 10);
    expect(endLocal.day, 16);
    expect(endLocal.hour, 0);
  });

  test('setLocalZone con nombre inválido cae a kFallbackZone', () {
    setLocalZone('Zona/Invalida_Inexistente');
    final utc = DateTime.utc(2026, 10, 31, 23, 30);
    final local = toLocal(utc);
    final asuncion = tz.TZDateTime.from(utc, tz.getLocation(kFallbackZone));
    expect(local.hour, asuncion.hour);
    expect(local.day, asuncion.day);
  });

  test('con setLocalZone Europe/Madrid un gasto a las 23:30 hora de Madrid cuenta en su día local de Madrid', () {
    setLocalZone('Europe/Madrid');
    final madridLocation = tz.getLocation('Europe/Madrid');
    final madridLocal = tz.TZDateTime(madridLocation, 2026, 10, 31, 23, 30);
    final utc = madridLocal.toUtc();
    final converted = toLocal(utc);
    expect(converted.year, 2026);
    expect(converted.month, 10);
    expect(converted.day, 31);
    expect(converted.hour, 23);
    expect(converted.minute, 30);

    final range = dayRangeUtc(DateTime(2026, 10, 31));
    expect(utc.isAfter(range.startUtc) || utc.isAtSameMomentAs(range.startUtc), isTrue);
    expect(utc.isBefore(range.endUtc), isTrue);
  });
}
