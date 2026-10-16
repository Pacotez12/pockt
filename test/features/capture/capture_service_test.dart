import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/capture/data/capture_service.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:timezone/data/latest.dart' as tz;

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
  setUpAll(() async {
    tz.initializeTimeZones();
    await initLocalZone();
  });

  late AppDatabase db;
  late _SpyNotifier notifier;
  late SuggestionsRepository suggestionsRepo;
  late TransactionsRepository txRepo;
  late SettingsRepository settingsRepo;
  late FakeSmsSource smsSource;
  late CaptureService service;

  const catComidaId = '018f0000-0000-7000-8000-000000000001';
  const catServiciosId = '018f0000-0000-7000-8000-000000000006';
  const catSueldoId = '018f0000-0000-7000-8000-000000000011';
  const catPrestamosId = '018f0000-0000-7000-8000-000000000014';
  const catTarjetasId = '018f0000-0000-7000-8000-000000000015';

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    notifier = _SpyNotifier();
    suggestionsRepo = SuggestionsRepository(db);
    txRepo = TransactionsRepository(db);
    settingsRepo = SettingsRepository(db);
    smsSource = FakeSmsSource();
    service = CaptureService(
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

  test('deduplica por fingerprint: el mismo SMS dos veces solo crea 1 sugerencia', () async {
    const smsBody =
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****34.500 por PIZZA HUT-MULTIPLAZA al 15/10/2026 12:15:51';
    final raw = RawSms(
      sender: '4828',
      body: smsBody,
      receivedAt: DateTime(2026, 10, 15, 12, 16),
    );

    final count1 = await service.ingest([raw]);
    final count2 = await service.ingest([raw]);

    expect(count1, 1);
    expect(count2, 0);

    final pending = await suggestionsRepo.watchPending().first;
    expect(pending.length, 1);
    expect(pending.single.suggestion.amount, 34500);
    expect(pending.single.suggestion.merchant, 'PIZZA HUT-MULTIPLAZA');
    expect(pending.single.suggestion.rawText, isNot(contains('XXXX')));
    expect(notifier.shown.length, 1);
    expect(notifier.shown.single.body, 'Tenés 1 movimiento por confirmar');
  });

  test('detecta posible duplicado contra movimiento manual ±2 h y permite Es el mismo o Es otro', () async {
    // Movimiento manual cargado a las 11:00 (1h 15m antes del SMS de las 12:15:51)
    final manualTxId = await txRepo.add(
      type: TxType.expense,
      amount: 34500,
      categoryId: catComidaId,
      merchant: 'Pizza Hut',
      occurredAt: DateTime(2026, 10, 15, 11, 0),
    );

    const smsBody =
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****34.500 por PIZZA HUT-MULTIPLAZA al 15/10/2026 12:15:51';
    await service.ingest([
      RawSms(
        sender: '4828',
        body: smsBody,
        receivedAt: DateTime(2026, 10, 15, 12, 16),
      ),
    ]);

    final pending = await suggestionsRepo.watchPending().first;
    expect(pending.length, 1);
    final sug = pending.single.suggestion;
    expect(sug.isPossibleDuplicate, isTrue);
    expect(sug.duplicateTxId, manualTxId);

    // "Es el mismo": descarta la sugerencia y la une al movimiento manual
    await suggestionsRepo.resolveDuplicateAsSame(sug.id);

    final pendingAfter = await suggestionsRepo.watchPending().first;
    expect(pendingAfter, isEmpty);

    final updatedManualTx = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(manualTxId))).getSingle();
    expect(updatedManualTx.suggestionId, sug.id);

    final updatedSug = await (db.select(
      db.suggestedTransactions,
    )..where((s) => s.id.equals(sug.id))).getSingle();
    expect(updatedSug.status, 'dismissed');
    expect(updatedSug.transactionId, manualTxId);
  });

  test('movimiento manual fuera de la ventana de ±2 h NO se marca como posible duplicado', () async {
    // Movimiento manual a las 08:00 (> 4 horas antes del SMS de las 12:15:51)
    await txRepo.add(
      type: TxType.expense,
      amount: 34500,
      categoryId: catComidaId,
      merchant: 'Pizza Hut',
      occurredAt: DateTime(2026, 10, 15, 8, 0),
    );

    const smsBody =
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****34.500 por PIZZA HUT-MULTIPLAZA al 15/10/2026 12:15:51';
    await service.ingest([
      RawSms(
        sender: '4828',
        body: smsBody,
        receivedAt: DateTime(2026, 10, 15, 12, 16),
      ),
    ]);

    final pending = await suggestionsRepo.watchPending().first;
    expect(pending.single.suggestion.isPossibleDuplicate, isFalse);
  });

  test('sueldo confirma sola la sugerencia pendiente del esquema en ±3 días con su monto esperado y la hora del SMS', () async {
    await db
        .into(db.suggestedTransactions)
        .insert(
          SuggestedTransactionsCompanion.insert(
            id: 'sug-pay-15',
            type: TxType.income,
            amount: 4500000,
            categoryId: const Value(catSueldoId),
            merchant: const Value('Cobro'),
            occurredAt: DateTime(2026, 10, 15),
            source: TxSource.incomeSchedule,
            sourceRef: const Value('sched-1'),
            status: 'pending',
            createdAt: DateTime(2026, 10, 15),
          ),
        );

    const smsSueldo =
        'Itau le informa: Su empresa realizo una acreditacion en su cuenta XXXXXXXXX en Gs. al 15/10/2026 15:19:24.Puede verificar su saldo aqui: www.itau.com.py/itaupy';
    final count = await service.ingest([
      RawSms(
        sender: '4828',
        body: smsSueldo,
        receivedAt: DateTime(2026, 10, 15, 15, 20),
      ),
    ]);

    // Se confirmó sola, no queda pendiente por confirmar
    expect(count, 0);
    final pending = await suggestionsRepo.watchPending().first;
    expect(pending, isEmpty);

    final txs = await txRepo.getAllActive();
    expect(txs.length, 1);
    expect(txs.single.tx.type, TxType.income);
    expect(txs.single.tx.amount, 4500000);
    expect(
      toLocal(txs.single.tx.occurredAt),
      DateTime(2026, 10, 15, 15, 19, 24),
    );
  });

  test('Pago de factura reemplaza sugerencia pendiente de recurrente (±10%, ±5 días) y Pago de Prestamos liga loanId al confirmar', () async {
    // 1. Regla recurrente + sugerencia pendiente
    await db
        .into(db.recurringRules)
        .insert(
          RecurringRulesCompanion.insert(
            id: 'rule-claro',
            name: 'Claro',
            type: TxType.expense,
            amount: 125000,
            categoryId: catServiciosId,
            frequency: 'monthly',
            dayOfMonth: const Value(15),
            nextDueDate: DateTime(2026, 10, 15),
          ),
        );
    await db
        .into(db.suggestedTransactions)
        .insert(
          SuggestedTransactionsCompanion.insert(
            id: 'sug-claro-rec',
            type: TxType.expense,
            amount: 125000,
            categoryId: const Value(catServiciosId),
            merchant: const Value('Claro'),
            occurredAt: DateTime(2026, 10, 15),
            source: TxSource.recurring,
            sourceRef: const Value('rule-claro'),
            status: 'pending',
            createdAt: DateTime(2026, 10, 15),
          ),
        );

    // 2. Préstamo activo con cuota de 1.100.000
    await db
        .into(db.loans)
        .insert(
          LoansCompanion.insert(
            id: 'loan-fam',
            direction: LoanDirection.owe,
            kind: LoanKind.installments,
            name: 'Banco Familiar',
            totalAmount: 11000000,
            installmentAmount: const Value(1100000),
            installmentsTotal: const Value(10),
            startDate: DateTime(2026, 1, 1),
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        );

    const smsFactura =
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.***130.000 por Claro Pago de factura con CI al 15/10/2026 17:00:00';
    const smsPrestamo =
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.**1.100.000 por Banco Familiar Pago de Prestamos al 15/10/2026 17:30:00';

    await service.ingest([
      RawSms(
        sender: '4828',
        body: smsFactura,
        receivedAt: DateTime(2026, 10, 15, 17, 1),
      ),
      RawSms(
        sender: '4828',
        body: smsPrestamo,
        receivedAt: DateTime(2026, 10, 15, 17, 31),
      ),
    ]);

    final pending = await suggestionsRepo.watchPending().first;
    // La sugerencia vieja sug-claro-rec fue reemplazada: solo hay 2 pendientes (factura y préstamo)
    expect(pending.length, 2);

    final sugFactura = pending
        .firstWhere((p) => p.suggestion.amount == 130000)
        .suggestion;
    expect(sugFactura.linkedRecurringRuleId, 'rule-claro');

    final sugPrestamo = pending
        .firstWhere((p) => p.suggestion.amount == 1100000)
        .suggestion;
    expect(sugPrestamo.linkedLoanId, 'loan-fam');

    final txLoanId = await suggestionsRepo.confirm(sugPrestamo.id);
    final txLoan = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(txLoanId))).getSingle();
    expect(txLoan.loanId, 'loan-fam');
    expect(txLoan.categoryId, catPrestamosId);
  });

  test('comercio con autoConfirm en merchant_memory se confirma solo sin pasar por pendientes', () async {
    await db
        .into(db.merchantMemory)
        .insert(
          MerchantMemoryCompanion.insert(
            merchantKey: 'pedidos ya',
            categoryId: catComidaId,
            uses: 3,
            lastUsedAt: DateTime(2026, 10, 10),
            autoConfirm: const Value(true),
          ),
        );

    const sms =
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****45.000 por PEDIDOS YA al 15/10/2026 20:00:00';
    final count = await service.ingest([
      RawSms(
        sender: '4828',
        body: sms,
        receivedAt: DateTime(2026, 10, 15, 20, 1),
      ),
    ]);

    expect(count, 0);
    expect(await suggestionsRepo.watchPending().first, isEmpty);

    final txs = await txRepo.getAllActive();
    expect(txs.length, 1);
    expect(txs.single.tx.amount, 45000);
    expect(txs.single.tx.categoryId, catComidaId);
    expect(txs.single.tx.source, TxSource.capture);
  });

  test('respeta capture.since, actualiza capture.lastSmsAt y cuenta no reconocidos', () async {
    await settingsRepo.set(SettingsKeys.captureSince, '2026-10-15');

    const oldSms =
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****25.000 por BIGGIE-DE LA VICTORIA al 14/10/2026 10:00:00';
    const brokenSms =
        'Itau informa: Registramos un debito con formato desconocido';
    const validSms =
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****34.500 por PIZZA HUT-MULTIPLAZA al 15/10/2026 12:15:51';

    final count = await service.ingest([
      RawSms(
        sender: '4828',
        body: oldSms,
        receivedAt: DateTime(2026, 10, 14, 10, 1),
      ),
      RawSms(
        sender: '4828',
        body: brokenSms,
        receivedAt: DateTime(2026, 10, 15, 11, 0),
      ),
      RawSms(
        sender: '4828',
        body: validSms,
        receivedAt: DateTime(2026, 10, 15, 12, 16),
      ),
    ]);

    expect(count, 1); // solo el del 15/10 válido
    final unrecognized = await settingsRepo.get(
      SettingsKeys.captureUnrecognizedCount,
    );
    expect(unrecognized, '1');

    final lastSmsAt = await settingsRepo.get(SettingsKeys.captureLastSmsAt);
    expect(lastSmsAt, isNotNull);
    expect(DateTime.parse(lastSmsAt!), DateTime(2026, 10, 15, 12, 16));
  });

  test('syncInbox no hace nada si capture.smsEnabled está apagado o no hay permiso', () async {
    smsSource.setInbox([
      RawSms(
        sender: '4828',
        body: 'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****34.500 por PIZZA HUT-MULTIPLAZA al 15/10/2026 12:15:51',
        receivedAt: DateTime(2026, 10, 15, 12, 16),
      ),
    ]);

    // 1. Por defecto apagado -> 0
    expect(await service.syncInbox(), 0);
    expect(await suggestionsRepo.watchPending().first, isEmpty);

    // 2. Prendido pero sin permiso -> 0
    await settingsRepo.set(SettingsKeys.captureSmsEnabled, 'true');
    smsSource.permissionsGranted = false;
    expect(await service.syncInbox(), 0);
    expect(await suggestionsRepo.watchPending().first, isEmpty);

    // 3. Prendido y con permiso -> procesa el buzón
    smsSource.permissionsGranted = true;
    expect(await service.syncInbox(), 1);
    expect((await suggestionsRepo.watchPending().first).length, 1);
  });

  test('SMS Pago de tarjeta crea sugerencia de gasto en Tarjetas y se auto-confirma si está configurado', () async {
    const sms =
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****1.500.000 por Bancop Pago de tarjeta con cedula al 15/10/2026 14:00:00';

    // 1. Sin autoConfirm -> sugerencia pendiente de tipo expense en Tarjetas
    final count = await service.ingest([
      RawSms(
        sender: '4828',
        body: sms,
        receivedAt: DateTime(2026, 10, 15, 14, 1),
      ),
    ]);
    expect(count, 1);

    final pending = await suggestionsRepo.watchPending().first;
    expect(pending.length, 1);
    expect(pending.single.suggestion.type, TxType.expense);
    expect(pending.single.suggestion.categoryId, catTarjetasId);
    expect(pending.single.suggestion.amount, 1500000);

    // 2. Con autoConfirm configurado para el comercio -> se confirma directamente
    await db
        .into(db.merchantMemory)
        .insert(
          MerchantMemoryCompanion.insert(
            merchantKey: 'financiera fic pago de tarjeta con',
            categoryId: catTarjetasId,
            uses: 2,
            lastUsedAt: DateTime(2026, 10, 15),
            autoConfirm: const Value(true),
          ),
        );

    const smsAuto =
        'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****850.000 por FINANCIERA FIC Pago de tarjeta con al 15/10/2026 15:00:00';
    final countAuto = await service.ingest([
      RawSms(
        sender: '4828',
        body: smsAuto,
        receivedAt: DateTime(2026, 10, 15, 15, 1),
      ),
    ]);
    expect(countAuto, 0); // confirmado directamente

    final txs = await (db.select(
      db.transactions,
    )..where((t) => t.amount.equals(850000))).get();
    expect(txs.length, 1);
    expect(txs.single.type, TxType.expense);
    expect(txs.single.categoryId, catTarjetasId);
  });
}
