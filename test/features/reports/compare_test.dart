import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/reports/domain/compare.dart';

void main() {
  group('compareToPreviousMonth', () {
    test('comparación el 31/03 contra febrero (28 días) compara 1-31/03 con 1-28/02', () {
      final dailyMap = <DateTime, int>{};

      // Marzo (días 1 a 31): 10.000 por día = 310.000
      for (var d = 1; d <= 31; d++) {
        dailyMap[DateTime(2026, 3, d)] = 10000;
      }

      // Febrero (días 1 a 28): 10.000 por día = 280.000
      for (var d = 1; d <= 28; d++) {
        dailyMap[DateTime(2026, 2, d)] = 10000;
      }

      final comp = compareToPreviousMonth(
        todayLocal: DateTime(2026, 3, 31),
        dailyExpenseByLocalDay: dailyMap,
      );

      expect(comp.current, equals(310000));
      expect(comp.previous, equals(280000));
      expect(comp.changePct, isNotNull);
      // (310000 - 280000) / 280000 * 100 = 30000 / 2800 = 10.714...%
      expect(comp.changePct!, closeTo(10.71, 0.01));
    });

    test('previous == 0 -> changePct == null', () {
      final dailyMap = <DateTime, int>{
        DateTime(2026, 10, 5): 50000,
      };

      final comp = compareToPreviousMonth(
        todayLocal: DateTime(2026, 10, 15),
        dailyExpenseByLocalDay: dailyMap,
      );

      expect(comp.current, equals(50000));
      expect(comp.previous, equals(0));
      expect(comp.changePct, isNull);
    });

    test('este mes gastaste 12 % más que el mes anterior a esta altura', () {
      final dailyMap = <DateTime, int>{
        DateTime(2026, 10, 5): 1120000,
        DateTime(2026, 9, 5): 1000000,
      };

      final comp = compareToPreviousMonth(
        todayLocal: DateTime(2026, 10, 15),
        dailyExpenseByLocalDay: dailyMap,
      );

      expect(comp.current, equals(1120000));
      expect(comp.previous, equals(1000000));
      expect(comp.changePct, closeTo(12.0, 0.001));
    });

    test('enero compara contra diciembre del año anterior', () {
      final dailyMap = <DateTime, int>{
        DateTime(2026, 1, 5): 100000,
        DateTime(2025, 12, 5): 100000,
        DateTime(2025, 12, 25): 999999, // día posterior al 10, no debe incluirse
      };

      final comp = compareToPreviousMonth(
        todayLocal: DateTime(2026, 1, 10),
        dailyExpenseByLocalDay: dailyMap,
      );

      expect(comp.current, equals(100000));
      expect(comp.previous, equals(100000));
      expect(comp.changePct, closeTo(0.0, 0.001));
    });
  });
}
