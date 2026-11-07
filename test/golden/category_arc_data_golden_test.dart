import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/home/domain/category_arc_data.dart';
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

void main() {
  test('category_arc_data golden test', () {
    final cComida = _cat('c_comida', 'Comida', 0xFFE4A067, 0xFFC9844D);
    final cOcio = _cat('c_ocio', 'Ocio', 0xFFC19FE9, 0xFFA57ED4);
    final cTransp = _cat('c_transporte', 'Transporte', 0xFF6BBAF0, 0xFF4D9FD7);
    final cServ = _cat('c_servicios', 'Servicios', 0xFF8FB0F8, 0xFF7093E0);
    final cSalud = _cat('c_salud', 'Salud', 0xFF4CD964, 0xFF34C759);
    final cEduc = _cat('c_educacion', 'Educación', 0xFFFFD60A, 0xFFFFCC00);
    final cRopa = _cat('c_ropa', 'Ropa', 0xFFFF375F, 0xFFFF2D55);

    final rawCases = [
      {
        'name': '3 categorías normales',
        'input': [
          {'id': cComida.id, 'name': cComida.name, 'amount': 1500000, 'colorDark': cComida.colorDark, 'colorLight': cComida.colorLight},
          {'id': cOcio.id, 'name': cOcio.name, 'amount': 1000000, 'colorDark': cOcio.colorDark, 'colorLight': cOcio.colorLight},
          {'id': cTransp.id, 'name': cTransp.name, 'amount': 500000, 'colorDark': cTransp.colorDark, 'colorLight': cTransp.colorLight},
        ],
      },
      {
        'name': 'exactamente 5 categorías sin Otros',
        'input': [
          {'id': cComida.id, 'name': cComida.name, 'amount': 400000, 'colorDark': cComida.colorDark, 'colorLight': cComida.colorLight},
          {'id': cOcio.id, 'name': cOcio.name, 'amount': 300000, 'colorDark': cOcio.colorDark, 'colorLight': cOcio.colorLight},
          {'id': cTransp.id, 'name': cTransp.name, 'amount': 200000, 'colorDark': cTransp.colorDark, 'colorLight': cTransp.colorLight},
          {'id': cServ.id, 'name': cServ.name, 'amount': 100000, 'colorDark': cServ.colorDark, 'colorLight': cServ.colorLight},
          {'id': cSalud.id, 'name': cSalud.name, 'amount': 50000, 'colorDark': cSalud.colorDark, 'colorLight': cSalud.colorLight},
        ],
      },
      {
        'name': '7 categorías agrupa en top 4 + Otros',
        'input': [
          {'id': cComida.id, 'name': cComida.name, 'amount': 700000, 'colorDark': cComida.colorDark, 'colorLight': cComida.colorLight},
          {'id': cOcio.id, 'name': cOcio.name, 'amount': 500000, 'colorDark': cOcio.colorDark, 'colorLight': cOcio.colorLight},
          {'id': cTransp.id, 'name': cTransp.name, 'amount': 400000, 'colorDark': cTransp.colorDark, 'colorLight': cTransp.colorLight},
          {'id': cServ.id, 'name': cServ.name, 'amount': 300000, 'colorDark': cServ.colorDark, 'colorLight': cServ.colorLight},
          {'id': cSalud.id, 'name': cSalud.name, 'amount': 200000, 'colorDark': cSalud.colorDark, 'colorLight': cSalud.colorLight},
          {'id': cEduc.id, 'name': cEduc.name, 'amount': 150000, 'colorDark': cEduc.colorDark, 'colorLight': cEduc.colorLight},
          {'id': cRopa.id, 'name': cRopa.name, 'amount': 50000, 'colorDark': cRopa.colorDark, 'colorLight': cRopa.colorLight},
        ],
      },
      {
        'name': 'redondeo de porcentajes con mayor resto (1/3 cada uno suma 100)',
        'input': [
          {'id': cComida.id, 'name': cComida.name, 'amount': 100, 'colorDark': cComida.colorDark, 'colorLight': cComida.colorLight},
          {'id': cOcio.id, 'name': cOcio.name, 'amount': 100, 'colorDark': cOcio.colorDark, 'colorLight': cOcio.colorLight},
          {'id': cTransp.id, 'name': cTransp.name, 'amount': 100, 'colorDark': cTransp.colorDark, 'colorLight': cTransp.colorLight},
        ],
      },
      {
        'name': 'ignora categorías con monto 0 o negativo',
        'input': [
          {'id': cComida.id, 'name': cComida.name, 'amount': 800000, 'colorDark': cComida.colorDark, 'colorLight': cComida.colorLight},
          {'id': cOcio.id, 'name': cOcio.name, 'amount': 0, 'colorDark': cOcio.colorDark, 'colorLight': cOcio.colorLight},
          {'id': cTransp.id, 'name': cTransp.name, 'amount': 200000, 'colorDark': cTransp.colorDark, 'colorLight': cTransp.colorLight},
        ],
      },
      {
        'name': 'lista vacía o todos en cero devuelve vacío',
        'input': <Map<String, dynamic>>[],
      },
      {
        'name': 'porcentajes asimétricos (ej. 48%, 22%, 17%, 13% del boceto)',
        'input': [
          {'id': cComida.id, 'name': cComida.name, 'amount': 480000, 'colorDark': cComida.colorDark, 'colorLight': cComida.colorLight},
          {'id': cOcio.id, 'name': cOcio.name, 'amount': 170000, 'colorDark': cOcio.colorDark, 'colorLight': cOcio.colorLight},
          {'id': cTransp.id, 'name': cTransp.name, 'amount': 130000, 'colorDark': cTransp.colorDark, 'colorLight': cTransp.colorLight},
          {'id': cServ.id, 'name': cServ.name, 'amount': 220000, 'colorDark': cServ.colorDark, 'colorLight': cServ.colorLight},
        ],
      },
    ];

    final goldenFile = File('shared/golden/category_arc_data.json');
    if (!goldenFile.existsSync()) {
      final cases = <Map<String, dynamic>>[];
      for (final rc in rawCases) {
        final list = (rc['input'] as List).map((item) {
          final m = item as Map<String, dynamic>;
          return CategoryTotal(
            category: _cat(m['id'], m['name'], m['colorDark'], m['colorLight']),
            total: m['amount'],
          );
        }).toList();

        final segments = buildCategoryArcSegments(categoryTotals: list);
        cases.add({
          'name': rc['name'],
          'input': rc['input'],
          'expected': segments
              .map((s) => {
                    'id': s.id,
                    'name': s.name,
                    'amount': s.amount,
                    'percentage': s.percentage,
                    'colorDark': s.colorDark,
                    'colorLight': s.colorLight,
                    'isOther': s.isOther,
                  })
              .toList(),
        });
      }
      goldenFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'cases': cases}));
    }

    // Now test against the generated golden file
    final data = jsonDecode(goldenFile.readAsStringSync()) as Map<String, dynamic>;
    final cases = data['cases'] as List<dynamic>;
    expect(cases.length, greaterThanOrEqualTo(6));

    for (final c in cases) {
      final name = c['name'] as String;
      final inputList = (c['input'] as List).map((item) {
        final m = item as Map<String, dynamic>;
        return CategoryTotal(
          category: _cat(m['id'], m['name'], m['colorDark'], m['colorLight']),
          total: m['amount'],
        );
      }).toList();

      final actual = buildCategoryArcSegments(categoryTotals: inputList);
      final expectedList = c['expected'] as List<dynamic>;

      expect(actual.length, equals(expectedList.length), reason: '$name: length mismatch');
      for (var i = 0; i < actual.length; i++) {
        final exp = expectedList[i] as Map<String, dynamic>;
        expect(actual[i].id, equals(exp['id']), reason: '$name item $i id');
        expect(actual[i].name, equals(exp['name']), reason: '$name item $i name');
        expect(actual[i].amount, equals(exp['amount']), reason: '$name item $i amount');
        expect(actual[i].percentage, equals(exp['percentage']), reason: '$name item $i percentage');
        expect(actual[i].isOther, equals(exp['isOther']), reason: '$name item $i isOther');
      }
    }
  });
}
