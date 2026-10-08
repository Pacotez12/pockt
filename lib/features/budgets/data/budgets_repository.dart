import 'package:drift/drift.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:uuid/uuid.dart';

class BudgetView {
  final Budget budget;
  final Category category;

  const BudgetView({
    required this.budget,
    required this.category,
  });
}

class BudgetsRepository {
  BudgetsRepository(this._db);

  final AppDatabase _db;

  Stream<List<BudgetView>> watchAll() {
    final query = _db.select(_db.budgets).join([
      innerJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.budgets.categoryId),
      ),
    ])..orderBy([
        OrderingTerm.asc(_db.categories.sortOrder),
      ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return BudgetView(
          budget: row.readTable(_db.budgets),
          category: row.readTable(_db.categories),
        );
      }).toList();
    });
  }

  Future<void> setLimit(String categoryId, int monthlyLimit) async {
    final existing = await (_db.select(_db.budgets)
          ..where((b) => b.categoryId.equals(categoryId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.budgets)..where((b) => b.id.equals(existing.id))).write(
        BudgetsCompanion(
          monthlyLimit: Value(monthlyLimit),
        ),
      );
    } else {
      await _db.into(_db.budgets).insert(
        BudgetsCompanion.insert(
          id: const Uuid().v7(),
          categoryId: categoryId,
          monthlyLimit: monthlyLimit,
        ),
      );
    }
  }

  Future<void> remove(String categoryId) async {
    await (_db.delete(_db.budgets)..where((b) => b.categoryId.equals(categoryId))).go();
  }

  Future<void> markAlertSent(
    String budgetId, {
    required int threshold,
    required String yearMonth,
  }) async {
    if (threshold == 80) {
      await (_db.update(_db.budgets)..where((b) => b.id.equals(budgetId))).write(
        BudgetsCompanion(
          alert80SentFor: Value(yearMonth),
        ),
      );
    } else if (threshold == 100) {
      await (_db.update(_db.budgets)..where((b) => b.id.equals(budgetId))).write(
        BudgetsCompanion(
          alert100SentFor: Value(yearMonth),
        ),
      );
    }
  }
}
