import 'package:drift/drift.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';

class CategoriesRepository {
  final AppDatabase db;

  CategoriesRepository(this.db);

  Stream<List<Category>> watchActive(CategoryKind kind) {
    return (db.select(db.categories)
          ..where((c) => c.archived.equals(false) & c.kind.equalsValue(kind))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .watch();
  }

  Future<void> archive(String id) {
    return (db.update(db.categories)..where((c) => c.id.equals(id))).write(
      const CategoriesCompanion(archived: Value(true)),
    );
  }
}
