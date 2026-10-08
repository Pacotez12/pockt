import 'package:drift/drift.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:uuid/uuid.dart';

class SuggestionView {
  final SuggestedTransaction suggestion;
  final Category? category;

  const SuggestionView({
    required this.suggestion,
    this.category,
  });
}

class SuggestionsRepository {
  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  SuggestionsRepository(
    this._db, {
    DateTime Function()? clock,
    Uuid? uuid,
  })  : _clock = clock ?? DateTime.now,
        _uuid = uuid ?? const Uuid();

  /// Emite sugerencias pendientes ordenadas por fecha más vieja primero.
  Stream<List<SuggestionView>> watchPending() {
    final query = _db.select(_db.suggestedTransactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.suggestedTransactions.categoryId),
      ),
    ])
      ..where(_db.suggestedTransactions.status.equals('pending'))
      ..orderBy([
        OrderingTerm.asc(_db.suggestedTransactions.occurredAt),
        OrderingTerm.asc(_db.suggestedTransactions.createdAt),
      ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return SuggestionView(
          suggestion: row.readTable(_db.suggestedTransactions),
          category: row.readTableOrNull(_db.categories),
        );
      }).toList();
    });
  }

  /// Emite la cantidad de sugerencias pendientes.
  Stream<int> watchPendingCount() {
    final countCol = _db.suggestedTransactions.id.count();
    final query = _db.selectOnly(_db.suggestedTransactions)
      ..addColumns([countCol])
      ..where(_db.suggestedTransactions.status.equals('pending'));

    return query.watchSingle().map((row) => row.read(countCol) ?? 0);
  }

  /// Inserta una sugerencia si no existe (usando el índice único en [source, sourceRef, occurredAt]).
  /// Devuelve `true` si fue creada o `false` si ya existía.
  Future<bool> createIfAbsent({
    required TxType type,
    required int amount,
    String currency = 'PYG',
    String? categoryId,
    String? merchant,
    required DateTime occurredAt,
    required TxSource source,
    String? sourceRef,
    String? rawText,
    String? fingerprint,
  }) async {
    final now = _clock();
    try {
      final inserted =
          await _db.into(_db.suggestedTransactions).insertReturningOrNull(
                SuggestedTransactionsCompanion.insert(
                  id: _uuid.v4(),
                  type: type,
                  amount: amount,
                  currency: Value(currency),
                  categoryId: Value(categoryId),
                  merchant: Value(merchant),
                  occurredAt: occurredAt,
                  source: source,
                  sourceRef: Value(sourceRef),
                  status: 'pending',
                  rawText: Value(rawText),
                  fingerprint: Value(fingerprint),
                  createdAt: now,
                ),
                mode: InsertMode.insertOrIgnore,
              );
      return inserted != null;
    } catch (_) {
      return false;
    }
  }

  /// En una sola transacción SQL:
  /// - Crea el movimiento en `transactions` con `source` según la sugerencia y `suggestionId`.
  /// - Marca la sugerencia como `confirmed` y guarda `transactionId`.
  /// Si ya estaba confirmada, devuelve el `transactionId` existente sin duplicar el movimiento.
  Future<String> confirm(
    String id, {
    int? amount,
    String? categoryId,
    DateTime? occurredAt,
  }) async {
    return _db.transaction(() async {
      final sug = await (_db.select(_db.suggestedTransactions)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();

      if (sug == null) {
        throw StateError('Suggestion not found: $id');
      }

      // Idempotencia: si ya estaba confirmada, devuelve el transactionId existente
      if (sug.status == 'confirmed' && sug.transactionId != null) {
        return sug.transactionId!;
      }

      final finalCategoryId = categoryId ?? sug.categoryId;
      if (finalCategoryId == null) {
        throw StateError('Cannot confirm suggestion without a category');
      }

      final txId = _uuid.v4();
      final now = _clock();
      final finalAmount = amount ?? sug.amount;
      final finalOccurredAt = occurredAt ?? sug.occurredAt;

      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: txId,
              type: sug.type,
              amount: finalAmount,
              currency: Value(sug.currency),
              categoryId: finalCategoryId,
              merchant: Value(sug.merchant),
              occurredAt: finalOccurredAt,
              createdAt: now,
              updatedAt: now,
              source: sug.source,
              suggestionId: Value(sug.id),
              recurringRuleId: Value(
                sug.source == TxSource.recurring ? sug.sourceRef : null,
              ),
            ),
          );

      await (_db.update(_db.suggestedTransactions)
            ..where((t) => t.id.equals(id)))
          .write(
        SuggestedTransactionsCompanion(
          status: const Value('confirmed'),
          transactionId: Value(txId),
        ),
      );

      return txId;
    });
  }

  /// Marca una sugerencia como descartada.
  Future<void> dismiss(String id) async {
    await (_db.update(_db.suggestedTransactions)
          ..where((t) => t.id.equals(id)))
        .write(
      const SuggestedTransactionsCompanion(
        status: Value('dismissed'),
      ),
    );
  }
}
