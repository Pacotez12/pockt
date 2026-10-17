import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/capture/data/capture_service.dart';
import 'package:pockt/features/capture/data/counterparty_rules_repository.dart';
import 'package:pockt/features/capture/data/email_capture_service.dart';
import 'package:pockt/features/capture/data/email_source.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

class _SpyNotifier implements Notifier {
  final List<({String title, String body, String? payload})> shown = [];

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> show(String title, String body, {String? payload}) async {
    shown.add((title: title, body: body, payload: payload));
  }

  @override
  Future<void> schedule(dynamic r) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAllReminders() async {}
}

void main() {
  late AppDatabase db;
  late _SpyNotifier notifier;
  late FakeEmailSource emailSource;
  late FakeSmsSource smsSource;
  late SettingsRepository settingsRepo;
  late SuggestionsRepository suggestionsRepo;
  late TransactionsRepository txRepo;
  late LoansRepository loansRepo;
  late CounterpartyRulesRepository rulesRepo;
  late EmailCaptureService emailService;
  late CaptureService smsService;

  const catSueldoId = '018f0000-0000-7000-8000-000000000011';
  const catServiciosId = '018f0000-0000-7000-8000-000000000003';

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    notifier = _SpyNotifier();
    emailSource = FakeEmailSource();
    smsSource = FakeSmsSource();
    settingsRepo = SettingsRepository(db);
    suggestionsRepo = SuggestionsRepository(db);
    txRepo = TransactionsRepository(db);
    loansRepo = LoansRepository(db);
    rulesRepo = CounterpartyRulesRepository(db);

    emailService = EmailCaptureService(
      db: db,
      notifier: notifier,
      source: emailSource,
      suggestionsRepository: suggestionsRepo,
      transactionsRepository: txRepo,
      loansRepository: loansRepo,
      counterpartyRulesRepository: rulesRepo,
      settingsRepository: settingsRepo,
    );

    smsService = CaptureService(
      db: db,
      notifier: notifier,
      smsSource: smsSource,
      suggestionsRepository: suggestionsRepo,
      settingsRepository: settingsRepo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('interruptor apagado no lee correos', () async {
    emailSource.inbox = [
      RawEmail(
        id: 'msg-1',
        receivedAt: DateTime(2026, 10, 16, 10, 0),
        subject: 'Aviso de transferencia recibida',
        bodyText: '''
Nro. de operación: | 000000000000000 |
Fecha y hora de operación: | 16/10/2026 10:00:00 |
Cliente Pagador: | MARIA LOPEZ |
Moneda y Monto: | PYG 50,000 |
''',
      ),
    ];

    final pending = await emailService.sync();
    expect(pending, 0);
    expect(emailSource.fetchCalls, 0);
  });

  test('mismo correo dos veces solo crea 1 sugerencia', () async {
    await settingsRepo.set(SettingsKeys.captureEmailEnabled, 'true');
    await settingsRepo.set(SettingsKeys.captureEmailSince, '2026-10-01T00:00:00.000');

    final email = RawEmail(
      id: 'msg-rec-1',
      receivedAt: DateTime(2026, 10, 16, 10, 0),
      subject: 'Aviso de transferencia recibida',
      bodyText: '''
Nro. de operación: | ABCDPYPA000000000000000000 |
Fecha y hora de operación: | 16/10/2026 10:00:00 |
Cliente Pagador: | MARIA LOPEZ |
Moneda y Monto: | PYG 30,000 |
Concepto de la Transferencia: | /Pago/ |
''',
    );

    final count1 = await emailService.ingest([email]);
    expect(count1, 1);

    final count2 = await emailService.ingest([email]);
    expect(count2, 0);

    final pending = await suggestionsRepo.watchPending().first;
    expect(pending.length, 1);
    expect(pending.single.suggestion.fingerprint, 'email:msg-rec-1');
  });

  test('recibida con regla crea movimiento y notificación, sin sugerencia', () async {
    await settingsRepo.set(SettingsKeys.captureEmailEnabled, 'true');
    await rulesRepo.upsert(
      nameKey: 'MARIA LOPEZ',
      direction: TransferDirection.incoming,
      action: CounterpartyAction.income,
      categoryId: catSueldoId,
      autoApply: true,
    );

    final email = RawEmail(
      id: 'msg-auto-1',
      receivedAt: DateTime(2026, 10, 16, 11, 0),
      subject: 'Aviso de transferencia recibida',
      bodyText: '''
Nro. de operación: | ABCDPYPA000000000000000000 |
Fecha y hora de operación: | 16/10/2026 11:00:00 |
Cliente Pagador: | MARIA LOPEZ |
Moneda y Monto: | PYG 50,000 |
Concepto de la Transferencia: | /Sueldo/ |
''',
    );

    final count = await emailService.ingest([email]);
    expect(count, 0);

    final pending = await suggestionsRepo.watchPending().first;
    expect(pending, isEmpty);

    final txs = await txRepo.getAllActive();
    expect(txs.length, 1);
    expect(txs.first.tx.amount, 50000);
    expect(txs.first.tx.type, TxType.income);
    expect(txs.first.tx.categoryId, catSueldoId);

    expect(
      notifier.shown.any((n) => n.body.contains('Ingreso registrado: MARIA LOPEZ Gs. 50.000')),
      isTrue,
    );
  });

  test('unión SMS↔correo: correo luego SMS y SMS luego correo para mismo pago de 95.000 da 1 sola entrada (Review Focus 2)', () async {
    await settingsRepo.set(SettingsKeys.captureEmailEnabled, 'true');
    await settingsRepo.set(SettingsKeys.captureSmsEnabled, 'true');

    // Caso A: correo primero, luego SMS
    final email1 = RawEmail(
      id: 'msg-claro-1',
      receivedAt: DateTime(2026, 10, 16, 14, 0),
      subject: 'Aviso de pago de servicios',
      bodyText: '''
Concepto del servicio | Claro - Pago de factura con CI |
Monto del pago: | 95,000 |
Fecha y hora de operación: | 16/10/2026 |
Nro. de operación: | 123456 |
''',
    );
    await emailService.ingest([email1]);

    final sms1 = RawSms(
      sender: '4828',
      body: 'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.****95.000 por Claro Pago de factura con CI al 16/10/2026 14:02:00',
      receivedAt: DateTime(2026, 10, 16, 14, 2),
    );
    await smsService.ingest([sms1]);

    var pending = await suggestionsRepo.watchPending().first;
    expect(pending.where((s) => s.suggestion.amount == 95000).length, 1);

    // Caso B: SMS primero, luego correo (con monto diferente para distinguir: 110.000)
    final sms2 = RawSms(
      sender: '4828',
      body: 'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.***110.000 por Personal Pago de factura al 16/10/2026 15:00:00',
      receivedAt: DateTime(2026, 10, 16, 15, 0),
    );
    await smsService.ingest([sms2]);

    final email2 = RawEmail(
      id: 'msg-personal-2',
      receivedAt: DateTime(2026, 10, 16, 15, 5),
      subject: 'Aviso de pago de servicios',
      bodyText: '''
Concepto del servicio | Personal - Pago de factura |
Monto del pago: | 110,000 |
Fecha y hora de operación: | 16/10/2026 |
Nro. de operación: | 789012 |
''',
    );
    await emailService.ingest([email2]);

    pending = await suggestionsRepo.watchPending().first;
    expect(pending.where((s) => s.suggestion.amount == 110000).length, 1);
  });

  test('manual 95.000 a la 1 h se marca como posible duplicado', () async {
    await settingsRepo.set(SettingsKeys.captureEmailEnabled, 'true');

    // Movimiento manual a las 12:00
    await txRepo.add(
      type: TxType.expense,
      amount: 95000,
      categoryId: catServiciosId,
      occurredAt: DateTime(2026, 10, 16, 12, 0),
    );

    // Correo llega con hora 13:00 (a 1 hora de diferencia)
    final email = RawEmail(
      id: 'msg-dup-1',
      receivedAt: DateTime(2026, 10, 16, 13, 0),
      subject: 'Aviso de transferencia enviada',
      bodyText: '''
Nro. de operación: | 000000000000000 |
Fecha y hora de operación: | 16/10/2026 13:00:00 |
Cliente Pagador: | JUAN PEREZ |
Moneda y Monto: | PYG 95,000 |
Cliente Beneficiario: | PEDRO GOMEZ |
''',
    );

    await emailService.ingest([email]);

    final pending = await suggestionsRepo.watchPending().first;
    expect(pending.length, 1);
    expect(pending.single.suggestion.isPossibleDuplicate, isTrue);
  });

  test('reconexión dos syncs seguidos emite una sola notificación (Review Focus 3)', () async {
    await settingsRepo.set(SettingsKeys.captureEmailEnabled, 'true');
    emailSource.requireReconnect = true;

    final count1 = await emailService.sync();
    expect(count1, 0);
    expect(await settingsRepo.get(SettingsKeys.captureEmailNeedsReconnect), 'true');
    expect(notifier.shown.where((n) => n.body.contains('Volvé a conectar Gmail')).length, 1);

    final count2 = await emailService.sync();
    expect(count2, 0);
    // No se duplica la notificación
    expect(notifier.shown.where((n) => n.body.contains('Volvé a conectar Gmail')).length, 1);
  });

  test('120 correos desordenados se procesan todos y emailLastAt queda con el más nuevo (Review Focus 5)', () async {
    await settingsRepo.set(SettingsKeys.captureEmailEnabled, 'true');
    await settingsRepo.set(SettingsKeys.captureEmailSince, '2026-09-01T00:00:00.000');

    final baseDate = DateTime(2026, 9, 10, 8, 0);
    final emails = List.generate(120, (i) {
      final dt = baseDate.add(Duration(hours: (i * 7) % 240));
      return RawEmail(
        id: 'msg-bulk-$i',
        receivedAt: dt,
        subject: 'Aviso de transferencia recibida',
        bodyText: '''
Nro. de operación: | $i |
Fecha y hora de operación: | 10/09/2026 08:00:00 |
Cliente Pagador: | PERSONA $i |
Moneda y Monto: | PYG ${10000 + i * 1000} |
''',
      );
    });

    final count = await emailService.ingest(emails);
    expect(count, 120);

    final pending = await suggestionsRepo.watchPending().first;
    expect(pending.length, 120);

    final lastAtStr = await settingsRepo.get(SettingsKeys.captureEmailLastAt);
    expect(lastAtStr, isNotNull);
    final lastAt = DateTime.parse(lastAtStr!);

    DateTime maxDt = emails.first.receivedAt;
    for (final e in emails) {
      if (e.receivedAt.isAfter(maxDt)) maxDt = e.receivedAt;
    }
    expect(lastAt, maxDt);
  });

  test('primera transferencia enviada fija captureEmailOwnerName', () async {
    await settingsRepo.set(SettingsKeys.captureEmailEnabled, 'true');

    expect(await settingsRepo.get(SettingsKeys.captureEmailOwnerName), isNull);

    final email = RawEmail(
      id: 'msg-owner-1',
      receivedAt: DateTime(2026, 10, 16, 16, 0),
      subject: 'Aviso de transferencia enviada',
      bodyText: '''
Nro. de operación: | 000000000000000 |
Fecha y hora de operación: | 16/10/2026 16:00:00 |
Cliente Pagador: | JUAN PEREZ |
Moneda y Monto: | PYG 20,000 |
Cliente Beneficiario: | FARMACIA SAN BLAS |
''',
    );

    await emailService.ingest([email]);

    final owner = await settingsRepo.get(SettingsKeys.captureEmailOwnerName);
    expect(owner, 'JUAN PEREZ');
  });
}
