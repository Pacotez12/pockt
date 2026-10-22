import 'package:flutter/services.dart';
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

  test('ThousandsInputFormatter agrega puntos de miles mientras se escribe', () {
    const f = ThousandsInputFormatter();
    TextEditingValue type(String t) => f.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length)),
        );
    expect(type('10000000').text, '10.000.000');
    expect(type('10000000').selection.baseOffset, 10);
    expect(type('1.0000').text, '10.000');
    expect(type('999').text, '999');
    expect(type('').text, '');
  });
}
