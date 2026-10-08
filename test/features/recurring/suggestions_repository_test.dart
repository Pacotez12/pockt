import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';

void main() {
  late AppDatabase db;
  late SuggestionsRepository repo;
  const comidaId = '018f0000-0000-7000-8000-000000000001';

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    repo = SuggestionsRepository(
      db,
      clock: () => DateTime(2026, 10, 15, 12, 0),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('createIfAbsent es idempotente: doble llamada con mismo (source, sourceRef, occurredAt) devuelve false y deja 1 fila', () async {
    final date = DateTime(2026, 10, 15);
    final first = await repo.createIfAbsent(
      type: TxType.expense,
      amount: 150000,
      categoryId: comidaId,
      merchant: 'Superseis',
      occurredAt: date,
      source: TxSource.recurring,
      sourceRef: 'rule-123',
    );
    expect(first, isTrue);

    final second = await repo.createIfAbsent(
      type: TxType.expense,
      amount: 150000,
      categoryId: comidaId,
      merchant: 'Superseis',
      occurredAt: date,
      source: TxSource.recurring,
      sourceRef: 'rule-123',
    );
    expect(second, isFalse);

    final count = await repo.watchPendingCount().first;
    expect(count, 1);
  });

  test('watchPending devuelve lista ordenada con categoría', () async {
    await repo.createIfAbsent(
      type: TxType.expense,
      amount: 20000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 14),
      source: TxSource.recurring,
      sourceRef: 'rule-1',
    );

    await repo.createIfAbsent(
      type: TxType.expense,
      amount: 50000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 12), // Más vieja
      source: TxSource.recurring,
      sourceRef: 'rule-2',
    );

    final pending = await repo.watchPending().first;
    expect(pending, hasLength(2));
    // La más vieja primero (12/10 antes de 14/10)
    expect(pending[0].suggestion.amount, 50000);
    expect(pending[0].category?.name, 'Comida');
    expect(pending[1].suggestion.amount, 20000);
  });

  test('confirm crea movimiento, marca confirmed y doble confirm devuelve el mismo txId sin duplicar', () async {
    final date = DateTime(2026, 10, 15);
    await repo.createIfAbsent(
      type: TxType.expense,
      amount: 70000,
      categoryId: comidaId,
      merchant: 'Biggie',
      occurredAt: date,
      source: TxSource.recurring,
      sourceRef: 'rule-netflix',
    );

    final pending = await repo.watchPending().first;
    final sugId = pending.first.suggestion.id;

    // Primera confirmación
    final txId1 = await repo.confirm(sugId);
    expect(txId1, isNotEmpty);

    // Movimiento creado en transactions
    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));
    final tx = txs.first;
    expect(tx.id, txId1);
    expect(tx.amount, 70000);
    expect(tx.source, TxSource.recurring);
    expect(tx.suggestionId, sugId);
    expect(tx.recurringRuleId, 'rule-netflix');

    // Sugerencia marcada como confirmed
    final sug = await (db.select(db.suggestedTransactions)..where((t) => t.id.equals(sugId))).getSingle();
    expect(sug.status, 'confirmed');
    expect(sug.transactionId, txId1);

    // Ya no está en pendientes
    expect(await repo.watchPendingCount().first, 0);

    // Segunda confirmación (doble toque)
    final txId2 = await repo.confirm(sugId);
    expect(txId2, txId1);

    // No se duplicó el movimiento en transactions
    final txsAfter = await db.select(db.transactions).get();
    expect(txsAfter, hasLength(1));
  });

  test('dismiss saca la sugerencia de pendientes', () async {
    await repo.createIfAbsent(
      type: TxType.expense,
      amount: 10000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 10),
      source: TxSource.recurring,
      sourceRef: 'rule-x',
    );

    final pending = await repo.watchPending().first;
    final id = pending.first.suggestion.id;

    await repo.dismiss(id);

    final after = await repo.watchPending().first;
    expect(after, isEmpty);
    expect(await repo.watchPendingCount().first, 0);
  });
}
