import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/reports/domain/ant_expenses.dart';
import 'package:pockt/features/reports/domain/compare.dart';
import 'package:pockt/features/reports/domain/weekly_summary.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

Category _cat(String id, String name, int dark, int light) {
  return Category(
    id: id,
    name: name,
    icon: 'tag',
    colorDark: dark,
    colorLight: light,
    kind: CategoryKind.expense,
    sortOrder: 0,
    archived: false,
  );
}

TxView _view({
  required String id,
  required TxType type,
  required int amount,
  String? merchant,
  required Category category,
  required DateTime occurredAt,
}) {
  return TxView(
    tx: Transaction(
      id: id,
      type: type,
      amount: amount,
      merchant: merchant,
      occurredAt: occurredAt,
      categoryId: category.id,
      currency: 'PYG',
      source: TxSource.manual,
      isExtra: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    category: category,
  );
}

void main() {
  test('reports golden test', () {
    final catComida = _cat('c_comida', 'Comida', 0xFFE4A067, 0xFFC9844D);
    final catCafes = _cat('c_cafes', 'Cafés y meriendas', 0xFFC19FE9, 0xFFA57ED4);
    final catTransp = _cat('c_transp', 'Transporte', 0xFF6BBAF0, 0xFF4D9FD7);

    final rawCases = [
      {
        'name': 'comparación de mes actual vs mes anterior (gasto menor, changePct negativo)',
        'type': 'comparison',
        'today': '2026-10-15',
        'dailyExpenseByLocalDay': {
          '2026-09-01': 100000,
          '2026-09-10': 200000,
          '2026-09-15': 150000,
          '2026-09-28': 300000, // posterior al día 15 de sep, no entra
          '2026-10-02': 80000,
          '2026-10-05': 120000,
          '2026-10-15': 100000,
        },
      },
      {
        'name': 'comparación cuando mes anterior fue cero (changePct null)',
        'type': 'comparison',
        'today': '2026-10-10',
        'dailyExpenseByLocalDay': {
          '2026-10-01': 50000,
          '2026-10-05': 70000,
        },
      },
      {
        'name': 'comparación en cambio de año (enero compara con diciembre del año anterior)',
        'type': 'comparison',
        'today': '2027-01-10',
        'dailyExpenseByLocalDay': {
          '2026-12-05': 200000,
          '2026-12-10': 300000,
          '2027-01-03': 150000,
          '2027-01-08': 250000,
        },
      },
      {
        'name': 'gastos hormiga normalización de comercio y selección de grafía más frecuente',
        'type': 'ant_expenses',
        'threshold': 30000,
        'transactions': [
          {'id': 't1', 'type': 'expense', 'amount': 15000, 'merchant': 'Biggie Express', 'category': 'c_comida'},
          {'id': 't2', 'type': 'expense', 'amount': 20000, 'merchant': 'biggie express', 'category': 'c_comida'},
          {'id': 't3', 'type': 'expense', 'amount': 25000, 'merchant': 'Biggie Express', 'category': 'c_comida'},
          {'id': 't4', 'type': 'expense', 'amount': 50000, 'merchant': 'Biggie Express', 'category': 'c_comida'}, // mayor al umbral: ignorado
          {'id': 't5', 'type': 'income', 'amount': 10000, 'merchant': 'Biggie Express', 'category': 'c_comida'}, // ingreso: ignorado
        ],
      },
      {
        'name': 'gastos hormiga sin comercio agrupa por categoría',
        'type': 'ant_expenses',
        'threshold': 30000,
        'transactions': [
          {'id': 't6', 'type': 'expense', 'amount': 12000, 'merchant': null, 'category': 'c_cafes'},
          {'id': 't7', 'type': 'expense', 'amount': 18000, 'merchant': '', 'category': 'c_cafes'},
          {'id': 't8', 'type': 'expense', 'amount': 25000, 'merchant': 'Bolt', 'category': 'c_transp'},
        ],
      },
      {
        'name': 'resumen semanal con semana anterior e identificación de top categoría',
        'type': 'weekly_summary',
        'weekStart': '2026-10-05',
        'weekEnd': '2026-10-11',
        'currentWeekTxs': [
          {'id': 'w1', 'type': 'expense', 'amount': 80000, 'category': 'c_comida'},
          {'id': 'w2', 'type': 'expense', 'amount': 120000, 'category': 'c_comida'},
          {'id': 'w3', 'type': 'expense', 'amount': 50000, 'category': 'c_transp'},
        ],
        'previousWeekTxs': [
          {'id': 'w4', 'type': 'expense', 'amount': 200000, 'category': 'c_comida'},
        ],
      },
      {
        'name': 'resumen semanal cuando semana anterior fue cero (percentageDiff null)',
        'type': 'weekly_summary',
        'weekStart': '2026-10-12',
        'weekEnd': '2026-10-18',
        'currentWeekTxs': [
          {'id': 'w5', 'type': 'expense', 'amount': 150000, 'category': 'c_comida'},
        ],
        'previousWeekTxs': <Map<String, dynamic>>[],
      },
    ];

    Category getCat(String id) {
      if (id == 'c_cafes') return catCafes;
      if (id == 'c_transp') return catTransp;
      return catComida;
    }

    final goldenFile = File('shared/golden/reports.json');
    if (!goldenFile.existsSync()) {
      final cases = <Map<String, dynamic>>[];
      for (final rc in rawCases) {
        final type = rc['type'] as String;

        if (type == 'comparison') {
          final today = DateTime.parse(rc['today'] as String);
          final rawMap = rc['dailyExpenseByLocalDay'] as Map<String, dynamic>;
          final dailyMap = <DateTime, int>{};
          for (final e in rawMap.entries) {
            dailyMap[DateTime.parse(e.key)] = e.value as int;
          }

          final comp = compareToPreviousMonth(
            todayLocal: today,
            dailyExpenseByLocalDay: dailyMap,
          );

          cases.add({
            'name': rc['name'],
            'type': type,
            'input': rc,
            'expected': {
              'current': comp.current,
              'previous': comp.previous,
              'changePct': comp.changePct != null
                  ? (comp.changePct! * 10).round() / 10
                  : null,
            },
          });
        } else if (type == 'ant_expenses') {
          final threshold = rc['threshold'] as int;
          final txs = (rc['transactions'] as List).map((t) {
            final tm = t as Map<String, dynamic>;
            final cat = getCat(tm['category'] as String);
            return _view(
              id: tm['id'],
              type: tm['type'] == 'expense' ? TxType.expense : TxType.income,
              amount: tm['amount'],
              merchant: tm['merchant'],
              category: cat,
              occurredAt: DateTime(2026, 10, 10),
            );
          }).toList();

          final ant = calculateAntExpenses(transactions: txs, threshold: threshold);
          cases.add({
            'name': rc['name'],
            'type': type,
            'input': rc,
            'expected': {
              'total': ant.total,
              'count': ant.count,
              'annualProjection': ant.annualProjection,
              'threshold': ant.threshold,
              'groups': ant.groups
                  .map((g) => {
                        'name': g.name,
                        'merchant': g.merchant,
                        'categoryName': g.categoryName,
                        'total': g.total,
                        'count': g.count,
                        'average': g.average,
                      })
                  .toList(),
            },
          });
        } else if (type == 'weekly_summary') {
          final curTxs = (rc['currentWeekTxs'] as List).map((t) {
            final tm = t as Map<String, dynamic>;
            final cat = getCat(tm['category'] as String);
            return _view(
              id: tm['id'],
              type: tm['type'] == 'expense' ? TxType.expense : TxType.income,
              amount: tm['amount'],
              category: cat,
              occurredAt: DateTime(2026, 10, 10),
            );
          }).toList();

          final prevTxs = (rc['previousWeekTxs'] as List).map((t) {
            final tm = t as Map<String, dynamic>;
            final cat = getCat(tm['category'] as String);
            return _view(
              id: tm['id'],
              type: tm['type'] == 'expense' ? TxType.expense : TxType.income,
              amount: tm['amount'],
              category: cat,
              occurredAt: DateTime(2026, 10, 3),
            );
          }).toList();

          final ws = calculateWeeklySummary(
            currentWeekTxs: curTxs,
            previousWeekTxs: prevTxs,
            weekStart: DateTime.parse(rc['weekStart'] as String),
            weekEnd: DateTime.parse(rc['weekEnd'] as String),
          );

          cases.add({
            'name': rc['name'],
            'type': type,
            'input': rc,
            'expected': {
              'currentWeekTotal': ws.currentWeekTotal,
              'previousWeekTotal': ws.previousWeekTotal,
              'percentageDiff': ws.percentageDiff,
              'topCategoryName': ws.topCategoryName,
              'topCategoryAmount': ws.topCategoryAmount,
            },
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
      final type = c['type'] as String;
      final exp = c['expected'] as Map<String, dynamic>;
      final inp = c['input'] as Map<String, dynamic>;

      if (type == 'comparison') {
        final today = DateTime.parse(inp['today'] as String);
        final rawMap = inp['dailyExpenseByLocalDay'] as Map<String, dynamic>;
        final dailyMap = <DateTime, int>{};
        for (final e in rawMap.entries) {
          dailyMap[DateTime.parse(e.key)] = e.value as int;
        }

        final actual = compareToPreviousMonth(
          todayLocal: today,
          dailyExpenseByLocalDay: dailyMap,
        );

        expect(actual.current, equals(exp['current']), reason: '$name: current');
        expect(actual.previous, equals(exp['previous']), reason: '$name: previous');
        final roundedActualPct = actual.changePct != null
            ? (actual.changePct! * 10).round() / 10
            : null;
        expect(roundedActualPct, equals(exp['changePct']), reason: '$name: changePct');
      } else if (type == 'ant_expenses') {
        final threshold = inp['threshold'] as int;
        final txs = (inp['transactions'] as List).map((t) {
          final tm = t as Map<String, dynamic>;
          final cat = getCat(tm['category'] as String);
          return _view(
            id: tm['id'],
            type: tm['type'] == 'expense' ? TxType.expense : TxType.income,
            amount: tm['amount'],
            merchant: tm['merchant'],
            category: cat,
            occurredAt: DateTime(2026, 10, 10),
          );
        }).toList();

        final actual = calculateAntExpenses(transactions: txs, threshold: threshold);
        expect(actual.total, equals(exp['total']), reason: '$name: total');
        expect(actual.count, equals(exp['count']), reason: '$name: count');
        expect(actual.annualProjection, equals(exp['annualProjection']), reason: '$name: annualProjection');
        expect(actual.groups.length, equals((exp['groups'] as List).length), reason: '$name: groups length');

        for (var i = 0; i < actual.groups.length; i++) {
          final gExp = (exp['groups'] as List)[i] as Map<String, dynamic>;
          expect(actual.groups[i].name, equals(gExp['name']), reason: '$name group $i name');
          expect(actual.groups[i].merchant, equals(gExp['merchant']), reason: '$name group $i merchant');
          expect(actual.groups[i].total, equals(gExp['total']), reason: '$name group $i total');
          expect(actual.groups[i].count, equals(gExp['count']), reason: '$name group $i count');
          expect(actual.groups[i].average, equals(gExp['average']), reason: '$name group $i average');
        }
      } else if (type == 'weekly_summary') {
        final curTxs = (inp['currentWeekTxs'] as List).map((t) {
          final tm = t as Map<String, dynamic>;
          final cat = getCat(tm['category'] as String);
          return _view(
            id: tm['id'],
            type: tm['type'] == 'expense' ? TxType.expense : TxType.income,
            amount: tm['amount'],
            category: cat,
            occurredAt: DateTime(2026, 10, 10),
          );
        }).toList();

        final prevTxs = (inp['previousWeekTxs'] as List).map((t) {
          final tm = t as Map<String, dynamic>;
          final cat = getCat(tm['category'] as String);
          return _view(
            id: tm['id'],
            type: tm['type'] == 'expense' ? TxType.expense : TxType.income,
            amount: tm['amount'],
            category: cat,
            occurredAt: DateTime(2026, 10, 3),
          );
        }).toList();

        final actual = calculateWeeklySummary(
          currentWeekTxs: curTxs,
          previousWeekTxs: prevTxs,
          weekStart: DateTime.parse(inp['weekStart'] as String),
          weekEnd: DateTime.parse(inp['weekEnd'] as String),
        );

        expect(actual.currentWeekTotal, equals(exp['currentWeekTotal']), reason: '$name: curWeekTotal');
        expect(actual.previousWeekTotal, equals(exp['previousWeekTotal']), reason: '$name: prevWeekTotal');
        expect(actual.percentageDiff, equals(exp['percentageDiff']), reason: '$name: pctDiff');
        expect(actual.topCategoryName, equals(exp['topCategoryName']), reason: '$name: topCatName');
        expect(actual.topCategoryAmount, equals(exp['topCategoryAmount']), reason: '$name: topCatAmount');
      }
    }
  });
}
