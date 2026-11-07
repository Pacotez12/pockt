import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/home/domain/heat_levels.dart';

void main() {
  test('heat_levels golden test', () {
    final rawCases = [
      {
        'name': 'mapa vacío devuelve vacío',
        'input': <String, int>{},
      },
      {
        'name': 'todos los días con cero o gasto negativo dan nivel 0',
        'input': {'1': 0, '2': 0, '3': -500, '4': 0},
      },
      {
        'name': 'todos los días positivos con el mismo monto dan nivel 4',
        'input': {'1': 50000, '2': 50000, '3': 50000, '4': 50000},
      },
      {
        'name': 'distribución uniforme de 4 montos da niveles 1, 2, 3, 4',
        'input': {'1': 10000, '2': 25000, '3': 50000, '4': 100000},
      },
      {
        'name': 'combinación con días en 0 y días con gastos variados',
        'input': {
          '1': 0,
          '2': 15000,
          '3': 0,
          '4': 40000,
          '5': 80000,
          '6': 120000,
          '7': 0,
          '8': 250000,
        },
      },
      {
        'name': 'valores repetidos (empates en rangos)',
        'input': {
          '1': 20000,
          '2': 20000,
          '3': 50000,
          '4': 50000,
          '5': 100000,
          '6': 200000,
        },
      },
      {
        'name': 'un solo día positivo da nivel 4',
        'input': {'1': 0, '2': 100000, '3': 0},
      },
    ];

    final goldenFile = File('shared/golden/heat_levels.json');
    if (!goldenFile.existsSync()) {
      final cases = <Map<String, dynamic>>[];
      for (final rc in rawCases) {
        final rawMap = rc['input'] as Map<String, dynamic>;
        final dailyTotals = <int, int>{};
        for (final e in rawMap.entries) {
          dailyTotals[int.parse(e.key)] = e.value as int;
        }

        final levels = heatLevels(dailyTotals);
        final expected = <String, int>{};
        for (final e in levels.entries) {
          expected[e.key.toString()] = e.value;
        }

        cases.add({
          'name': rc['name'],
          'input': rc['input'],
          'expected': expected,
        });
      }
      goldenFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'cases': cases}));
    }

    final data = jsonDecode(goldenFile.readAsStringSync()) as Map<String, dynamic>;
    final cases = data['cases'] as List<dynamic>;
    expect(cases.length, greaterThanOrEqualTo(6));

    for (final c in cases) {
      final name = c['name'] as String;
      final rawMap = c['input'] as Map<String, dynamic>;
      final dailyTotals = <int, int>{};
      for (final e in rawMap.entries) {
        dailyTotals[int.parse(e.key)] = e.value as int;
      }

      final actual = heatLevels(dailyTotals);
      final expectedMap = c['expected'] as Map<String, dynamic>;

      expect(actual.length, equals(expectedMap.length), reason: '$name: length');
      for (final e in actual.entries) {
        expect(e.value, equals(expectedMap[e.key.toString()]), reason: '$name day ${e.key}');
      }
    }
  });
}
