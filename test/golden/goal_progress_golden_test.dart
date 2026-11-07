import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/features/goals/domain/goal_progress.dart';

Goal _goal({
  required String id,
  required String name,
  required int targetAmount,
  DateTime? targetDate,
}) {
  return Goal(
    id: id,
    name: name,
    icon: 'target',
    targetAmount: targetAmount,
    targetDate: targetDate,
    createdAt: DateTime(2026, 1, 1),
    archived: false,
  );
}

GoalContribution _contrib({
  required String id,
  required String goalId,
  required int amount,
  required DateTime date,
}) {
  return GoalContribution(
    id: id,
    goalId: goalId,
    amount: amount,
    date: date,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test('goal_progress golden test', () {
    final now = DateTime(2026, 10, 15);

    final rawCases = [
      {
        'name': 'meta al día (onTrack) con fecha objetivo y aportes constantes',
        'goal': {
          'id': 'g1',
          'name': 'Viaje',
          'targetAmount': 10000000,
          'targetDate': '2027-10-15',
        },
        'contributions': [
          {'id': 'c1', 'goalId': 'g1', 'amount': 1000000, 'date': '2026-08-01'},
          {'id': 'c2', 'goalId': 'g1', 'amount': 1000000, 'date': '2026-09-01'},
          {'id': 'c3', 'goalId': 'g1', 'amount': 1000000, 'date': '2026-10-01'},
        ],
      },
      {
        'name': 'meta atrasada (late) ritmo menor al necesario',
        'goal': {
          'id': 'g2',
          'name': 'Fondo Emergencia',
          'targetAmount': 20000000,
          'targetDate': '2026-12-31',
        },
        'contributions': [
          {'id': 'c4', 'goalId': 'g2', 'amount': 500000, 'date': '2026-08-15'},
          {'id': 'c5', 'goalId': 'g2', 'amount': 500000, 'date': '2026-09-15'},
        ],
      },
      {
        'name': 'meta sin fecha objetivo (status noDate)',
        'goal': {
          'id': 'g3',
          'name': 'Ahorro Libre',
          'targetAmount': 5000000,
          'targetDate': null,
        },
        'contributions': [
          {'id': 'c6', 'goalId': 'g3', 'amount': 1500000, 'date': '2026-09-10'},
          {'id': 'c7', 'goalId': 'g3', 'amount': 1000000, 'date': '2026-10-05'},
        ],
      },
      {
        'name': 'meta completada (saved >= targetAmount)',
        'goal': {
          'id': 'g4',
          'name': 'Laptop',
          'targetAmount': 8000000,
          'targetDate': '2026-11-30',
        },
        'contributions': [
          {'id': 'c8', 'goalId': 'g4', 'amount': 5000000, 'date': '2026-08-01'},
          {'id': 'c9', 'goalId': 'g4', 'amount': 3500000, 'date': '2026-09-01'},
        ],
      },
      {
        'name': 'meta con retiros (aportes negativos) y sin ritmo positivo',
        'goal': {
          'id': 'g5',
          'name': 'Inversión',
          'targetAmount': 15000000,
          'targetDate': '2027-06-30',
        },
        'contributions': [
          {'id': 'c10', 'goalId': 'g5', 'amount': 2000000, 'date': '2026-08-01'},
          {'id': 'c11', 'goalId': 'g5', 'amount': -1500000, 'date': '2026-09-15'},
        ],
      },
      {
        'name': 'meta con targetAmount en 0',
        'goal': {
          'id': 'g6',
          'name': 'Meta Cero',
          'targetAmount': 0,
          'targetDate': '2026-12-01',
        },
        'contributions': <Map<String, dynamic>>[],
      },
      {
        'name': 'meta recién creada (historia menor a 30 días se clampea a 30 días)',
        'goal': {
          'id': 'g7',
          'name': 'Curso',
          'targetAmount': 3000000,
          'targetDate': '2027-01-31',
        },
        'contributions': [
          {'id': 'c12', 'goalId': 'g7', 'amount': 1500000, 'date': '2026-10-10'},
        ],
      },
    ];

    final goldenFile = File('shared/golden/goal_progress.json');
    if (!goldenFile.existsSync()) {
      final cases = <Map<String, dynamic>>[];
      for (final rc in rawCases) {
        final gMap = rc['goal'] as Map<String, dynamic>;
        final goal = _goal(
          id: gMap['id'],
          name: gMap['name'],
          targetAmount: gMap['targetAmount'],
          targetDate: gMap['targetDate'] != null ? DateTime.parse(gMap['targetDate']) : null,
        );

        final cList = (rc['contributions'] as List).map((c) {
          final cm = c as Map<String, dynamic>;
          return _contrib(
            id: cm['id'],
            goalId: cm['goalId'],
            amount: cm['amount'],
            date: DateTime.parse(cm['date']),
          );
        }).toList();

        final progress = calculateGoalProgress(
          goal: goal,
          contributions: cList,
          now: now,
        );

        String? fmt(DateTime? d) => d != null
            ? '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
            : null;

        Map<String, dynamic> statusMap;
        final st = progress.status;
        if (st is GoalStatusNoDate) {
          statusMap = {'type': 'noDate'};
        } else if (st is GoalStatusOnTrack) {
          statusMap = {'type': 'onTrack'};
        } else if (st is GoalStatusLate) {
          statusMap = {'type': 'late', 'months': st.months};
        } else {
          statusMap = {'type': 'unknown'};
        }

        cases.add({
          'name': rc['name'],
          'input': {
            'goal': rc['goal'],
            'contributions': rc['contributions'],
            'now': '2026-10-15',
          },
          'expected': {
            'saved': progress.saved,
            'percent': (progress.percent * 1000).round() / 1000,
            'remaining': progress.remaining,
            'isCompleted': progress.isCompleted,
            'requiredMonthlyPace': progress.requiredMonthlyPace,
            'realDailyPace': (progress.realDailyPace * 100).round() / 100,
            'realMonthlyPace': progress.realMonthlyPace,
            'projectedFinishDate': fmt(progress.projectedFinishDate),
            'status': statusMap,
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
      final input = c['input'] as Map<String, dynamic>;
      final gMap = input['goal'] as Map<String, dynamic>;
      final goal = _goal(
        id: gMap['id'],
        name: gMap['name'],
        targetAmount: gMap['targetAmount'],
        targetDate: gMap['targetDate'] != null ? DateTime.parse(gMap['targetDate']) : null,
      );

      final cList = (input['contributions'] as List).map((contrib) {
        final cm = contrib as Map<String, dynamic>;
        return _contrib(
          id: cm['id'],
          goalId: cm['goalId'],
          amount: cm['amount'],
          date: DateTime.parse(cm['date']),
        );
      }).toList();

      final actual = calculateGoalProgress(
        goal: goal,
        contributions: cList,
        now: DateTime.parse(input['now']),
      );

      final exp = c['expected'] as Map<String, dynamic>;
      String? fmt(DateTime? d) => d != null
          ? '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
          : null;

      expect(actual.saved, equals(exp['saved']), reason: '$name: saved');
      expect((actual.percent * 1000).round() / 1000, equals(exp['percent']), reason: '$name: percent');
      expect(actual.remaining, equals(exp['remaining']), reason: '$name: remaining');
      expect(actual.isCompleted, equals(exp['isCompleted']), reason: '$name: isCompleted');
      expect(actual.requiredMonthlyPace, equals(exp['requiredMonthlyPace']), reason: '$name: requiredMonthlyPace');
      expect((actual.realDailyPace * 100).round() / 100, equals(exp['realDailyPace']), reason: '$name: realDailyPace');
      expect(actual.realMonthlyPace, equals(exp['realMonthlyPace']), reason: '$name: realMonthlyPace');
      expect(fmt(actual.projectedFinishDate), equals(exp['projectedFinishDate']), reason: '$name: projectedFinishDate');

      final expStatus = exp['status'] as Map<String, dynamic>;
      if (expStatus['type'] == 'noDate') {
        expect(actual.status, isA<GoalStatusNoDate>(), reason: '$name: status');
      } else if (expStatus['type'] == 'onTrack') {
        expect(actual.status, isA<GoalStatusOnTrack>(), reason: '$name: status');
      } else if (expStatus['type'] == 'late') {
        expect(actual.status, isA<GoalStatusLate>(), reason: '$name: status');
        expect((actual.status as GoalStatusLate).months, equals(expStatus['months']), reason: '$name: late months');
      }
    }
  });
}
