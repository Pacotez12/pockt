import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/income/domain/pay_split.dart';

void main() {
  group('splitAmounts', () {
    test('splitAmounts(7000000, [30, 70]) == [2100000, 4900000]', () {
      final result = splitAmounts(7000000, [30, 70]);
      expect(result, equals([2100000, 4900000]));
    });

    test('splitAmounts(1000001, [50, 50]) suma 1000001 exactamente', () {
      final result = splitAmounts(1000001, [50, 50]);
      expect(result.fold<int>(0, (a, b) => a + b), equals(1000001));
      expect(result, equals([500001, 500000]));
    });

    test('un solo cobro devuelve el monto completo', () {
      final result = splitAmounts(5000000, [100]);
      expect(result, equals([5000000]));
    });

    test('monto 0 devuelve ceros', () {
      final result = splitAmounts(0, [50, 50]);
      expect(result, equals([0, 0]));
    });

    test('lista vacía de porcentajes devuelve lista vacía', () {
      final result = splitAmounts(7000000, []);
      expect(result, isEmpty);
    });
  });

  group('parsePaySplitPercents', () {
    test('parsea json válido con la cantidad esperada', () {
      expect(parsePaySplitPercents('[30, 70]', count: 2), equals([30, 70]));
    });

    test('si es nulo o vacío devuelve partes iguales según count', () {
      expect(parsePaySplitPercents(null, count: 2), equals([50, 50]));
      expect(parsePaySplitPercents('', count: 1), equals([100]));
      expect(parsePaySplitPercents('[]', count: 2), equals([50, 50]));
    });

    test('si la cantidad no coincide devuelve partes iguales', () {
      expect(parsePaySplitPercents('[100]', count: 2), equals([50, 50]));
    });
  });
}
