import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/capture/domain/capture_classifier.dart';
import 'package:pockt/features/capture/domain/email_classifier.dart';
import 'package:pockt/features/capture/domain/itau_email_parser.dart';

void main() {
  group('emailClassifier', () {
    final now = DateTime(2026, 10, 10, 12, 0);

    test('recibida sin regla va a inbox con suggestedAction income', () {
      final capture = EmailCapture(
        kind: EmailCaptureKind.transferIn,
        messageId: 'msg-1',
        amount: 30000,
        occurredAt: now,
        hasTime: true,
        counterparty: 'MARIA LOPEZ',
        sanitizedRawText: 'Transferencia recibida de MARIA LOPEZ Gs. 30.000',
      );

      final res = classifyEmail(capture);

      expect(res.kind, EmailOutcomeKind.inbox);
      expect(res.suggestedAction, CounterpartyAction.income);
      expect(res.categoryId, isNull);
      expect(res.loanId, isNull);
    });

    test('recibida con regla autoApply income/cat X va a autoApply con categoryId', () {
      final capture = EmailCapture(
        kind: EmailCaptureKind.transferIn,
        messageId: 'msg-2',
        amount: 50000,
        occurredAt: now,
        hasTime: true,
        counterparty: 'MARIA LOPEZ',
        sanitizedRawText: 'Transferencia recibida de MARIA LOPEZ Gs. 50.000',
      );

      final rule = const EmailRuleView(
        action: CounterpartyAction.income,
        categoryId: 'cat-sueldo',
        autoApply: true,
      );

      final res = classifyEmail(capture, rule: rule);

      expect(res.kind, EmailOutcomeKind.autoApply);
      expect(res.suggestedAction, CounterpartyAction.income);
      expect(res.categoryId, 'cat-sueldo');
      expect(res.loanId, isNull);
    });

    test('regla loanRepayment con loanId fuera de activeLoanIds vuelve a inbox sin préstamo (Review Focus 4)', () {
      final capture = EmailCapture(
        kind: EmailCaptureKind.transferIn,
        messageId: 'msg-3',
        amount: 100000,
        occurredAt: now,
        hasTime: true,
        counterparty: 'PEDRO GOMEZ',
        sanitizedRawText: 'Transferencia recibida de PEDRO GOMEZ Gs. 100.000',
      );

      final rule = const EmailRuleView(
        action: CounterpartyAction.loanRepayment,
        loanId: 'loan-cerrado',
        autoApply: true,
      );

      final res = classifyEmail(
        capture,
        rule: rule,
        activeLoanIds: {'loan-activo-1', 'loan-activo-2'},
      );

      expect(res.kind, EmailOutcomeKind.inbox);
      expect(res.suggestedAction, CounterpartyAction.income);
      expect(res.loanId, isNull);
    });

    test('recibida o enviada con counterparty == ownerNameKey va a inbox con suggestedAction ignore', () {
      final ownerKey = normalizePersonKey('JUAN PEREZ');

      final captureIn = EmailCapture(
        kind: EmailCaptureKind.transferIn,
        messageId: 'msg-4',
        amount: 200000,
        occurredAt: now,
        hasTime: true,
        counterparty: 'Juan Perez',
        sanitizedRawText: 'Transferencia recibida de Juan Perez Gs. 200.000',
      );

      final captureOut = EmailCapture(
        kind: EmailCaptureKind.transferOut,
        messageId: 'msg-5',
        amount: 150000,
        occurredAt: now,
        hasTime: true,
        counterparty: 'JUAN PÉREZ',
        sanitizedRawText: 'Transferencia enviada a JUAN PÉREZ Gs. 150.000',
      );

      final resIn = classifyEmail(captureIn, ownerNameKey: ownerKey);
      expect(resIn.kind, EmailOutcomeKind.inbox);
      expect(resIn.suggestedAction, CounterpartyAction.ignore);

      final resOut = classifyEmail(captureOut, ownerNameKey: ownerKey);
      expect(resOut.kind, EmailOutcomeKind.inbox);
      expect(resOut.suggestedAction, CounterpartyAction.ignore);
    });

    test('enviada con regla autoApply: true igual va a inbox precargada con la acción de la regla', () {
      final capture = EmailCapture(
        kind: EmailCaptureKind.transferOut,
        messageId: 'msg-6',
        amount: 45000,
        occurredAt: now,
        hasTime: true,
        counterparty: 'ALMACEN DON TITO',
        sanitizedRawText: 'Transferencia enviada a ALMACEN DON TITO Gs. 45.000',
      );

      final rule = const EmailRuleView(
        action: CounterpartyAction.expense,
        categoryId: 'cat-supermercado',
        autoApply: true, // No debería aplicarse sola nunca para salidas
      );

      final res = classifyEmail(capture, rule: rule);

      expect(res.kind, EmailOutcomeKind.inbox);
      expect(res.suggestedAction, CounterpartyAction.expense);
      expect(res.categoryId, 'cat-supermercado');
    });

    test('servicePayment Claro - Pago de factura con recurrente va a serviceClassified recurringServicePayment', () {
      final capture = EmailCapture(
        kind: EmailCaptureKind.servicePayment,
        messageId: 'msg-7',
        amount: 95000,
        occurredAt: now,
        hasTime: false,
        concept: 'Claro - Pago de factura con CI',
        sanitizedRawText: 'Pago de servicio Claro Gs. 95.000',
      );

      final recurringRule = CaptureRecurringCandidate(
        id: 'rec-claro',
        name: 'Claro',
        amount: 95000,
        dueDate: now,
        categoryId: 'cat-servicios',
      );

      final res = classifyEmail(
        capture,
        recurringRules: [recurringRule],
      );

      expect(res.kind, EmailOutcomeKind.serviceClassified);
      expect(res.service, isNotNull);
      expect(res.service!.kind, CaptureClassificationKind.recurringServicePayment);
      expect(res.service!.recurringRuleId, 'rec-claro');
      expect(res.categoryId, 'cat-servicios');
    });

    test('servicePayment Bancop - Pago de tarjeta con cédula va a gasto en Tarjetas', () {
      final capture = EmailCapture(
        kind: EmailCaptureKind.servicePayment,
        messageId: 'msg-8',
        amount: 1500000,
        occurredAt: now,
        hasTime: false,
        concept: 'Bancop - Pago de tarjeta con cedula',
        sanitizedRawText: 'Pago de servicio Bancop Gs. 1.500.000',
      );

      final res = classifyEmail(
        capture,
        cardsCategoryId: 'cat-tarjetas',
      );

      expect(res.kind, EmailOutcomeKind.serviceClassified);
      expect(res.service, isNotNull);
      expect(res.service!.kind, CaptureClassificationKind.expense);
      expect(res.categoryId, 'cat-tarjetas');
      expect(res.service!.categoryId, 'cat-tarjetas');
    });

    test('ignored y unrecognized se mapean directamente', () {
      final ignored = EmailCapture(
        kind: EmailCaptureKind.ignored,
        messageId: 'msg-9',
        sanitizedRawText: '',
      );
      final unrec = EmailCapture(
        kind: EmailCaptureKind.unrecognized,
        messageId: 'msg-10',
        sanitizedRawText: '',
      );

      expect(classifyEmail(ignored).kind, EmailOutcomeKind.ignored);
      expect(classifyEmail(unrec).kind, EmailOutcomeKind.unrecognized);
    });
  });
}
