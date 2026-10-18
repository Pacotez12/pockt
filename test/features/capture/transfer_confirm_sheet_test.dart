import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/features/capture/data/counterparty_rules_repository.dart';
import 'package:pockt/features/capture/ui/transfer_confirm_sheet.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/recurring/ui/suggestion_card.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

import 'package:pockt/core/design/theme.dart';

Widget createTestApp({
  required Widget child,
  required AppDatabase db,
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      suggestionsRepositoryProvider.overrideWithValue(SuggestionsRepository(db)),
      transactionsRepositoryProvider.overrideWithValue(TransactionsRepository(db)),
      loansRepositoryProvider.overrideWithValue(LoansRepository(db)),
      counterpartyRulesRepositoryProvider.overrideWithValue(CounterpartyRulesRepository(db)),
    ],
    child: MaterialApp(
      theme: buildDarkTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  late AppDatabase db;
  late TransactionsRepository txRepo;
  late CounterpartyRulesRepository rulesRepo;

  const catSueldoId = '018f0000-0000-7000-8000-000000000011';
  const catPrestamosId = '018f0000-0000-7000-8000-000000000014';

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    txRepo = TransactionsRepository(db);
    rulesRepo = CounterpartyRulesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('recibida muestra 3 opciones y elegir Ingreso + categoría crea movimiento y regla autoApply: true', (tester) async {
    final now = DateTime(2026, 10, 16, 10, 0);
    const sugId = 'sug-in-1';

    await db.into(db.suggestedTransactions).insert(
      SuggestedTransactionsCompanion.insert(
        id: sugId,
        type: TxType.income,
        amount: 50000,
        categoryId: const Value(catSueldoId),
        merchant: const Value('MARIA LOPEZ'),
        occurredAt: now,
        source: TxSource.capture,
        status: 'pending',
        rawText: const Value('Transferencia recibida de MARIA LOPEZ Gs. 50.000'),
        fingerprint: const Value('email:msg-1'),
        captureMeta: Value(jsonEncode({
          'channel': 'email',
          'kind': 'transferIn',
          'counterparty': 'MARIA LOPEZ',
        })),
        createdAt: now,
      ),
    );

    final sug = await (db.select(db.suggestedTransactions)..where((t) => t.id.equals(sugId))).getSingle();

    await tester.pumpWidget(
      createTestApp(
        db: db,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showTransferConfirmSheet(context, sug),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    // 3 opciones visibles
    expect(find.text('Ingreso'), findsOneWidget);
    expect(find.text('Me pagaron un préstamo'), findsOneWidget);
    expect(find.text('No contar'), findsOneWidget);

    // Confirmar la opción Ingreso (por defecto)
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    // Movimiento creado
    final txs = await txRepo.getAllActive();
    expect(txs.length, 1);
    expect(txs.first.tx.amount, 50000);
    expect(txs.first.tx.type, TxType.income);

    // Regla creada con autoApply: true
    final rule = await rulesRepo.find('MARIA LOPEZ', TransferDirection.incoming);
    expect(rule, isNotNull);
    expect(rule!.action, CounterpartyAction.income);
    expect(rule.autoApply, isTrue);

    // Sugerencia confirmada
    final pending = await (db.select(db.suggestedTransactions)..where((t) => t.status.equals('pending'))).get();
    expect(pending, isEmpty);
  });

  testWidgets('enviada muestra 4 opciones y Le presté a alguien crea préstamo lent y gasto en Préstamos', (tester) async {
    final now = DateTime(2026, 10, 16, 12, 0);
    const sugId = 'sug-out-1';

    await db.into(db.suggestedTransactions).insert(
      SuggestedTransactionsCompanion.insert(
        id: sugId,
        type: TxType.expense,
        amount: 150000,
        merchant: const Value('PEDRO GOMEZ'),
        occurredAt: now,
        source: TxSource.capture,
        status: 'pending',
        rawText: const Value('Transferencia enviada a PEDRO GOMEZ Gs. 150.000'),
        fingerprint: const Value('email:msg-2'),
        captureMeta: Value(jsonEncode({
          'channel': 'email',
          'kind': 'transferOut',
          'counterparty': 'PEDRO GOMEZ',
        })),
        createdAt: now,
      ),
    );

    final sug = await (db.select(db.suggestedTransactions)..where((t) => t.id.equals(sugId))).getSingle();

    await tester.pumpWidget(
      createTestApp(
        db: db,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showTransferConfirmSheet(context, sug),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    // 4 opciones
    expect(find.text('Gasto'), findsOneWidget);
    expect(find.text('Le presté a alguien'), findsOneWidget);
    expect(find.text('Pagué una deuda'), findsOneWidget);
    expect(find.text('No contar'), findsOneWidget);

    // Seleccionar "Le presté a alguien"
    await tester.tap(find.text('Le presté a alguien'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    // Préstamo creado con dirección lent
    final loans = await (db.select(db.loans)..where((l) => l.closedAt.isNull())).get();
    expect(loans.length, 1);
    expect(loans.first.name, 'PEDRO GOMEZ');
    expect(loans.first.direction, LoanDirection.lent);
    expect(loans.first.totalAmount, 150000);

    // Gasto en categoría Préstamos
    final txs = await txRepo.getAllActive();
    expect(txs.length, 1);
    expect(txs.first.tx.type, TxType.expense);
    expect(txs.first.tx.amount, 150000);
    expect(txs.first.tx.categoryId, catPrestamosId);

    // Regla guardada con autoApply: false
    final rule = await rulesRepo.find('PEDRO GOMEZ', TransferDirection.outgoing);
    expect(rule, isNotNull);
    expect(rule!.action, CounterpartyAction.loanLent);
    expect(rule.autoApply, isFalse);

    // Sugerencia ya no pendiente
    final pending = await (db.select(db.suggestedTransactions)..where((t) => t.status.equals('pending'))).get();
    expect(pending, isEmpty);
  });

  testWidgets('No contar descarta sugerencia sin crear movimiento', (tester) async {
    final now = DateTime(2026, 10, 16, 14, 0);
    const sugId = 'sug-ign-1';

    await db.into(db.suggestedTransactions).insert(
      SuggestedTransactionsCompanion.insert(
        id: sugId,
        type: TxType.expense,
        amount: 80000,
        merchant: const Value('ALMACEN PRUEBA'),
        occurredAt: now,
        source: TxSource.capture,
        status: 'pending',
        rawText: const Value('Transferencia enviada Gs. 80.000'),
        fingerprint: const Value('email:msg-3'),
        captureMeta: Value(jsonEncode({
          'channel': 'email',
          'kind': 'transferOut',
          'counterparty': 'ALMACEN PRUEBA',
        })),
        createdAt: now,
      ),
    );

    final sug = await (db.select(db.suggestedTransactions)..where((t) => t.id.equals(sugId))).getSingle();

    await tester.pumpWidget(
      createTestApp(
        db: db,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showTransferConfirmSheet(context, sug),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No contar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    // Sin movimiento creado
    final txs = await txRepo.getAllActive();
    expect(txs, isEmpty);

    // Sugerencia descartada
    final pending = await (db.select(db.suggestedTransactions)..where((t) => t.status.equals('pending'))).get();
    expect(pending, isEmpty);

    // Regla ignore guardada
    final rule = await rulesRepo.find('ALMACEN PRUEBA', TransferDirection.outgoing);
    expect(rule, isNotNull);
    expect(rule!.action, CounterpartyAction.ignore);
  });

  testWidgets('tarjeta de correo muestra ícono envelope-simple', (tester) async {
    final now = DateTime(2026, 10, 16, 15, 0);
    const sugId = 'sug-email-card';

    await db.into(db.suggestedTransactions).insert(
      SuggestedTransactionsCompanion.insert(
        id: sugId,
        type: TxType.expense,
        amount: 40000,
        merchant: const Value('FARMACIA'),
        occurredAt: now,
        source: TxSource.capture,
        status: 'pending',
        rawText: const Value('Transferencia enviada Gs. 40.000'),
        fingerprint: const Value('email:msg-4'),
        captureMeta: Value(jsonEncode({
          'channel': 'email',
          'kind': 'transferOut',
          'counterparty': 'FARMACIA',
        })),
        createdAt: now,
      ),
    );

    final sugRow = await (db.select(db.suggestedTransactions)..where((t) => t.id.equals(sugId))).getSingle();
    final sugView = SuggestionView(suggestion: sugRow);

    await tester.pumpWidget(
      createTestApp(
        db: db,
        child: SuggestionCard(item: sugView),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(uiIcon('envelope-simple')), findsOneWidget);
  });

  testWidgets('tarjeta de correo de transferencia NO muestra Confirmar siempre este comercio, servicio sí lo muestra', (tester) async {
    final now = DateTime(2026, 10, 16, 16, 0);

    // 1. Transferencia enviada por correo (gasto a comercio/persona)
    await db.into(db.suggestedTransactions).insert(
      SuggestedTransactionsCompanion.insert(
        id: 'sug-email-out',
        type: TxType.expense,
        amount: 50000,
        merchant: const Value('FERNANDO GOMEZ'),
        occurredAt: now,
        source: TxSource.capture,
        status: 'pending',
        rawText: const Value('Transferencia enviada Gs. 50.000'),
        fingerprint: const Value('email:msg-tf-out'),
        captureMeta: Value(jsonEncode({
          'channel': 'email',
          'kind': 'transferOut',
          'counterparty': 'FERNANDO GOMEZ',
        })),
        createdAt: now,
      ),
    );

    // 2. Pago de servicio por correo (gasto)
    await db.into(db.suggestedTransactions).insert(
      SuggestedTransactionsCompanion.insert(
        id: 'sug-email-service',
        type: TxType.expense,
        amount: 85000,
        merchant: const Value('ANDE'),
        occurredAt: now,
        source: TxSource.capture,
        status: 'pending',
        rawText: const Value('Pago de servicios ANDE Gs. 85.000'),
        fingerprint: const Value('email:msg-srv'),
        captureMeta: Value(jsonEncode({
          'channel': 'email',
          'kind': 'servicePayment',
          'biller': 'ANDE',
        })),
        createdAt: now,
      ),
    );

    final rowTransfer = await (db.select(db.suggestedTransactions)..where((t) => t.id.equals('sug-email-out'))).getSingle();
    final rowService = await (db.select(db.suggestedTransactions)..where((t) => t.id.equals('sug-email-service'))).getSingle();

    // Probar tarjeta de transferencia
    await tester.pumpWidget(
      createTestApp(
        db: db,
        child: SuggestionCard(item: SuggestionView(suggestion: rowTransfer)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Confirmar siempre este comercio'), findsNothing);

    // Probar tarjeta de servicio
    await tester.pumpWidget(
      createTestApp(
        db: db,
        child: SuggestionCard(item: SuggestionView(suggestion: rowService)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Confirmar siempre este comercio'), findsOneWidget);
  });

  testWidgets('sin regla ni categoryId, transfer_confirm_sheet muestra Elegí una categoría y Confirmar está deshabilitado', (tester) async {
    final now = DateTime(2026, 10, 16, 17, 0);
    const sugId = 'sug-no-cat';

    await db.into(db.suggestedTransactions).insert(
      SuggestedTransactionsCompanion.insert(
        id: sugId,
        type: TxType.income,
        amount: 100000,
        merchant: const Value('CARLOS BOGADO'),
        occurredAt: now,
        source: TxSource.capture,
        status: 'pending',
        rawText: const Value('Transferencia recibida Gs. 100.000'),
        fingerprint: const Value('email:msg-no-cat'),
        captureMeta: Value(jsonEncode({
          'channel': 'email',
          'kind': 'transferIn',
          'counterparty': 'CARLOS BOGADO',
        })),
        createdAt: now,
      ),
    );

    final sug = await (db.select(db.suggestedTransactions)..where((t) => t.id.equals(sugId))).getSingle();

    await tester.pumpWidget(
      createTestApp(
        db: db,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showTransferConfirmSheet(context, sug),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    // Muestra 'Elegí una categoría' en vez de precargar una cualquiera
    expect(find.text('Elegí una categoría'), findsOneWidget);

    // Botón Confirmar deshabilitado (onPressed == null)
    final confirmBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Confirmar'));
    expect(confirmBtn.onPressed, isNull);

    // Cambiar a 'No contar' (no requiere categoría)
    await tester.tap(find.text('No contar'));
    await tester.pumpAndSettle();

    final confirmBtnAfterIgnore = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Confirmar'));
    expect(confirmBtnAfterIgnore.onPressed, isNotNull);

    // Volver a 'Ingreso' -> vuelve a estar deshabilitado
    await tester.tap(find.text('Ingreso'));
    await tester.pumpAndSettle();

    final confirmBtnAfterBack = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Confirmar'));
    expect(confirmBtnAfterBack.onPressed, isNull);
  });

  testWidgets('con regla recordada de esa persona, precarga su categoría y acción', (tester) async {
    final now = DateTime(2026, 10, 16, 18, 0);
    const sugId = 'sug-with-rule';

    // Regla guardada para ALICE GOMEZ
    await rulesRepo.upsert(
      nameKey: 'ALICE GOMEZ',
      direction: TransferDirection.incoming,
      action: CounterpartyAction.income,
      categoryId: catSueldoId,
      autoApply: false,
    );

    await db.into(db.suggestedTransactions).insert(
      SuggestedTransactionsCompanion.insert(
        id: sugId,
        type: TxType.income,
        amount: 200000,
        merchant: const Value('ALICE GOMEZ'),
        occurredAt: now,
        source: TxSource.capture,
        status: 'pending',
        rawText: const Value('Transferencia recibida Gs. 200.000'),
        fingerprint: const Value('email:msg-with-rule'),
        captureMeta: Value(jsonEncode({
          'channel': 'email',
          'kind': 'transferIn',
          'counterparty': 'ALICE GOMEZ',
        })),
        createdAt: now,
      ),
    );

    final sug = await (db.select(db.suggestedTransactions)..where((t) => t.id.equals(sugId))).getSingle();

    await tester.pumpWidget(
      createTestApp(
        db: db,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showTransferConfirmSheet(context, sug),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    // Precarga la categoría 'Sueldo' de la regla y Confirmar está habilitado
    expect(find.text('Sueldo'), findsOneWidget);
    final confirmBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Confirmar'));
    expect(confirmBtn.onPressed, isNotNull);
  });

  testWidgets('enviada sin regla ni categoryId muestra Elegí una categoría y Confirmar deshabilitado', (tester) async {
    final now = DateTime(2026, 10, 16, 19, 0);
    const sugId = 'sug-out-no-cat';

    await db.into(db.suggestedTransactions).insert(
      SuggestedTransactionsCompanion.insert(
        id: sugId,
        type: TxType.expense,
        amount: 80000,
        merchant: const Value('LUCAS SILVA'),
        occurredAt: now,
        source: TxSource.capture,
        status: 'pending',
        rawText: const Value('Transferencia enviada a LUCAS SILVA Gs. 80.000'),
        fingerprint: const Value('email:msg-out-no-cat'),
        captureMeta: Value(jsonEncode({
          'channel': 'email',
          'kind': 'transferOut',
          'counterparty': 'LUCAS SILVA',
        })),
        createdAt: now,
      ),
    );

    final sug = await (db.select(db.suggestedTransactions)..where((t) => t.id.equals(sugId))).getSingle();

    await tester.pumpWidget(
      createTestApp(
        db: db,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showTransferConfirmSheet(context, sug),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Elegí una categoría'), findsOneWidget);
    final confirmBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Confirmar'));
    expect(confirmBtn.onPressed, isNull);

    // Cambiar a "Le presté a alguien" -> se habilita porque no necesita categoría
    await tester.tap(find.text('Le presté a alguien'));
    await tester.pumpAndSettle();

    final confirmBtnAfterLent = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Confirmar'));
    expect(confirmBtnAfterLent.onPressed, isNotNull);
  });
}
