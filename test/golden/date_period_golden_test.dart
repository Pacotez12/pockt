import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/time/date_period.dart';
import 'package:pockt/features/income/domain/pay_days.dart';

void main() {
  test('date_period golden test matches app calculation', () {
    final file = File('shared/golden/date_period.json');
    expect(file.existsSync(), isTrue, reason: 'shared/golden/date_period.json debe existir');

    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final cases = data['cases'] as List<dynamic>;
    expect(cases.length, greaterThanOrEqualTo(6), reason: 'Al menos 6 casos');

    for (final c in cases) {
      final name = c['name'] as String;
      final input = c['input'] as Map<String, dynamic>;
      final expected = c['expected'] as Map<String, dynamic>;

      final dayParts = (input['day'] as String).split('-').map(int.parse).toList();
      final day = DateTime(dayParts[0], dayParts[1], dayParts[2]);
      final mode = MonthStartMode.parse(input['mode'] as String?);
      final rawPayDays = (input['payDays'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList();
      final rawRules = (input['payDayRules'] as List<dynamic>?)?.map((e) => PayDayRule.parse(e.toString())).toList();

      final actual = periodFor(
        day,
        mode: mode,
        payDays: rawPayDays,
        payDayRules: rawRules,
      );

      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      expect(fmt(actual.start), equals(expected['start']), reason: '$name: start mismatch');
      expect(fmt(actual.end), equals(expected['end']), reason: '$name: end mismatch');
      expect(actual.daysCount, equals(expected['daysCount']), reason: '$name: daysCount mismatch');
    }
  });
}
