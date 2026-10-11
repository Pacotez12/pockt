import 'package:drift/drift.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/settings/settings_repository.dart';

class CategoriesRepository {
  final AppDatabase db;
  final DateTime Function() _clock;

  CategoriesRepository(this.db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  Stream<List<Category>> watchActive(
    CategoryKind kind, {
    CategoryOrder order = CategoryOrder.manual,
  }) {
    if (order == CategoryOrder.manual) {
      return (db.select(db.categories)
            ..where((c) => c.archived.equals(false) & c.kind.equalsValue(kind))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .watch();
    }

    final cutoff = _clock().toUtc().subtract(const Duration(days: 90));
    final txCount = db.transactions.id.count();
    final query = db.select(db.categories).join([
      leftOuterJoin(
        db.transactions,
        db.transactions.categoryId.equalsExp(db.categories.id) &
            db.transactions.occurredAt.isBiggerOrEqualValue(cutoff) &
            db.transactions.deletedAt.isNull(),
      ),
    ])
      ..where(
          db.categories.archived.equals(false) & db.categories.kind.equalsValue(kind))
      ..groupBy([db.categories.id])
      ..orderBy([
        OrderingTerm.desc(txCount),
        OrderingTerm.asc(db.categories.sortOrder),
      ]);

    return query.watch().map((rows) => rows.map((r) => r.readTable(db.categories)).toList());
  }

  Future<void> archive(String id) {
    return (db.update(db.categories)..where((c) => c.id.equals(id))).write(
      const CategoriesCompanion(archived: Value(true)),
    );
  }
}
