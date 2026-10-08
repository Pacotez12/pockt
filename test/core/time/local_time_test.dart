import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  test('kZone is America/Asuncion', () {
    expect(kZone, 'America/Asuncion');
  });

  test('toLocal convierte UTC a hora local de Asunción', () {
    final location = tz.getLocation(kZone);
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
}
