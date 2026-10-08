import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/entry/domain/natural_parser.dart';

void main() {
  group('parseNaturalEntry', () {
    final now = DateTime(2026, 10, 8, 14, 0); // Jueves 8 de octubre de 2026
    const comida = '018f0000-0000-7000-8000-000000000001';
    const transporte = '018f0000-0000-7000-8000-000000000002';
    const hogar = '018f0000-0000-7000-8000-000000000003';
    const salud = '018f0000-0000-7000-8000-000000000004';
    const keywords = {
      'café': comida,
      'almuerzo': comida,
      'super': hogar,
      'bolt': transporte,
      'uber': transporte,
      'farmacia': salud,
    };

    test('casos exactos del plan', () {
      expect(
        parseNaturalEntry('café 15000', nowLocal: now, keywordToCategoryId: keywords)!.amount,
        15000,
      );
      expect(
        parseNaturalEntry('café 15000', nowLocal: now, keywordToCategoryId: keywords)!.categoryId,
        comida,
      );

      final s = parseNaturalEntry('super 230 mil ayer', nowLocal: now, keywordToCategoryId: keywords)!;
      expect(s.amount, 230000);
      expect(s.categoryId, hogar);
      expect(s.occurredLocalDay, DateTime(2026, 10, 7));

      expect(
        parseNaturalEntry('bolt 28.500', nowLocal: now, keywordToCategoryId: keywords)!.amount,
        28500,
      );
      expect(
        parseNaturalEntry('uber 25k', nowLocal: now, keywordToCategoryId: keywords)!.amount,
        25000,
      );

      expect(
        parseNaturalEntry('almuerzo 45.000 el lunes', nowLocal: now, keywordToCategoryId: keywords)!.occurredLocalDay,
        DateTime(2026, 10, 5),
      );

      expect(
        parseNaturalEntry('anteayer farmacia 60mil', nowLocal: now, keywordToCategoryId: keywords)!.occurredLocalDay,
        DateTime(2026, 10, 6),
      );

      expect(
        parseNaturalEntry('15000', nowLocal: now, keywordToCategoryId: keywords)!.categoryId,
        isNull,
      );

      expect(
        parseNaturalEntry('café', nowLocal: now, keywordToCategoryId: keywords),
        isNull,
      );

      expect(
        parseNaturalEntry('Café Martínez 15000', nowLocal: now, keywordToCategoryId: keywords)!.merchant,
        'Café Martínez',
      );
    });

    test('sin monto devuelve null', () {
      expect(parseNaturalEntry('', nowLocal: now, keywordToCategoryId: keywords), isNull);
      expect(parseNaturalEntry('super ayer', nowLocal: now, keywordToCategoryId: keywords), isNull);
    });

    test('palabras clave sin distinguir mayúsculas ni tildes', () {
      final res1 = parseNaturalEntry('CAFE 20000', nowLocal: now, keywordToCategoryId: keywords)!;
      expect(res1.categoryId, comida);
      expect(res1.amount, 20000);

      final res2 = parseNaturalEntry('FARMACIA 50000', nowLocal: now, keywordToCategoryId: keywords)!;
      expect(res2.categoryId, salud);
    });

    test('día de la semana más reciente <= hoy (si es hoy, hoy)', () {
      // Jueves es hoy
      final hoyRes = parseNaturalEntry('bolt 30000 el jueves', nowLocal: now, keywordToCategoryId: keywords)!;
      expect(hoyRes.occurredLocalDay, DateTime(2026, 10, 8));

      // Miércoles fue ayer (7 de octubre)
      final miercolesRes = parseNaturalEntry('super 100000 miércoles', nowLocal: now, keywordToCategoryId: keywords)!;
      expect(miercolesRes.occurredLocalDay, DateTime(2026, 10, 7));

      // Viernes más reciente fue el viernes pasado (2 de octubre)
      final viernesRes = parseNaturalEntry('almuerzo 50000 viernes', nowLocal: now, keywordToCategoryId: keywords)!;
      expect(viernesRes.occurredLocalDay, DateTime(2026, 10, 2));
    });

    test('merchant sin monto ni palabras de fecha preserva mayúsculas originales', () {
      final res = parseNaturalEntry('Superseis Los Laureles 120.000 ayer', nowLocal: now, keywordToCategoryId: keywords)!;
      expect(res.amount, 120000);
      expect(res.occurredLocalDay, DateTime(2026, 10, 7));
      expect(res.merchant, 'Superseis Los Laureles');
    });
  });
}
