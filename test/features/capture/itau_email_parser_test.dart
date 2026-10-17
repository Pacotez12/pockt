import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/capture/domain/itau_email_parser.dart';

void main() {
  group('normalizePersonKey', () {
    test('limpia tildes, pasa a mayúsculas y colapsa espacios', () {
      expect(normalizePersonKey('  María  López '), 'MARIA LOPEZ');
      expect(normalizePersonKey('Ángel  Ñandú  Úbeda'), 'ANGEL NANDU UBEDA');
    });
  });

  group('parseItauEmail', () {
    const sentTransferBody = '''
Nro. de operación: | 000000000000000 |
Fecha y hora de operación: | 10/10/2026 12:47 |
Cliente Pagador: | JUAN PEREZ |
Nro. de cuenta del pagador: | ****XXXX |
Moneda y Monto: | Gs. 15.000 |
Cliente Beneficiario: | PEDRO GOMEZ |
Nro. de cuenta del beneficiario: | ****XXXX |
Entidad beneficiaria: | BANCO EJEMPLO SAECA |
Concepto de la Transferencia: | |
Estado: | La transferencia ha sido acreditada a la entidad beneficiaria |
''';

    const receivedTransferBody = '''
Nro. de operación: | ABCDPYPA000000000000000000 |
Fecha y hora de operación: | 10/10/2026 12:47:20 |
Cliente Pagador: | MARIA LOPEZ |
Nro. de cuenta del pagador: | ****XXXX |
Entidad pagadora: | BANCO EJEMPLO S.A. |
Moneda y Monto: | PYG 30,000 |
Nro. de cuenta crédito: | ****XXXX |
Nro. comprobante: | 0000000 |
Concepto de la Transferencia: | /BNF/ |
Estado: | Transferencia acreditada en cuenta |
''';

    const servicePaymentBody = '''
Tipo de cuenta: | Ahorro a la Vista Guaraníes |
Nombre del cliente: | JUAN PEREZ |
Concepto del servicio | Claro - Pago de factura con CI |
Referencia del servicio: | 0000000 |
Monto del pago: | 95,000 |
Fecha y hora de operación: | 15/10/2026 |
Nro. de operación: | 0000000 |
''';

    test('parsea transferencia enviada', () {
      final receivedAt = DateTime(2026, 10, 10, 12, 48);
      final capture = parseItauEmail(
        messageId: 'msg-1',
        subject: 'Aviso de transferencia enviada',
        bodyText: sentTransferBody,
        receivedAt: receivedAt,
      );

      expect(capture.kind, EmailCaptureKind.transferOut);
      expect(capture.messageId, 'msg-1');
      expect(capture.fingerprint, 'email:msg-1');
      expect(capture.amount, 15000);
      expect(capture.occurredAt, DateTime(2026, 10, 10, 12, 47));
      expect(capture.hasTime, isTrue);
      expect(capture.counterparty, 'PEDRO GOMEZ');
      expect(capture.payer, 'JUAN PEREZ');
      expect(capture.entity, 'BANCO EJEMPLO SAECA');
      expect(capture.concept, isNull);
      expect(capture.operationId, '000000000000000');
    });

    test('parsea transferencia recibida', () {
      final receivedAt = DateTime(2026, 10, 10, 12, 48);
      final capture = parseItauEmail(
        messageId: 'msg-2',
        subject: 'Aviso de transferencia recibida',
        bodyText: receivedTransferBody,
        receivedAt: receivedAt,
      );

      expect(capture.kind, EmailCaptureKind.transferIn);
      expect(capture.messageId, 'msg-2');
      expect(capture.fingerprint, 'email:msg-2');
      expect(capture.amount, 30000);
      expect(capture.occurredAt, DateTime(2026, 10, 10, 12, 47, 20));
      expect(capture.hasTime, isTrue);
      expect(capture.counterparty, 'MARIA LOPEZ');
      expect(capture.payer, 'MARIA LOPEZ');
      expect(capture.entity, 'BANCO EJEMPLO S.A.');
      expect(capture.concept, '/BNF/');
      expect(capture.operationId, 'ABCDPYPA000000000000000000');
    });

    test('parsea pago de servicios sin hora (usa receivedAt)', () {
      final receivedAt = DateTime(2026, 10, 15, 14, 30);
      final capture = parseItauEmail(
        messageId: 'msg-3',
        subject: 'AVISO DE PAGO DE SERVICIOS',
        bodyText: servicePaymentBody,
        receivedAt: receivedAt,
      );

      expect(capture.kind, EmailCaptureKind.servicePayment);
      expect(capture.amount, 95000);
      expect(capture.hasTime, isFalse);
      expect(capture.occurredAt, receivedAt);
      expect(capture.concept, 'Claro - Pago de factura con CI');
      expect(capture.operationId, '0000000');
    });

    test('parsea monto con comas y puntos grandes (ej. 1,200,500)', () {
      const body = '''
Tipo de cuenta: | Ahorro a la Vista Guaraníes |
Nombre del cliente: | JUAN PEREZ |
Concepto del servicio | Bancop - Pago de tarjeta con cédula |
Referencia del servicio: | 0000000 |
Monto del pago: | 1,200,500 |
Fecha y hora de operación: | 15/10/2026 |
Nro. de operación: | 123456 |
''';
      final receivedAt = DateTime(2026, 10, 15, 16, 0);
      final capture = parseItauEmail(
        messageId: 'msg-4',
        subject: 'AVISO DE PAGO DE SERVICIOS',
        bodyText: body,
        receivedAt: receivedAt,
      );

      expect(capture.amount, 1200500);
      expect(capture.concept, 'Bancop - Pago de tarjeta con cédula');
    });

    test('asunto desconocido se marca ignored', () {
      final capture = parseItauEmail(
        messageId: 'msg-promo',
        subject: 'Tu código de seguridad',
        bodyText: 'Tu código es 123456',
        receivedAt: DateTime(2026, 10, 10),
      );

      expect(capture.kind, EmailCaptureKind.ignored);
    });

    test('asunto conocido pero sin campos requeridos se marca unrecognized', () {
      final capture = parseItauEmail(
        messageId: 'msg-broken',
        subject: 'Aviso de transferencia enviada',
        bodyText: 'Texto roto sin monto ni operación',
        receivedAt: DateTime(2026, 10, 10),
      );

      expect(capture.kind, EmailCaptureKind.unrecognized);
    });

    test('soporta &nbsp; y espacios dobles en celdas (Review Focus 1)', () {
      const bodyWithNbsp = '''
Nro. de operación:&nbsp;| 000000000000000 |
Fecha y hora de operación:&nbsp;| 10/10/2026&nbsp;12:47 |
Cliente Pagador: |  JUAN   PEREZ  |
Nro. de cuenta del pagador: | ****XXXX |
Moneda y Monto: | Gs.&nbsp;15.000 |
Cliente Beneficiario: | PEDRO  GOMEZ |
Concepto de la Transferencia: | &nbsp; |
''';
      final capture = parseItauEmail(
        messageId: 'msg-nbsp',
        subject: 'Aviso de transferencia enviada',
        bodyText: bodyWithNbsp,
        receivedAt: DateTime(2026, 10, 10),
      );

      expect(capture.kind, EmailCaptureKind.transferOut);
      expect(capture.amount, 15000);
      expect(capture.counterparty, 'PEDRO GOMEZ');
      expect(capture.concept, isNull);
    });

    test('sanitizedRawText no contiene números de cuenta ni ****XXXX', () {
      final capture = parseItauEmail(
        messageId: 'msg-sec',
        subject: 'Aviso de transferencia enviada',
        bodyText: sentTransferBody,
        receivedAt: DateTime(2026, 10, 10),
      );

      expect(capture.sanitizedRawText.contains('cuenta'), isFalse);
      expect(capture.sanitizedRawText.contains('XXXX'), isFalse);
      expect(capture.sanitizedRawText.contains('PEDRO GOMEZ'), isTrue);
      expect(capture.sanitizedRawText.contains('15.000'), isTrue);
    });
  });
}
