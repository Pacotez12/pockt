import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/format/money.dart';

void main() {
  test('formatGs con separador de miles y símbolo', () {
    expect(formatGs(4212000), 'Gs. 4.212.000');
    expect(formatGs(15000, symbol: false), '15.000');
    expect(formatGs(0), 'Gs. 0');
    expect(formatGs(-28500), '−Gs. 28.500');
    expect(formatGs(-15000, symbol: false), '−15.000');
  });

  test('keypadAppend respeta ceros a la izquierda, 000 y tope de 12 dígitos', () {
    expect(keypadAppend('', '0'), '');
    expect(keypadAppend('', '000'), '');
    expect(keypadAppend('15', '000'), '15000');
    expect(keypadAppend('15000', '⌫'), '1500');
    expect(keypadAppend('', '⌫'), '');
    expect(keypadAppend('99999999999', '000'), '999999999990');
    expect(keypadAppend('999999999999', '1'), '999999999999');
    expect(keypadAppend('1234567890', '000'), '123456789000');
  });

  test('keypadValue', () {
    expect(keypadValue(''), 0);
    expect(keypadValue('28500'), 28500);
  });
}
