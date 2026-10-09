import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/income/domain/pay_days.dart';

void main() {
  group('payDaysInMonth', () {
    test('15 y fin de mes en mes de 31 días sin corrimiento', () {
      final days = payDaysInMonth(
        2026,
        10,
        [15, -1],
        shiftToPreviousBusinessDay: false,
      );
      expect(days, [
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 31),
      ]);
    });

    test('febrero no bisiesto (2027) y bisiesto (2028) con [15, -1]', () {
      final days2027 = payDaysInMonth(
        2027,
        2,
        [15, -1],
        shiftToPreviousBusinessDay: false,
      );
      expect(days2027, [
        DateTime(2027, 2, 15),
        DateTime(2027, 2, 28),
      ]);

      final days2028 = payDaysInMonth(
        2028,
        2,
        [15, -1],
        shiftToPreviousBusinessDay: false,
      );
      expect(days2028, [
        DateTime(2028, 2, 15),
        DateTime(2028, 2, 29),
      ]);
    });

    test('corrimiento a día hábil anterior en fin de semana', () {
      // 15/11/2026 es domingo -> viernes 13/11
      final nov15 = payDaysInMonth(
        2026,
        11,
        [15],
        shiftToPreviousBusinessDay: true,
      );
      expect(nov15, [DateTime(2026, 11, 13)]);

      // 15/8/2026 es sábado -> viernes 14/8
      final ago15 = payDaysInMonth(
        2026,
        8,
        [15],
        shiftToPreviousBusinessDay: true,
      );
      expect(ago15, [DateTime(2026, 8, 14)]);

      // 31/1/2027 es domingo -> viernes 29/1
      final janEnd = payDaysInMonth(
        2027,
        1,
        [-1],
        shiftToPreviousBusinessDay: true,
      );
      expect(janEnd, [DateTime(2027, 1, 29)]);

      // 31/10/2026 es sábado -> viernes 30/10
      final octEnd = payDaysInMonth(
        2026,
        10,
        [15, -1],
        shiftToPreviousBusinessDay: true,
      );
      expect(octEnd, [
        DateTime(2026, 10, 15), // Jueves 15 no cambia
        DateTime(2026, 10, 30), // Sábado 31 corre a viernes 30
      ]);
    });

    test('día mayor al largo del mes se ajusta al último día', () {
      // Noviembre tiene 30 días, día 31 debe ser 30
      final days = payDaysInMonth(
        2026,
        11,
        [31],
        shiftToPreviousBusinessDay: false,
      );
      expect(days, [DateTime(2026, 11, 30)]);
    });

    test('resultado ordenado y sin repetidos', () {
      final days = payDaysInMonth(
        2026,
        10,
        [-1, 31, 15, 15],
        shiftToPreviousBusinessDay: false,
      );
      expect(days, [
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 31),
      ]);
    });

    test('lista de días vacía devuelve lista vacía', () {
      final days = payDaysInMonth(
        2026,
        10,
        [],
        shiftToPreviousBusinessDay: false,
      );
      expect(days, isEmpty);
    });
  });

  group('nextPayDay', () {
    test('sin corrimiento: 14/10 -> 15/10 y 16/10 -> 31/10', () {
      final next14 = nextPayDay(
        DateTime(2026, 10, 14),
        [15, -1],
        shiftToPreviousBusinessDay: false,
      );
      expect(next14, DateTime(2026, 10, 15));

      final next15 = nextPayDay(
        DateTime(2026, 10, 15),
        [15, -1],
        shiftToPreviousBusinessDay: false,
      );
      expect(next15, DateTime(2026, 10, 15));

      final next16 = nextPayDay(
        DateTime(2026, 10, 16),
        [15, -1],
        shiftToPreviousBusinessDay: false,
      );
      expect(next16, DateTime(2026, 10, 31));
    });

    test('con corrimiento: 16/10 -> viernes 30/10 y 1/11 -> viernes 13/11', () {
      // 31/10/2026 es sábado -> cobro viernes 30/10
      final next16 = nextPayDay(
        DateTime(2026, 10, 16),
        [15, -1],
        shiftToPreviousBusinessDay: true,
      );
      expect(next16, DateTime(2026, 10, 30));

      // 15/11/2026 es domingo -> cobro viernes 13/11
      final nextNov = nextPayDay(
        DateTime(2026, 11, 1),
        [15, -1],
        shiftToPreviousBusinessDay: true,
      );
      expect(nextNov, DateTime(2026, 11, 13));
    });

    test('pasa al mes siguiente cuando ya pasaron todos los cobros del mes', () {
      final nextAfterOct = nextPayDay(
        DateTime(2026, 10, 31),
        [15, -1],
        shiftToPreviousBusinessDay: true,
      );
      expect(nextAfterOct, DateTime(2026, 11, 13));
    });

    test('payDays vacío devuelve null', () {
      final next = nextPayDay(
        DateTime(2026, 10, 14),
        [],
        shiftToPreviousBusinessDay: false,
      );
      expect(next, isNull);
    });
  });

  group('previousPayDay', () {
    test('payDays vacío devuelve null', () {
      final prev = previousPayDay(
        DateTime(2026, 10, 14),
        [],
        shiftToPreviousBusinessDay: false,
      );
      expect(prev, isNull);
    });

    test('el mismo día de cobro devuelve hoy: 15/10 -> 15/10', () {
      final prev = previousPayDay(
        DateTime(2026, 10, 15),
        [15, -1],
        shiftToPreviousBusinessDay: false,
      );
      expect(prev, DateTime(2026, 10, 15));
    });

    test('después del primer cobro del mes: 16/10 con [15, -1] -> 15/10', () {
      final prev = previousPayDay(
        DateTime(2026, 10, 16),
        [15, -1],
        shiftToPreviousBusinessDay: false,
      );
      expect(prev, DateTime(2026, 10, 15));
    });

    test('antes del primer cobro del mes mira el mes anterior: 9/10 con [15, -1] -> 30/09', () {
      final prev = previousPayDay(
        DateTime(2026, 10, 9),
        [15, -1],
        shiftToPreviousBusinessDay: false,
      );
      expect(prev, DateTime(2026, 9, 30));
    });

    test('con corrimiento: 31/10/2026 sábado -> viernes 30/10/2026', () {
      final prev = previousPayDay(
        DateTime(2026, 10, 31),
        [15, -1],
        shiftToPreviousBusinessDay: true,
      );
      expect(prev, DateTime(2026, 10, 30));
    });

    test('en enero mirando diciembre: 5/1/2027 con [15, -1] -> 31/12/2026', () {
      final prev = previousPayDay(
        DateTime(2027, 1, 5),
        [15, -1],
        shiftToPreviousBusinessDay: false,
      );
      expect(prev, DateTime(2026, 12, 31));
    });
  });

  group('PayMode enum', () {
    test('define biweekly y monthly', () {
      expect(PayMode.values, contains(PayMode.biweekly));
      expect(PayMode.values, contains(PayMode.monthly));
    });
  });
}
