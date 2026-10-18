import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/home/domain/category_arc_data.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

Category _cat(String id, String name, {int colorDark = 0xFFFFFFFF, int colorLight = 0xFF000000}) {
  return Category(
    id: id,
    name: name,
    icon: 'tag',
    colorDark: colorDark,
    colorLight: colorLight,
    kind: CategoryKind.expense,
    sortOrder: 0,
    archived: false,
  );
}

CategoryTotal _tot(String id, String name, int amount, {int colorDark = 0xFF111111, int colorLight = 0xFF222222}) {
  return CategoryTotal(
    category: _cat(id, name, colorDark: colorDark, colorLight: colorLight),
    total: amount,
  );
}

void main() {
  group('buildCategoryArcSegments', () {
    test('lista vacía o sum <= 0 retorna lista vacía', () {
      expect(buildCategoryArcSegments(categoryTotals: []), isEmpty);
      expect(
        buildCategoryArcSegments(categoryTotals: [
          _tot('c1', 'Comida', 0),
          _tot('c2', 'Transporte', -100),
        ]),
        isEmpty,
      );
    });

    test('1 categoría sola: 100%', () {
      final segments = buildCategoryArcSegments(
        categoryTotals: [_tot('c1', 'Comida', 500000)],
      );
      expect(segments.length, 1);
      expect(segments.first.id, 'c1');
      expect(segments.first.name, 'Comida');
      expect(segments.first.amount, 500000);
      expect(segments.first.percentage, 100);
      expect(segments.first.isOther, isFalse);
    });

    test('hasta 5 categorías: sin "Otros", ordenadas de mayor a menor y porcentajes suman 100', () {
      final segments = buildCategoryArcSegments(
        categoryTotals: [
          _tot('c1', 'Salidas', 200000),
          _tot('c2', 'Comida', 600000),
          _tot('c3', 'Transporte', 100000),
          _tot('c4', 'Servicios', 100000),
        ],
      );

      expect(segments.length, 4);
      expect(segments.map((s) => s.name).toList(), [
        'Comida',
        'Salidas',
        'Transporte',
        'Servicios',
      ]);
      expect(segments.any((s) => s.isOther), isFalse);

      final totalPct = segments.fold<int>(0, (sum, s) => sum + s.percentage);
      expect(totalPct, 100);
      expect(segments[0].percentage, 60);
      expect(segments[1].percentage, 20);
      expect(segments[2].percentage, 10);
      expect(segments[3].percentage, 10);
    });

    test('exactamente 5 categorías: mantiene las 5 sin "Otros"', () {
      final segments = buildCategoryArcSegments(
        categoryTotals: [
          _tot('c1', 'A', 50),
          _tot('c2', 'B', 40),
          _tot('c3', 'C', 30),
          _tot('c4', 'D', 20),
          _tot('c5', 'E', 10),
        ],
      );

      expect(segments.length, 5);
      expect(segments.any((s) => s.isOther), isFalse);
      expect(segments.map((s) => s.name).toList(), ['A', 'B', 'C', 'D', 'E']);
      expect(segments.fold<int>(0, (sum, s) => sum + s.percentage), 100);
    });

    test('más de 5 categorías: top 4 + "Otros" agrupando el resto al final', () {
      // Caso idéntico al boceto HTML: Comida 1.056.000, Salidas 360.000, Transporte 240.000,
      // Servicios 168.000, Salud 200.000, Hogar 200.000, Ropa 176.000 (total resto = 576.000)
      final segments = buildCategoryArcSegments(
        categoryTotals: [
          _tot('c1', 'Comida', 1056000, colorDark: 0xFFE4A067),
          _tot('c2', 'Salidas', 360000, colorDark: 0xFFC19FE9),
          _tot('c3', 'Transporte', 240000, colorDark: 0xFF6BBAF0),
          _tot('c4', 'Servicios', 168000, colorDark: 0xFF8FB0F8),
          _tot('c5', 'Salud', 160000),
          _tot('c6', 'Hogar', 150000),
          _tot('c7', 'Ropa', 140000),
          _tot('c8', 'Educación', 126000),
        ],
        otherColorDark: 0xFF7C8796,
        otherColorLight: 0xFF606A74,
      );

      expect(segments.length, 5);
      expect(segments.map((s) => s.name).toList(), [
        'Comida',
        'Salidas',
        'Transporte',
        'Servicios',
        'Otros',
      ]);
      expect(segments[4].isOther, isTrue);
      expect(segments[4].amount, 576000);
      expect(segments[4].colorDark, 0xFF7C8796);
      expect(segments[4].colorLight, 0xFF606A74);

      // Porcentajes del boceto: 44, 15, 10, 7, 24 = 100%
      expect(segments[0].percentage, 44);
      expect(segments[1].percentage, 15);
      expect(segments[2].percentage, 10);
      expect(segments[3].percentage, 7);
      expect(segments[4].percentage, 24);
      expect(segments.fold<int>(0, (sum, s) => sum + s.percentage), 100);
    });

    test('porcentajes inexactos siempre suman exactamente 100 mediante mayor resto', () {
      // 100 dividido entre 3: 33.333% cada uno
      final segments = buildCategoryArcSegments(
        categoryTotals: [
          _tot('c1', 'A', 100),
          _tot('c2', 'B', 100),
          _tot('c3', 'C', 100),
        ],
      );

      expect(segments.fold<int>(0, (sum, s) => sum + s.percentage), 100);
      // El primero recibe el resto sobrante: 34, 33, 33
      expect(segments[0].percentage, 34);
      expect(segments[1].percentage, 33);
      expect(segments[2].percentage, 33);
    });
  });
}
