import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/format/dates.dart';

void main() {
  // Jueves 8 de octubre de 2026, 15:00.
  final now = DateTime(2026, 10, 8, 15, 0);

  group('formatTxWhen', () {
    test('hoy muestra "Hoy · HH:mm"', () {
      expect(formatTxWhen(DateTime(2026, 10, 8, 14, 32), now), 'Hoy · 14:32');
    });

    test('ayer muestra "Ayer · HH:mm" con cero a la izquierda', () {
      expect(formatTxWhen(DateTime(2026, 10, 7, 9, 3), now), 'Ayer · 09:03');
    });

    test('otro día de la misma semana muestra día abreviado, número y mes', () {
      expect(formatTxWhen(DateTime(2026, 10, 5, 19, 40), now), 'Lun 5 oct · 19:40');
    });

    test('otro mes', () {
      expect(formatTxWhen(DateTime(2026, 9, 30, 8, 5), now), 'Mié 30 sep · 08:05');
    });

    test('otro año agrega el año', () {
      expect(formatTxWhen(DateTime(2025, 10, 6, 19, 40), now), 'Lun 6 oct 2025 · 19:40');
    });
  });

  group('formatLongDay', () {
    test('fecha larga en español con mayúscula inicial', () {
      expect(formatLongDay(DateTime(2026, 10, 17)), 'Sábado 17 de octubre');
      expect(formatLongDay(DateTime(2026, 10, 16)), 'Viernes 16 de octubre');
    });
  });

  group('formatDayHeader', () {
    test('Hoy, Ayer y luego fecha larga', () {
      expect(formatDayHeader(DateTime(2026, 10, 8), now), 'Hoy');
      expect(formatDayHeader(DateTime(2026, 10, 7), now), 'Ayer');
      expect(formatDayHeader(DateTime(2026, 10, 5), now), 'Lunes 5 de octubre');
      expect(formatDayHeader(DateTime(2025, 12, 31), now), 'Miércoles 31 de diciembre de 2025');
    });
  });
}
