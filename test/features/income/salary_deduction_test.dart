import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/income/domain/salary_deduction.dart';

void main() {
  group('netPayAmounts pure function', () {
    test('4.000.000, 30/70, IPS 9 % + fijo 40.000 devuelve [1.200.000, 2.400.000]', () {
      final gross = 4000000;
      final splits = [30, 70];
      final deductions = [
        const SalaryDeductionItem(
          name: 'IPS',
          kind: 'percent',
          value: 900, // 9 % en centésimas de punto
        ),
        const SalaryDeductionItem(
          name: 'Seguro privado',
          kind: 'fixed',
          value: 40000,
        ),
      ];

      final net = netPayAmounts(gross, splits, deductions);

      expect(net, equals([1200000, 2400000]));
    });

    test('un descuento que deja el cobro negativo es rechazado', () {
      final gross = 4000000;
      final splits = [30, 70]; // bruto fin de mes: 2.800.000
      final deductions = [
        const SalaryDeductionItem(
          name: 'Descuento excesivo',
          kind: 'fixed',
          value: 3000000, // supera los 2.800.000 del último cobro
        ),
      ];

      expect(
        () => netPayAmounts(gross, splits, deductions),
        throwsArgumentError,
      );
    });

    test('sin descuentos devuelve el reparto íntegro de splitAmounts', () {
      final gross = 5000000;
      final splits = [50, 50];

      final net = netPayAmounts(gross, splits, const []);

      expect(net, equals([2500000, 2500000]));
    });

    test('modo mensual (un solo cobro) resta todos los descuentos', () {
      final gross = 6000000;
      final splits = [100];
      final deductions = [
        const SalaryDeductionItem(
          name: 'IPS',
          kind: 'percent',
          value: 900, // 540.000
        ),
        const SalaryDeductionItem(
          name: 'Ahorro cooperativa',
          kind: 'fixed',
          value: 200000,
        ),
      ];

      final net = netPayAmounts(gross, splits, deductions);

      expect(net, equals([5260000]));
    });

    test('descuento con valor negativo lanza ArgumentError', () {
      expect(
        () => netPayAmounts(
          4000000,
          [50, 50],
          [const SalaryDeductionItem(name: 'Inválido', kind: 'fixed', value: -1000)],
        ),
        throwsArgumentError,
      );
    });
  });
}
