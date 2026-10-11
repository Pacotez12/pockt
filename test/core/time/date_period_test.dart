import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/time/date_period.dart';
import 'package:pockt/features/income/domain/pay_days.dart';

void main() {
  group('periodFor con MonthStartMode.calendar', () {
    test('un día de octubre tiene período 1/10–31/10', () {
      final period = periodFor(
        DateTime(2026, 10, 5),
        mode: MonthStartMode.calendar,
      );

      expect(period.start, equals(DateTime(2026, 10, 1)));
      expect(period.end, equals(DateTime(2026, 10, 31)));
      expect(period.daysCount, equals(31));
      expect(period.contains(DateTime(2026, 10, 1)), isTrue);
      expect(period.contains(DateTime(2026, 10, 31)), isTrue);
      expect(period.contains(DateTime(2026, 9, 30)), isFalse);
      expect(period.contains(DateTime(2026, 11, 1)), isFalse);
    });

    test('por defecto el modo es calendar', () {
      final period = periodFor(DateTime(2026, 10, 5));
      expect(period.start, equals(DateTime(2026, 10, 1)));
      expect(period.end, equals(DateTime(2026, 10, 31)));
    });

    test('funciona en febrero bisiesto y no bisiesto', () {
      // 2024 fue bisiesto (29 días)
      final leap = periodFor(DateTime(2024, 2, 10));
      expect(leap.start, equals(DateTime(2024, 2, 1)));
      expect(leap.end, equals(DateTime(2024, 2, 29)));

      // 2026 no es bisiesto (28 días)
      final nonLeap = periodFor(DateTime(2026, 2, 10));
      expect(nonLeap.start, equals(DateTime(2026, 2, 1)));
      expect(nonLeap.end, equals(DateTime(2026, 2, 28)));
    });
  });

  group('periodFor con MonthStartMode.payday', () {
    test('con cobro el 30/09 el período del 05/10 es 30/09–(día anterior al cobro de octubre)', () {
      // En 2026:
      // Septiembre: 30/09 es miércoles (hábil) -> cobro fin de mes: 30/09/2026.
      // Octubre: 31/10 es sábado -> con PayDayRule.previous, cobro fin de mes: viernes 30/10/2026.
      // El día anterior al siguiente cobro de fin de mes es 29/10/2026.
      final period = periodFor(
        DateTime(2026, 10, 5),
        mode: MonthStartMode.payday,
        payDays: const [15, -1],
        payDayRules: const [PayDayRule.either, PayDayRule.previous],
      );

      expect(period.start, equals(DateTime(2026, 9, 30)));
      expect(period.end, equals(DateTime(2026, 10, 29)));
      expect(period.contains(DateTime(2026, 9, 30)), isTrue);
      expect(period.contains(DateTime(2026, 10, 5)), isTrue);
      expect(period.contains(DateTime(2026, 10, 29)), isTrue);
      expect(period.contains(DateTime(2026, 9, 29)), isFalse);
      expect(period.contains(DateTime(2026, 10, 30)), isFalse);
    });

    test('el día del cobro (30/09) pertenece al nuevo período que empieza el 30/09', () {
      final period = periodFor(
        DateTime(2026, 9, 30),
        mode: MonthStartMode.payday,
        payDays: const [15, -1],
        payDayRules: const [PayDayRule.either, PayDayRule.previous],
      );

      expect(period.start, equals(DateTime(2026, 9, 30)));
      expect(period.end, equals(DateTime(2026, 10, 29)));
    });

    test('el día del cobro de octubre (30/10) arranca el período siguiente hacia noviembre', () {
      // Noviembre 2026: 30/11 es lunes (hábil) -> cobro 30/11/2026.
      // Día anterior: 29/11/2026.
      final period = periodFor(
        DateTime(2026, 10, 30),
        mode: MonthStartMode.payday,
        payDays: const [15, -1],
        payDayRules: const [PayDayRule.either, PayDayRule.previous],
      );

      expect(period.start, equals(DateTime(2026, 10, 30)));
      expect(period.end, equals(DateTime(2026, 11, 29)));
    });

    test('si no hay esquema o payDays está vacío, cae a calendar', () {
      final period = periodFor(
        DateTime(2026, 10, 5),
        mode: MonthStartMode.payday,
        payDays: const [],
      );

      expect(period.start, equals(DateTime(2026, 10, 1)));
      expect(period.end, equals(DateTime(2026, 10, 31)));
    });
  });
}
