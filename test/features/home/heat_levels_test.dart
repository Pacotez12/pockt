import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/home/domain/heat_levels.dart';

void main() {
  test('vacío', () => expect(heatLevels({}), isEmpty));

  test('un solo día con gasto es nivel 4', () => expect(heatLevels({17: 612000}), {17: 4}));

  test('cuartiles: el mayor es 4, el menor es 1', () {
    final l = heatLevels({
      1: 10000,
      2: 20000,
      3: 30000,
      4: 40000,
      5: 50000,
      6: 60000,
      7: 70000,
      8: 80000,
    });
    expect(l[1], 1);
    expect(l[2], 1);
    expect(l[7], 4);
    expect(l[8], 4);
    expect(l.values.toSet(), {1, 2, 3, 4});
  });

  test('todos iguales caen en nivel 4', () => expect(heatLevels({1: 5000, 2: 5000}), {1: 4, 2: 4}));

  test('montos en 0 quedan en nivel 0', () => expect(heatLevels({3: 0}), {3: 0}));
}
