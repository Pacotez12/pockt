import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:uuid/uuid.dart';

class CounterpartyRulesRepository {
  final AppDatabase _db;

  CounterpartyRulesRepository(this._db);

  Future<CounterpartyRule?> find(String nameKey, TransferDirection direction) {
    final query = _db.select(_db.counterpartyRules)
      ..where(
        (t) =>
            t.nameKey.equals(nameKey) & t.direction.equalsValue(direction),
      );
    return query.getSingleOrNull();
  }

  Future<void> upsert({
    required String nameKey,
    required TransferDirection direction,
    required CounterpartyAction action,
    String? categoryId,
    String? loanId,
    bool autoApply = false,
  }) async {
    final existing = await find(nameKey, direction);
    final now = DateTime.now();
    final id = existing?.id ?? const Uuid().v4();

    await _db.into(_db.counterpartyRules).insertOnConflictUpdate(
          CounterpartyRulesCompanion(
            id: Value(id),
            nameKey: Value(nameKey),
            direction: Value(direction),
            action: Value(action),
            categoryId: Value(categoryId),
            loanId: Value(loanId),
            autoApply: Value(autoApply),
            updatedAt: Value(now),
          ),
        );
  }

  Stream<List<CounterpartyRule>> watchAll() {
    final query = _db.select(_db.counterpartyRules)
      ..orderBy([(t) => OrderingTerm.asc(t.nameKey)]);
    return query.watch();
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.counterpartyRules)..where((t) => t.id.equals(id)))
        .go();
  }
}

final counterpartyRulesRepositoryProvider =
    Provider<CounterpartyRulesRepository>((ref) {
  return CounterpartyRulesRepository(ref.watch(databaseProvider));
});
