import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/loans/domain/installment_schedule_parser.dart';

void main() {
  group('parseInstallmentSchedule', () {
    test('devuelve lista vacía y sin errores si el texto está vacío o solo tiene espacios', () {
      final res1 = parseInstallmentSchedule('');
      expect(res1.installments, isEmpty);
      expect(res1.lineErrors, isEmpty);
      expect(res1.isValid, isFalse);

      final res2 = parseInstallmentSchedule('   \n  \n');
      expect(res2.installments, isEmpty);
      expect(res2.lineErrors, isEmpty);
      expect(res2.isValid, isFalse);
    });

    test('parsea líneas válidas con fechas con / y montos con puntos', () {
      const text = '''
1 02/01/2027 905.000
2 02/02/2027 805.000
3 02/03/2027 705.000
''';
      final res = parseInstallmentSchedule(text);
      expect(res.lineErrors, isEmpty);
      expect(res.isValid, isTrue);
      expect(res.installments.length, 3);

      expect(res.installments[0].number, 1);
      expect(res.installments[0].dueDate, DateTime(2027, 1, 2));
      expect(res.installments[0].amount, 905000);

      expect(res.installments[1].number, 2);
      expect(res.installments[1].dueDate, DateTime(2027, 2, 2));
      expect(res.installments[1].amount, 805000);

      expect(res.installments[2].number, 3);
      expect(res.installments[2].dueDate, DateTime(2027, 3, 2));
      expect(res.installments[2].amount, 705000);

      expect(res.totalAmount, 905000 + 805000 + 705000);
    });

    test('acepta prefijo Gs., fechas con guión y espacios extra', () {
      const text = '''

1   02-01-2027   Gs. 905.000   

2   02-02-2027   Gs 805.000
3   02-03-2027   705000
''';
      final res = parseInstallmentSchedule(text);
      expect(res.lineErrors, isEmpty);
      expect(res.isValid, isTrue);
      expect(res.installments.length, 3);
      expect(res.installments[0].amount, 905000);
      expect(res.installments[1].amount, 805000);
      expect(res.installments[2].amount, 705000);
    });

    test('marca error con número de línea si el formato de una línea no es válido', () {
      const text = '''
1 02/01/2027 905.000
esto no es una cuota
3 02/03/2027 705.000
''';
      final res = parseInstallmentSchedule(text);
      expect(res.isValid, isFalse);
      expect(res.lineErrors.containsKey(2), isTrue);
    });

    test('marca error si los números de cuota no son 1..N consecutivos', () {
      const text = '''
2 02/01/2027 905.000
3 02/02/2027 805.000
''';
      final res = parseInstallmentSchedule(text);
      expect(res.isValid, isFalse);
      expect(res.lineErrors.containsKey(1), isTrue);
    });

    test('marca error en la línea con salto de numeración', () {
      const text = '''
1 02/01/2027 905.000
2 02/02/2027 805.000
4 02/04/2027 655.000
''';
      final res = parseInstallmentSchedule(text);
      expect(res.isValid, isFalse);
      expect(res.lineErrors.containsKey(3), isTrue);
    });

    test('marca error en fecha inválida o monto inválido', () {
      const text = '''
1 32/01/2027 905.000
2 02/02/2027 0
''';
      final res = parseInstallmentSchedule(text);
      expect(res.isValid, isFalse);
      expect(res.lineErrors.containsKey(1), isTrue);
      expect(res.lineErrors.containsKey(2), isTrue);
    });

    test('formatInstallmentSchedule reconstruye el texto para el editor', () {
      final installments = [
        ParsedInstallment(number: 1, dueDate: DateTime(2027, 1, 2), amount: 905000),
        ParsedInstallment(number: 2, dueDate: DateTime(2027, 2, 2), amount: 805000),
      ];
      final text = formatInstallmentSchedule(installments);
      expect(text, contains('1 02/01/2027 905.000'));
      expect(text, contains('2 02/02/2027 805.000'));
    });
  });
}
