import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/recurring/domain/recurrence.dart';

void main() {
  group('nextOccurrence', () {
    test('mensual día 31 desde 31/1/2027 -> 28/2/2027 -> 31/3/2027', () {
      final feb = nextOccurrence(
        DateTime(2027, 1, 31),
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 31,
      );
      expect(feb, DateTime(2027, 2, 28));

      final mar = nextOccurrence(
        feb,
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 31,
      );
      expect(mar, DateTime(2027, 3, 31));
    });

    test('mensual día 15 desde 10/10/2026 -> 15/10/2026 y desde 15/10/2026 -> 15/11/2026', () {
      final oct = nextOccurrence(
        DateTime(2026, 10, 10),
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 15,
      );
      expect(oct, DateTime(2026, 10, 15));

      final nov = nextOccurrence(
        DateTime(2026, 10, 15),
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 15,
      );
      expect(nov, DateTime(2026, 11, 15));
    });

    test('semanal dayOfWeek: 1 (lunes) desde jueves 8/10/2026 -> lunes 12/10/2026', () {
      final nextMon = nextOccurrence(
        DateTime(2026, 10, 8),
        frequency: RecurrenceFrequency.weekly,
        dayOfWeek: 1,
      );
      expect(nextMon, DateTime(2026, 10, 12));
      expect(nextMon.weekday, DateTime.monday);
    });

    test('semanal dayOfWeek: 1 (lunes) desde lunes 12/10/2026 -> lunes 19/10/2026', () {
      final nextMon = nextOccurrence(
        DateTime(2026, 10, 12),
        frequency: RecurrenceFrequency.weekly,
        dayOfWeek: 1,
      );
      expect(nextMon, DateTime(2026, 10, 19));
      expect(nextMon.weekday, DateTime.monday);
    });

    test('anual 15/3 desde 15/3/2026 -> 15/3/2027', () {
      final nextYear = nextOccurrence(
        DateTime(2026, 3, 15),
        frequency: RecurrenceFrequency.yearly,
        monthOfYear: 3,
        dayOfMonth: 15,
      );
      expect(nextYear, DateTime(2027, 3, 15));
    });

    test('anual 15/3 desde 10/1/2026 -> 15/3/2026', () {
      final sameYear = nextOccurrence(
        DateTime(2026, 1, 10),
        frequency: RecurrenceFrequency.yearly,
        monthOfYear: 3,
        dayOfMonth: 15,
      );
      expect(sameYear, DateTime(2026, 3, 15));
    });

    test('anual 29/2 en año bisiesto desde 29/2/2028 -> 28/2/2029', () {
      final next = nextOccurrence(
        DateTime(2028, 2, 29),
        frequency: RecurrenceFrequency.yearly,
        monthOfYear: 2,
        dayOfMonth: 29,
      );
      expect(next, DateTime(2029, 2, 28));
    });
  });

  group('dueOccurrences', () {
    test('mensual día 5, nextDueDate 5/8, hoy 8/10 -> [5/8, 5/9, 5/10]', () {
      final occurrences = dueOccurrences(
        DateTime(2026, 8, 5),
        DateTime(2026, 10, 8),
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 5,
      );
      expect(occurrences, [
        DateTime(2026, 8, 5),
        DateTime(2026, 9, 5),
        DateTime(2026, 10, 5),
      ]);
    });

    test('nextDueDate posterior a todayLocal devuelve lista vacía', () {
      final occurrences = dueOccurrences(
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 8),
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 15,
      );
      expect(occurrences, isEmpty);
    });

    test('nextDueDate igual a todayLocal devuelve solo hoy', () {
      final occurrences = dueOccurrences(
        DateTime(2026, 10, 8),
        DateTime(2026, 10, 8),
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 8,
      );
      expect(occurrences, [DateTime(2026, 10, 8)]);
    });

    test('semanal vence cada 7 días', () {
      final occurrences = dueOccurrences(
        DateTime(2026, 10, 1), // Jueves 1
        DateTime(2026, 10, 15), // Jueves 15
        frequency: RecurrenceFrequency.weekly,
        dayOfWeek: 4,
      );
      expect(occurrences, [
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 8),
        DateTime(2026, 10, 15),
      ]);
    });
  });

  group('RecurrenceFrequency enum', () {
    test('define monthly, weekly y yearly', () {
      expect(RecurrenceFrequency.values, contains(RecurrenceFrequency.monthly));
      expect(RecurrenceFrequency.values, contains(RecurrenceFrequency.weekly));
      expect(RecurrenceFrequency.values, contains(RecurrenceFrequency.yearly));
    });
  });
}
