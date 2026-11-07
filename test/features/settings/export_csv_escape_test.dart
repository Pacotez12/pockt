import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/settings/domain/export_csv.dart';

void main() {
  group('escapeCsvField', () {
    test('prefija con comilla simple los campos que Excel tomaría como fórmula', () {
      expect(escapeCsvField('=SUM(A1:A9)'), "'=SUM(A1:A9)");
      expect(escapeCsvField('+595981123456'), "'+595981123456");
      expect(escapeCsvField('-2+3'), "'-2+3");
      expect(escapeCsvField('@usuario'), "'@usuario");
    });

    test('protege contra inyecciones OWASP con espacios, caracteres de control o pipe', () {
      expect(escapeCsvField(' =1+1'), "' =1+1");
      expect(escapeCsvField('\t=1+1'), "'\t=1+1");
      expect(escapeCsvField('\r=cmd'), '"\'\r=cmd"');
      expect(escapeCsvField('|cmd'), "'|cmd");
      expect(escapeCsvField('Café'), 'Café');
      expect(escapeCsvField('45000'), '45000');
    });

    test('combina el prefijo con el entrecomillado cuando hace falta', () {
      expect(
        escapeCsvField('=HYPERLINK("http://x";"y")'),
        '"\'=HYPERLINK(""http://x"";""y"")"',
      );
    });

    test('no toca los campos normales ni los que tienen el símbolo en medio', () {
      expect(escapeCsvField('Supermercado'), 'Supermercado');
      expect(escapeCsvField('2x1 = promo'), '2x1 = promo');
      expect(escapeCsvField('a@b.com'), 'a@b.com');
      expect(escapeCsvField(''), '');
    });

    test('mantiene el entrecomillado de separadores, comillas y saltos de línea', () {
      expect(escapeCsvField('uno;dos'), '"uno;dos"');
      expect(escapeCsvField('dijo "hola"'), '"dijo ""hola"""');
      expect(escapeCsvField('linea1\nlinea2'), '"linea1\nlinea2"');
    });
  });
}
