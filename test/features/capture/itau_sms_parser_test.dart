import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/capture/domain/itau_sms_parser.dart';

void main() {
  group('parseItauSms - Débitos (§3.1)', () {
    test('parsea débito estándar con relleno de asteriscos', () {
      const sms =
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****34.500 por PIZZA HUT-MULTIPLAZA al 14/10/2026 12:15:51';
      final result = parseItauSms(sms);

      expect(result.kind, CaptureKind.debit);
      expect(result.amount, 34500);
      expect(result.description, 'PIZZA HUT-MULTIPLAZA');
      expect(result.merchantKey, 'pizza hut-multiplaza');
      expect(result.occurredAt, DateTime(2026, 10, 14, 12, 15, 51));
      expect(result.fingerprint, 'sms:2026-10-14T12:15:51.000:34500');
    });

    test('parsea montos con distinta cantidad de asteriscos y puntos de miles', () {
      const smsMillon =
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.**1.200.500 por SHELL BAHIA ABASTO al 14/10/2026 08:30:00';
      const smsMiles =
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.******7.162 por BIGGIE-DE LA VICTORIA al 14/10/2026 09:05:10';

      final r1 = parseItauSms(smsMillon);
      expect(r1.kind, CaptureKind.debit);
      expect(r1.amount, 1200500);
      expect(r1.description, 'SHELL BAHIA ABASTO');

      final r2 = parseItauSms(smsMiles);
      expect(r2.kind, CaptureKind.debit);
      expect(r2.amount, 7162);
      expect(r2.description, 'BIGGIE-DE LA VICTORIA');
    });

    test('conserva sufijos cortos de sucursal pero quita -VPOS solo en merchantKey', () {
      const smsFcia =
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****45.000 por FCIA PUNTO FARMA-P394 al 14/10/2026 10:00:00';
      const smsVpos =
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****80.000 por TIENDA EJEMPLO-VPOS al 14/10/2026 11:00:00';

      final rFcia = parseItauSms(smsFcia);
      expect(rFcia.description, 'FCIA PUNTO FARMA-P394');
      expect(rFcia.merchantKey, 'fcia punto farma-p394');

      final rVpos = parseItauSms(smsVpos);
      expect(rVpos.description, 'TIENDA EJEMPLO-VPOS');
      expect(rVpos.merchantKey, 'tienda ejemplo');
    });

    test('limpia referencias numéricas finales (>= 8 dígitos) y espacios repetidos', () {
      const smsClaude =
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.***155.000 por ANTHROPIC* CLAUDE SUB0001234567890 al 14/10/2026 14:22:01';
      const smsSteam =
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.****95.000 por WL *STEAM PURCHASE   0001234567890 al 14/10/2026 16:40:12';

      final rClaude = parseItauSms(smsClaude);
      expect(rClaude.kind, CaptureKind.debit);
      expect(rClaude.description, 'ANTHROPIC* CLAUDE');
      expect(rClaude.merchantKey, 'anthropic* claude');

      final rSteam = parseItauSms(smsSteam);
      expect(rSteam.kind, CaptureKind.debit);
      expect(rSteam.description, 'WL *STEAM PURCHASE');
      expect(rSteam.merchantKey, 'wl *steam purchase');
    });

    test('parsea pago de servicio, pago de tarjeta (incluso cortado), préstamo y recarga', () {
      const smsServicio =
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.***130.000 por Claro Pago de factura con CI al 14/10/2026 17:00:00';
      const smsTarjeta1 =
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.**1.500.000 por Bancop Pago de tarjeta con cedula al 14/10/2026 17:10:00';
      const smsTarjetaCortado =
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.***850.000 por FINANCIERA FIC Pago de tarjeta con al 14/10/2026 17:20:00';
      const smsPrestamo =
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.**1.100.000 por Banco Familiar Pago de Prestamos al 14/10/2026 17:30:00';
      const smsRecarga =
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****20.000 por Mas tarjeta Billetaje Mas - Carga al 14/10/2026 17:40:00';

      expect(
        parseItauSms(smsServicio).description,
        'Claro Pago de factura con CI',
      );
      expect(
        parseItauSms(smsTarjeta1).description,
        'Bancop Pago de tarjeta con cedula',
      );
      expect(
        parseItauSms(smsTarjetaCortado).description,
        'FINANCIERA FIC Pago de tarjeta con',
      );
      expect(
        parseItauSms(smsPrestamo).description,
        'Banco Familiar Pago de Prestamos',
      );
      expect(
        parseItauSms(smsRecarga).description,
        'Mas tarjeta Billetaje Mas - Carga',
      );
    });
  });

  group('parseItauSms - Acreditación de sueldo (§3.2)', () {
    test('parsea acreditación de sueldo sin monto', () {
      const sms =
          'Itau le informa: Su empresa realizo una acreditacion en su cuenta XXXXXXXXX en Gs. al 15/10/2026 15:19:24.Puede verificar su saldo aqui: www.itau.com.py/itaupy';
      final result = parseItauSms(sms);

      expect(result.kind, CaptureKind.salaryCredit);
      expect(result.amount, isNull);
      expect(result.occurredAt, DateTime(2026, 10, 15, 15, 19, 24));
      expect(result.fingerprint, 'sms:2026-10-15T15:19:24.000:0');
    });
  });

  group('parseItauSms - Ignorados y No reconocidos (§3.3, §4.2)', () {
    test('marca como unrecognized un aviso de débito con formato roto', () {
      const brokenDebit =
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX con nuevo formato sin fecha';
      final result = parseItauSms(brokenDebit);

      expect(result.kind, CaptureKind.unrecognized);
    });

    test('ignora otros SMS del 4828 (promos, encuestas, TC, mora)', () {
      const promo =
          'Itau: Aprovecha 20% de reintegro con tus tarjetas de credito este fin de semana.';
      const encuesta =
          'Itau le informa: Califique nuestra atencion del 1 al 5 respondiendo este SMS.';

      expect(parseItauSms(promo).kind, CaptureKind.ignored);
      expect(parseItauSms(encuesta).kind, CaptureKind.ignored);
    });
  });

  group('Privacidad - sanitización de número de cuenta (§6)', () {
    test('recorta o enmascara el número de cuenta en sanitizedRawText', () {
      const smsDebito =
          'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****34.500 por PEDIDOS YA al 14/10/2026 12:15:51';
      const smsSueldo =
          'Itau le informa: Su empresa realizo una acreditacion en su cuenta XXXXXXXXX en Gs. al 15/10/2026 15:19:24.Puede verificar su saldo aqui: www.itau.com.py/itaupy';

      final rDebito = parseItauSms(smsDebito);
      expect(rDebito.sanitizedRawText, contains('Cuenta ****'));
      expect(rDebito.sanitizedRawText, isNot(contains('XXXX')));

      final rSueldo = parseItauSms(smsSueldo);
      expect(rSueldo.sanitizedRawText, contains('cuenta ****'));
      expect(rSueldo.sanitizedRawText, isNot(contains('XXXXXXXXX')));
    });
  });
}
