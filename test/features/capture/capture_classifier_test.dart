import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/capture/domain/capture_classifier.dart';
import 'package:pockt/features/capture/domain/itau_sms_parser.dart';

void main() {
  group('classifyCapture (§4.3)', () {
    test('comercio conocido asigna categoría de merchantMemory; desconocido queda sin categoría', () {
      final knownSms = parseItauSms(
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****34.500 por PIZZA HUT-MULTIPLAZA al 14/10/2026 12:15:51',
      );
      final unknownSms = parseItauSms(
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****80.000 por TIENDA EJEMPLO-VPOS al 14/10/2026 11:00:00',
      );

      final memory = {'pizza hut-multiplaza': 'cat-comida'};

      final rKnown = classifyCapture(knownSms, merchantMemory: memory);
      expect(rKnown.kind, CaptureClassificationKind.expense);
      expect(rKnown.amount, 34500);
      expect(rKnown.categoryId, 'cat-comida');
      expect(rKnown.merchant, 'PIZZA HUT-MULTIPLAZA');
      expect(rKnown.autoConfirm, isFalse);

      final rUnknown = classifyCapture(unknownSms, merchantMemory: memory);
      expect(rUnknown.kind, CaptureClassificationKind.expense);
      expect(rUnknown.amount, 80000);
      expect(rUnknown.categoryId, isNull);
      expect(rUnknown.merchant, 'TIENDA EJEMPLO-VPOS');
    });

    test('comercio con autoConfirm activado marca autoConfirm = true cuando tiene categoría', () {
      final sms = parseItauSms(
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****34.500 por PIZZA HUT-MULTIPLAZA al 14/10/2026 12:15:51',
      );

      final result = classifyCapture(
        sms,
        merchantMemory: {'pizza hut-multiplaza': 'cat-comida'},
        autoConfirmMerchants: {'pizza hut-multiplaza'},
      );

      expect(result.kind, CaptureClassificationKind.expense);
      expect(result.categoryId, 'cat-comida');
      expect(result.autoConfirm, isTrue);
    });

    test('Pago de factura coincide con recurrente (±10% y ±5 días) y reemplaza su sugerencia pendiente', () {
      final sms = parseItauSms(
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.***130.000 por Claro Pago de factura con CI al 14/10/2026 17:00:00',
      );

      final result = classifyCapture(
        sms,
        recurringRules: [
          CaptureRecurringCandidate(
            id: 'rule-claro',
            name: 'Claro',
            amount: 125000, // dentro de ±10% (125.000 * 1.04 = 130.000)
            categoryId: 'cat-servicios',
            dueDate: DateTime(2026, 10, 12), // 2 días antes (dentro de ±5 días)
            pendingSuggestionId: 'sug-claro-oct',
          ),
        ],
      );

      expect(result.kind, CaptureClassificationKind.recurringServicePayment);
      expect(result.amount, 130000);
      expect(result.categoryId, 'cat-servicios');
      expect(result.recurringRuleId, 'rule-claro');
      expect(result.replacesSuggestionId, 'sug-claro-oct');
    });

    test(
      'Pago de factura fuera de rango (±10% o ±5 días) queda como gasto común',
      () {
        final sms = parseItauSms(
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.***130.000 por Claro Pago de factura con CI al 14/10/2026 17:00:00',
        );

        final result = classifyCapture(
          sms,
          recurringRules: [
            CaptureRecurringCandidate(
              id: 'rule-otro',
              name: 'ANDE',
              amount: 300000, // lejos del ±10%
              categoryId: 'cat-servicios',
              dueDate: DateTime(2026, 10, 14),
            ),
          ],
        );

        expect(result.kind, CaptureClassificationKind.expense);
        expect(result.recurringRuleId, isNull);
        expect(result.replacesSuggestionId, isNull);
      },
    );

    test('Pago de Prestamos coincide con cuota de préstamo activo (±5%) y liga loanId', () {
      final sms = parseItauSms(
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.**1.100.000 por Banco Familiar Pago de Prestamos al 14/10/2026 17:30:00',
      );

      final result = classifyCapture(
        sms,
        loansCategoryId: 'cat-prestamos',
        activeLoans: [
          const CaptureLoanCandidate(
            id: 'loan-familiar',
            name: 'Banco Familiar',
            installmentAmount: 1080000, // dentro de ±5% (diff 20.000 <= 54.000)
          ),
        ],
      );

      expect(result.kind, CaptureClassificationKind.loanPayment);
      expect(result.loanId, 'loan-familiar');
      expect(result.categoryId, 'cat-prestamos');
      expect(result.amount, 1100000);
    });

    test('Pago de Prestamos sin préstamo coincidente cae como gasto en categoría Préstamos', () {
      final sms = parseItauSms(
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.**1.100.000 por Banco Familiar Pago de Prestamos al 14/10/2026 17:30:00',
      );

      final result = classifyCapture(
        sms,
        loansCategoryId: 'cat-prestamos',
        activeLoans: [
          const CaptureLoanCandidate(
            id: 'loan-otro',
            name: 'Coop',
            installmentAmount: 500000, // fuera de ±5%
          ),
        ],
      );

      expect(result.kind, CaptureClassificationKind.expense);
      expect(result.loanId, isNull);
      expect(result.categoryId, 'cat-prestamos');
      expect(result.amount, 1100000);
    });

    test(
      'Pago de tarjeta (completo o cortado) se clasifica como transferencia',
      () {
        final sms1 = parseItauSms(
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.**1.500.000 por Bancop Pago de tarjeta con cedula al 14/10/2026 17:10:00',
        );
        final sms2 = parseItauSms(
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.***850.000 por FINANCIERA FIC Pago de tarjeta con al 14/10/2026 17:20:00',
        );

        final r1 = classifyCapture(sms1);
        expect(r1.kind, CaptureClassificationKind.cardPaymentTransfer);
        expect(r1.amount, 1500000);

        final r2 = classifyCapture(sms2);
        expect(r2.kind, CaptureClassificationKind.cardPaymentTransfer);
        expect(r2.amount, 850000);
      },
    );

    test('Acreditación de sueldo confirma sola la sugerencia del esquema si está en ±3 días', () {
      final sms = parseItauSms(
        'Itau le informa: Su empresa realizo una acreditacion en su cuenta XXXXXXXXX en Gs. al 15/10/2026 15:19:24.Puede verificar su saldo aqui: www.itau.com.py/itaupy',
      );

      final result = classifyCapture(
        sms,
        pendingSalarySuggestions: [
          CaptureSalarySuggestionCandidate(
            id: 'sug-sueldo-15',
            amount: 4500000,
            categoryId: 'cat-sueldo',
            occurredAt: DateTime(2026, 10, 15),
          ),
        ],
      );

      expect(result.kind, CaptureClassificationKind.confirmSalarySuggestion);
      expect(result.confirmSuggestionId, 'sug-sueldo-15');
      expect(result.amount, 4500000);
      expect(result.categoryId, 'cat-sueldo');
      expect(result.occurredAt, DateTime(2026, 10, 15, 15, 19, 24));
      expect(result.autoConfirm, isTrue);
    });

    test('Acreditación de sueldo sin sugerencia pendiente crea sugerencia de ingreso con monto esperado o 0', () {
      final sms = parseItauSms(
        'Itau le informa: Su empresa realizo una acreditacion en su cuenta XXXXXXXXX en Gs. al 15/10/2026 15:19:24.Puede verificar su saldo aqui: www.itau.com.py/itaupy',
      );

      final withSchedule = classifyCapture(
        sms,
        expectedSalaryAmount: 4500000,
        salaryCategoryId: 'cat-sueldo',
      );
      expect(
        withSchedule.kind,
        CaptureClassificationKind.salaryIncomeSuggestion,
      );
      expect(withSchedule.amount, 4500000);
      expect(withSchedule.categoryId, 'cat-sueldo');
      expect(withSchedule.autoConfirm, isFalse);

      final withoutSchedule = classifyCapture(
        sms,
        salaryCategoryId: 'cat-sueldo',
      );
      expect(
        withoutSchedule.kind,
        CaptureClassificationKind.salaryIncomeSuggestion,
      );
      expect(withoutSchedule.amount, 0);
      expect(withoutSchedule.categoryId, 'cat-sueldo');
    });
  });
}
