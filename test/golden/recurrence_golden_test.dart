import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/recurring/domain/recurrence.dart';

void main() {
  test('recurrence golden test', () {
    final rawCases = [
      {
        'name': 'mensual día 10 cuando hoy es 5 del mismo mes',
        'input': {
          'after': '2026-10-05',
          'frequency': 'monthly',
          'dayOfMonth': 10,
        },
      },
      {
        'name': 'mensual día 10 cuando hoy es 15 del mismo mes (pasa al mes siguiente)',
        'input': {
          'after': '2026-10-15',
          'frequency': 'monthly',
          'dayOfMonth': 10,
        },
      },
      {
        'name': 'mensual día 31 en mes de 30 días se ajusta al último día (clamped)',
        'input': {
          'after': '2026-10-31',
          'frequency': 'monthly',
          'dayOfMonth': 31,
        },
      },
      {
        'name': 'mensual día 31 pasando por febrero (ajusta al 28)',
        'input': {
          'after': '2026-01-31',
          'frequency': 'monthly',
          'dayOfMonth': 31,
        },
      },
      {
        'name': 'semanal día lunes (weekday 1) hoy es viernes (weekday 5)',
        'input': {
          'after': '2026-10-09', // Viernes
          'frequency': 'weekly',
          'dayOfWeek': 1,
        },
      },
      {
        'name': 'semanal día viernes hoy es viernes (debe ser el próximo viernes)',
        'input': {
          'after': '2026-10-09', // Viernes
          'frequency': 'weekly',
          'dayOfWeek': 5,
        },
      },
      {
        'name': 'anual 15 de marzo hoy es 10 de enero (mismo año)',
        'input': {
          'after': '2026-01-10',
          'frequency': 'yearly',
          'monthOfYear': 3,
          'dayOfMonth': 15,
        },
      },
      {
        'name': 'anual 15 de marzo hoy es 20 de mayo (pasa al año siguiente)',
        'input': {
          'after': '2026-05-20',
          'frequency': 'yearly',
          'monthOfYear': 3,
          'dayOfMonth': 15,
        },
      },
      {
        'name': 'anual 29 de febrero en año no bisiesto se ajusta al 28',
        'input': {
          'after': '2024-03-01',
          'frequency': 'yearly',
          'monthOfYear': 2,
          'dayOfMonth': 29,
        },
      },
      {
        'name': 'dueOccurrences con varias ocurrencias vencidas',
        'input': {
          'type': 'dueOccurrences',
          'nextDueDate': '2026-07-15',
          'today': '2026-10-15',
          'frequency': 'monthly',
          'dayOfMonth': 15,
        },
      },
      {
        'name': 'dueOccurrences fecha futura devuelve lista vacía',
        'input': {
          'type': 'dueOccurrences',
          'nextDueDate': '2026-10-20',
          'today': '2026-10-15',
          'frequency': 'monthly',
          'dayOfMonth': 20,
        },
      },
    ];

    final goldenFile = File('shared/golden/recurrence.json');
    if (!goldenFile.existsSync()) {
      final cases = <Map<String, dynamic>>[];
      for (final rc in rawCases) {
        final inp = rc['input'] as Map<String, dynamic>;
        final isDue = inp['type'] == 'dueOccurrences';

        String fmt(DateTime d) =>
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

        final RecurrenceFrequency freq;
        switch (inp['frequency']) {
          case 'weekly':
            freq = RecurrenceFrequency.weekly;
            break;
          case 'yearly':
            freq = RecurrenceFrequency.yearly;
            break;
          case 'monthly':
          default:
            freq = RecurrenceFrequency.monthly;
            break;
        }

        if (isDue) {
          final nextDue = DateTime.parse(inp['nextDueDate']);
          final today = DateTime.parse(inp['today']);
          final list = dueOccurrences(
            nextDue,
            today,
            frequency: freq,
            dayOfMonth: inp['dayOfMonth'],
            dayOfWeek: inp['dayOfWeek'],
            monthOfYear: inp['monthOfYear'],
          );

          cases.add({
            'name': rc['name'],
            'input': rc['input'],
            'expected': {'dates': list.map(fmt).toList()},
          });
        } else {
          final after = DateTime.parse(inp['after']);
          final next = nextOccurrence(
            after,
            frequency: freq,
            dayOfMonth: inp['dayOfMonth'],
            dayOfWeek: inp['dayOfWeek'],
            monthOfYear: inp['monthOfYear'],
          );

          cases.add({
            'name': rc['name'],
            'input': rc['input'],
            'expected': {'next': fmt(next)},
          });
        }
      }
      goldenFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'cases': cases}));
    }

    final data = jsonDecode(goldenFile.readAsStringSync()) as Map<String, dynamic>;
    final cases = data['cases'] as List<dynamic>;
    expect(cases.length, greaterThanOrEqualTo(6));

    for (final c in cases) {
      final name = c['name'] as String;
      final inp = c['input'] as Map<String, dynamic>;
      final isDue = inp['type'] == 'dueOccurrences';
      final exp = c['expected'] as Map<String, dynamic>;

      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final RecurrenceFrequency freq;
      switch (inp['frequency']) {
        case 'weekly':
          freq = RecurrenceFrequency.weekly;
          break;
        case 'yearly':
          freq = RecurrenceFrequency.yearly;
          break;
        case 'monthly':
        default:
          freq = RecurrenceFrequency.monthly;
          break;
      }

      if (isDue) {
        final nextDue = DateTime.parse(inp['nextDueDate']);
        final today = DateTime.parse(inp['today']);
        final list = dueOccurrences(
          nextDue,
          today,
          frequency: freq,
          dayOfMonth: inp['dayOfMonth'],
          dayOfWeek: inp['dayOfWeek'],
          monthOfYear: inp['monthOfYear'],
        );
        expect(list.map(fmt).toList(), equals(exp['dates']), reason: '$name: dates');
      } else {
        final after = DateTime.parse(inp['after']);
        final actual = nextOccurrence(
          after,
          frequency: freq,
          dayOfMonth: inp['dayOfMonth'],
          dayOfWeek: inp['dayOfWeek'],
          monthOfYear: inp['monthOfYear'],
        );
        expect(fmt(actual), equals(exp['next']), reason: '$name: next');
      }
    }
  });
}
