import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/budgets/domain/budget_status.dart';

void main() {
  test('budget_status golden test', () {
    final rawCases = [
      {
        'name': 'gasto normal dentro del presupuesto (nivel ok)',
        'input': {'spent': 300000, 'limit': 1000000},
      },
      {
        'name': 'gasto exactamente en umbral de advertencia 80% (nivel warning)',
        'input': {'spent': 800000, 'limit': 1000000},
      },
      {
        'name': 'gasto entre 80% y 100% (nivel warning)',
        'input': {'spent': 950000, 'limit': 1000000},
      },
      {
        'name': 'gasto exactamente en el límite 100% (nivel over)',
        'input': {'spent': 1000000, 'limit': 1000000},
      },
      {
        'name': 'gasto excedido por encima del límite (nivel over)',
        'input': {'spent': 1400000, 'limit': 1000000},
      },
      {
        'name': 'presupuesto en 0 sin gastos (límite 0 y gasto 0)',
        'input': {'spent': 0, 'limit': 0},
      },
      {
        'name': 'presupuesto en 0 con gastos (límite 0 y gasto > 0)',
        'input': {'spent': 150000, 'limit': 0},
      },
      {
        'name': 'umbrales personalizados (warningRatio 0.7, overRatio 0.9)',
        'input': {
          'spent': 750000,
          'limit': 1000000,
          'warningRatio': 0.7,
          'overRatio': 0.9,
        },
      },
    ];

    final goldenFile = File('shared/golden/budget_status.json');
    if (!goldenFile.existsSync()) {
      final cases = <Map<String, dynamic>>[];
      for (final rc in rawCases) {
        final inp = rc['input'] as Map<String, dynamic>;
        final spent = inp['spent'] as int;
        final limit = inp['limit'] as int;
        final wRatio = (inp['warningRatio'] as num?)?.toDouble() ?? 0.8;
        final oRatio = (inp['overRatio'] as num?)?.toDouble() ?? 1.0;

        final status = budgetStatus(
          spent,
          limit,
          warningRatio: wRatio,
          overRatio: oRatio,
        );

        cases.add({
          'name': rc['name'],
          'input': rc['input'],
          'expected': {
            'level': status.level.name,
            'ratio': (status.ratio * 1000).round() / 1000,
            'remaining': status.remaining,
          },
        });
      }
      goldenFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'cases': cases}));
    }

    final data = jsonDecode(goldenFile.readAsStringSync()) as Map<String, dynamic>;
    final cases = data['cases'] as List<dynamic>;
    expect(cases.length, greaterThanOrEqualTo(6));

    for (final c in cases) {
      final name = c['name'] as String;
      final inp = c['input'] as Map<String, dynamic>;
      final spent = inp['spent'] as int;
      final limit = inp['limit'] as int;
      final wRatio = (inp['warningRatio'] as num?)?.toDouble() ?? 0.8;
      final oRatio = (inp['overRatio'] as num?)?.toDouble() ?? 1.0;

      final actual = budgetStatus(
        spent,
        limit,
        warningRatio: wRatio,
        overRatio: oRatio,
      );

      final exp = c['expected'] as Map<String, dynamic>;
      expect(actual.level.name, equals(exp['level']), reason: '$name: level');
      expect((actual.ratio * 1000).round() / 1000, equals(exp['ratio']), reason: '$name: ratio');
      expect(actual.remaining, equals(exp['remaining']), reason: '$name: remaining');
    }
  });
}
