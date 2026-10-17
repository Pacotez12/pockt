import 'package:drift/drift.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/capture/domain/itau_sms_parser.dart';
import 'package:pockt/features/entry/domain/natural_parser.dart';
import 'package:uuid/uuid.dart';

extension CaptureSuggestionExt on SuggestedTransaction {
  String? get duplicateTxId =>
      (source == TxSource.capture && (sourceRef?.startsWith('dup:') ?? false))
      ? sourceRef!.substring(4)
      : null;

  String? get linkedLoanId =>
      (source == TxSource.capture && (sourceRef?.startsWith('loan:') ?? false))
      ? sourceRef!.substring(5)
      : null;

  String? get linkedRecurringRuleId =>
      (source == TxSource.capture && (sourceRef?.startsWith('rule:') ?? false))
      ? sourceRef!.substring(5)
      : (source == TxSource.recurring ? sourceRef : null);

  bool get isPossibleDuplicate => duplicateTxId != null;
}

class SuggestionView {
  final SuggestedTransaction suggestion;
  final Category? category;

  const SuggestionView({required this.suggestion, this.category});
}

class SuggestionsRepository {
  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  SuggestionsRepository(this._db, {DateTime Function()? clock, Uuid? uuid})
    : _clock = clock ?? DateTime.now,
      _uuid = uuid ?? const Uuid();

  /// Emite sugerencias pendientes ordenadas por fecha más vieja primero.
  Stream<List<SuggestionView>> watchPending() {
    final query =
        _db.select(_db.suggestedTransactions).join([
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

  /// Inserta una sugerencia si no existe (usando el índice único en [source, sourceRef, occurredAt] o [fingerprint]).
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
    String? captureMeta,
  }) async {
    final now = _clock();
    try {
      final inserted = await _db
          .into(_db.suggestedTransactions)
          .insertReturningOrNull(
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
              captureMeta: Value(captureMeta),
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
    bool autoConfirmMerchant = false,
  }) async {
    return _db.transaction(() async {
      final sug = await (_db.select(
        _db.suggestedTransactions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (sug == null) {
        throw StateError('Suggestion not found: $id');
      }

      // Idempotencia: si ya estaba confirmada, devuelve el transactionId existente
      if (sug.status == 'confirmed' && sug.transactionId != null) {
        return sug.transactionId!;
      }

      String? finalCategoryId = categoryId ?? sug.categoryId;
      if (finalCategoryId == null && sug.type == TxType.transfer) {
        final otros =
            await (_db.select(_db.categories)
                  ..where(
                    (c) => c.id.equals('018f0000-0000-7000-8000-000000000010'),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (otros != null) {
          finalCategoryId = otros.id;
        } else {
          final firstCat = await (_db.select(
            _db.categories,
          )..limit(1)).getSingleOrNull();
          finalCategoryId = firstCat?.id;
        }
      }
      if (finalCategoryId == null) {
        throw StateError('Cannot confirm suggestion without a category');
      }

      final txId = _uuid.v4();
      final now = _clock();
      final finalAmount = amount ?? sug.amount;
      DateTime finalOccurredAt;
      if (occurredAt != null) {
        finalOccurredAt = occurredAt;
      } else if (sug.source == TxSource.capture) {
        finalOccurredAt = sug.occurredAt;
      } else {
        final sugLocal = toLocal(sug.occurredAt);
        final nowLocal = toLocal(now);
        final isToday =
            sugLocal.year == nowLocal.year &&
            sugLocal.month == nowLocal.month &&
            sugLocal.day == nowLocal.day;
        if (isToday) {
          finalOccurredAt = combineDayWithNow(sugLocal, nowLocal);
        } else {
          finalOccurredAt = DateTime(
            sugLocal.year,
            sugLocal.month,
            sugLocal.day,
            12,
            0,
          );
        }
      }

      await _db
          .into(_db.transactions)
          .insert(
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
              recurringRuleId: Value(sug.linkedRecurringRuleId),
              loanId: Value(sug.linkedLoanId),
            ),
          );

      if (sug.type == TxType.expense &&
          sug.merchant != null &&
          sug.merchant!.trim().isNotEmpty) {
        final mKey = extractMerchantKey(normalizeKeyword(sug.merchant!));
        if (mKey.isNotEmpty) {
          final existing =
              await (_db.select(_db.merchantMemory)..where(
                    (m) =>
                        m.merchantKey.equals(mKey) &
                        m.categoryId.equals(finalCategoryId!),
                  ))
                  .getSingleOrNull();
          if (existing != null) {
            await (_db.update(_db.merchantMemory)..where(
                  (m) =>
                      m.merchantKey.equals(mKey) &
                      m.categoryId.equals(finalCategoryId!),
                ))
                .write(
                  MerchantMemoryCompanion(
                    uses: Value(existing.uses + 1),
                    lastUsedAt: Value(finalOccurredAt),
                    autoConfirm: autoConfirmMerchant
                        ? const Value(true)
                        : const Value.absent(),
                  ),
                );
          } else {
            await _db
                .into(_db.merchantMemory)
                .insert(
                  MerchantMemoryCompanion.insert(
                    merchantKey: mKey,
                    categoryId: finalCategoryId,
                    uses: 1,
                    lastUsedAt: finalOccurredAt,
                    autoConfirm: Value(autoConfirmMerchant),
                  ),
                );
          }
        }
      }

      await (_db.update(
        _db.suggestedTransactions,
      )..where((t) => t.id.equals(id))).write(
        SuggestedTransactionsCompanion(
          status: const Value('confirmed'),
          transactionId: Value(txId),
        ),
      );

      return txId;
    });
  }

  /// "Es el mismo": descarta la sugerencia marcada como posible duplicado y la
  /// une al movimiento manual existente (spec §4.4).
  Future<void> resolveDuplicateAsSame(String id) async {
    await _db.transaction(() async {
      final sug = await (_db.select(
        _db.suggestedTransactions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (sug == null) return;

      final dupTxId = sug.duplicateTxId;
      await (_db.update(
        _db.suggestedTransactions,
      )..where((t) => t.id.equals(id))).write(
        SuggestedTransactionsCompanion(
          status: const Value('dismissed'),
          transactionId: Value(dupTxId),
        ),
      );

      if (dupTxId != null) {
        await (_db.update(_db.transactions)..where((t) => t.id.equals(dupTxId)))
            .write(TransactionsCompanion(suggestionId: Value(sug.id)));
      }
    });
  }

  /// Marca una sugerencia como descartada.
  Future<void> dismiss(String id) async {
    await (_db.update(
      _db.suggestedTransactions,
    )..where((t) => t.id.equals(id))).write(
      const SuggestedTransactionsCompanion(status: Value('dismissed')),
    );
  }
}
