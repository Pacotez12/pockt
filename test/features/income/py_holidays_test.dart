import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/income/domain/py_holidays.dart';

void main() {
  group('py_holidays', () {
    test('feriados fijos de Paraguay', () {
      // 1/1 Año Nuevo
      expect(isPyHoliday(DateTime(2026, 1, 1)), isTrue);
      // 1/3 Día de los Héroes
      expect(isPyHoliday(DateTime(2026, 3, 1)), isTrue);
      // 1/5 Día del Trabajador
      expect(isPyHoliday(DateTime(2026, 5, 1)), isTrue);
      // 14/5 y 15/5 Día de la Independencia
      expect(isPyHoliday(DateTime(2026, 5, 14)), isTrue);
      expect(isPyHoliday(DateTime(2026, 5, 15)), isTrue);
      // 12/6 Paz del Chaco
      expect(isPyHoliday(DateTime(2026, 6, 12)), isTrue);
      // 15/8 Fundación de Asunción
      expect(isPyHoliday(DateTime(2026, 8, 15)), isTrue);
      // 29/9 Victoria de Boquerón
      expect(isPyHoliday(DateTime(2026, 9, 29)), isTrue);
      // 8/12 Caacupé
      expect(isPyHoliday(DateTime(2026, 12, 8)), isTrue);
      // 25/12 Navidad
      expect(isPyHoliday(DateTime(2026, 12, 25)), isTrue);

      // Día hábil cualquiera no es feriado
      expect(isPyHoliday(DateTime(2026, 10, 9)), isFalse);
    });

    test('Jueves y Viernes Santo calculados con algoritmo de Pascua (Meeus)', () {
      // En 2026: Pascua es 5 de abril
      // Jueves Santo: 2 de abril
      // Viernes Santo: 3 de abril
      expect(isPyHoliday(DateTime(2026, 4, 2)), isTrue);
      expect(isPyHoliday(DateTime(2026, 4, 3)), isTrue);
      expect(isPyHoliday(DateTime(2026, 4, 4)), isFalse);

      // En 2027: Pascua es 28 de marzo
      // Jueves Santo: 25 de marzo
      // Viernes Santo: 26 de marzo
      expect(isPyHoliday(DateTime(2027, 3, 25)), isTrue);
      expect(isPyHoliday(DateTime(2027, 3, 26)), isTrue);
    });

    test('Viernes Santo 2027 (26/3) no es hábil', () {
      expect(isBusinessDay(DateTime(2027, 3, 26)), isFalse);
    });

    test('isBusinessDay descarta fines de semana y feriados', () {
      // 10/10/2026 es sábado -> no hábil
      expect(isBusinessDay(DateTime(2026, 10, 10)), isFalse);
      // 11/10/2026 es domingo -> no hábil
      expect(isBusinessDay(DateTime(2026, 10, 11)), isFalse);
      // 8/12/2026 es martes feriado -> no hábil
      expect(isBusinessDay(DateTime(2026, 12, 8)), isFalse);
      // 9/10/2026 es viernes normal -> hábil
      expect(isBusinessDay(DateTime(2026, 10, 9)), isTrue);
      // 12/10/2026 es lunes normal -> hábil
      expect(isBusinessDay(DateTime(2026, 10, 12)), isTrue);
    });
  });
}
