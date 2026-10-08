import 'package:drift/drift.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:uuid/uuid.dart';

class TxView {
  final Transaction tx;
  final Category category;

  TxView({required this.tx, required this.category});
}

class CategoryTotal {
  final Category category;
  final int total;

  CategoryTotal({required this.category, required this.total});
}

class TransactionsRepository {
  final AppDatabase db;
  final DateTime Function() _clock;

  TransactionsRepository(this.db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  DateTime _now() => _clock().toUtc();

  Future<String> add({
    required TxType type,
    required int amount,
    required String categoryId,
    required DateTime occurredAt,
    String? merchant,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Amount must be positive');
    }

    final id = const Uuid().v4();
    final now = _now();

    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: id,
            type: type,
            amount: amount,
            categoryId: categoryId,
            occurredAt: occurredAt.toUtc(),
            createdAt: now,
            updatedAt: now,
            source: TxSource.manual,
            merchant: Value(merchant),
            note: Value(note),
          ),
        );

    return id;
  }

  Future<void> update(
    String id, {
    int? amount,
    String? categoryId,
    DateTime? occurredAt,
    String? merchant,
    String? note,
  }) async {
    if (amount != null && amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Amount must be positive');
    }

    final companion = TransactionsCompanion(
      amount: amount != null ? Value(amount) : const Value.absent(),
      categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
      occurredAt: occurredAt != null ? Value(occurredAt.toUtc()) : const Value.absent(),
      merchant: merchant != null ? Value(merchant) : const Value.absent(),
      note: note != null ? Value(note) : const Value.absent(),
      updatedAt: Value(_now()),
    );

    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(companion);
  }

  Future<void> softDelete(String id) async {
    final now = _now();
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> restore(String id) async {
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(_now()),
      ),
    );
  }

  Stream<int> watchMonthTotal(int year, int month, TxType type) {
    final range = monthRangeUtc(year, month);
    final sumAmount = db.transactions.amount.sum();
    final query = db.selectOnly(db.transactions)
      ..addColumns([sumAmount])
      ..where(
        db.transactions.deletedAt.isNull() &
            db.transactions.type.equalsValue(type) &
            db.transactions.occurredAt.isBiggerOrEqualValue(range.startUtc) &
            db.transactions.occurredAt.isSmallerThanValue(range.endUtc),
      );

    return query.watchSingle().map((row) => row.read(sumAmount) ?? 0);
  }

  Stream<List<CategoryTotal>> watchMonthCategoryTotals(int year, int month) {
    final range = monthRangeUtc(year, month);
    final sumAmount = db.transactions.amount.sum();

    final query = db.select(db.categories).join([
      innerJoin(
        db.transactions,
        db.transactions.categoryId.equalsExp(db.categories.id) &
            db.transactions.deletedAt.isNull() &
            db.transactions.type.equalsValue(TxType.expense) &
            db.transactions.occurredAt.isBiggerOrEqualValue(range.startUtc) &
            db.transactions.occurredAt.isSmallerThanValue(range.endUtc),
      ),
    ])
      ..addColumns([sumAmount])
      ..groupBy([db.categories.id])
      ..orderBy([OrderingTerm.desc(sumAmount)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final category = row.readTable(db.categories);
        final total = row.read(sumAmount) ?? 0;
        return CategoryTotal(category: category, total: total);
      }).toList();
    });
  }

  Stream<Map<int, int>> watchDailyExpenseTotals(int year, int month) {
    final range = monthRangeUtc(year, month);
    final query = db.select(db.transactions)
      ..where((t) =>
          t.deletedAt.isNull() &
          t.type.equalsValue(TxType.expense) &
          t.occurredAt.isBiggerOrEqualValue(range.startUtc) &
          t.occurredAt.isSmallerThanValue(range.endUtc));

    return query.watch().map((txs) {
      final map = <int, int>{};
      for (final tx in txs) {
        final localDt = toLocal(tx.occurredAt);
        if (localDt.year == year && localDt.month == month) {
          final day = localDt.day;
          map[day] = (map[day] ?? 0) + tx.amount;
        }
      }
      map.removeWhere((key, value) => value <= 0);
      return map;
    });
  }

  Stream<List<TxView>> watchRecent({int limit = 20}) {
    final query = db.select(db.transactions).join([
      innerJoin(db.categories, db.categories.id.equalsExp(db.transactions.categoryId)),
    ])
      ..where(db.transactions.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(db.transactions.occurredAt)])
      ..limit(limit);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TxView(
          tx: row.readTable(db.transactions),
          category: row.readTable(db.categories),
        );
      }).toList();
    });
  }

  Stream<List<TxView>> watchDay(DateTime localDay) {
    final range = dayRangeUtc(localDay);
    final query = db.select(db.transactions).join([
      innerJoin(db.categories, db.categories.id.equalsExp(db.transactions.categoryId)),
    ])
      ..where(
        db.transactions.deletedAt.isNull() &
            db.transactions.occurredAt.isBiggerOrEqualValue(range.startUtc) &
            db.transactions.occurredAt.isSmallerThanValue(range.endUtc),
      )
      ..orderBy([OrderingTerm.desc(db.transactions.occurredAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TxView(
          tx: row.readTable(db.transactions),
          category: row.readTable(db.categories),
        );
      }).toList();
    });
  }

  Stream<List<TxView>> watchFiltered({
    String? query,
    Set<String>? categoryIds,
    TxType? type,
    DateTime? fromLocal,
    DateTime? toLocal,
  }) {
    Expression<bool> predicate = db.transactions.deletedAt.isNull();

    if (categoryIds != null && categoryIds.isNotEmpty) {
      predicate = predicate & db.transactions.categoryId.isIn(categoryIds);
    }

    if (type != null) {
      predicate = predicate & db.transactions.type.equalsValue(type);
    }

    if (fromLocal != null) {
      final startUtc = dayRangeUtc(fromLocal).startUtc;
      predicate = predicate & db.transactions.occurredAt.isBiggerOrEqualValue(startUtc);
    }

    if (toLocal != null) {
      final endUtc = dayRangeUtc(toLocal).endUtc;
      predicate = predicate & db.transactions.occurredAt.isSmallerThanValue(endUtc);
    }

    if (query != null && query.trim().isNotEmpty) {
      final cleanQuery = '%${query.trim().toLowerCase()}%';
      predicate = predicate &
          (db.transactions.merchant.lower().like(cleanQuery) |
              db.transactions.note.lower().like(cleanQuery));
    }

    final joined = db.select(db.transactions).join([
      innerJoin(db.categories, db.categories.id.equalsExp(db.transactions.categoryId)),
    ])
      ..where(predicate)
      ..orderBy([OrderingTerm.desc(db.transactions.occurredAt)]);

    return joined.watch().map((rows) {
      return rows.map((row) {
        return TxView(
          tx: row.readTable(db.transactions),
          category: row.readTable(db.categories),
        );
      }).toList();
    });
  }
}
