import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/entry/domain/natural_parser.dart';
import 'package:pockt/features/reports/domain/compare.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

class MonthTotals {
  final int year;
  final int month;
  final int expense;
  final int income;
  int get saving => income - expense;

  const MonthTotals({
    required this.year,
    required this.month,
    required this.expense,
    required this.income,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthTotals &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          expense == other.expense &&
          income == other.income;

  @override
  int get hashCode => Object.hash(year, month, expense, income);

  @override
  String toString() =>
      'MonthTotals(year: $year, month: $month, expense: $expense, income: $income, saving: $saving)';
}

class MerchantTotal {
  final String merchant;
  final int total;
  final int count;

  const MerchantTotal({
    required this.merchant,
    required this.total,
    required this.count,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MerchantTotal &&
          runtimeType == other.runtimeType &&
          merchant == other.merchant &&
          total == other.total &&
          count == other.count;

  @override
  int get hashCode => Object.hash(merchant, total, count);

  @override
  String toString() =>
      'MerchantTotal(merchant: $merchant, total: $total, count: $count)';
}

class ReportsRepository {
  final AppDatabase db;

  ReportsRepository(this.db);

  /// Emite los totales de gasto agrupados por categoría para [year] y [month],
  /// ordenados de mayor a menor total.
  Stream<List<CategoryTotal>> watchMonthByCategory(
    int year,
    int month, {
    DatePeriod? period,
  }) {
    final effectivePeriod = period ?? periodFor(DateTime(year, month, 1));
    final sumAmount = db.transactions.amount.sum();

    final query = db.select(db.categories).join([
      innerJoin(
        db.transactions,
        db.transactions.categoryId.equalsExp(db.categories.id) &
            db.transactions.deletedAt.isNull() &
            db.transactions.type.equalsValue(TxType.expense) &
            db.transactions.occurredAt
                .isBiggerOrEqualValue(effectivePeriod.startUtc) &
            db.transactions.occurredAt
                .isSmallerThanValue(effectivePeriod.endUtc),
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

  /// Emite la evolución de los últimos [months] meses (incluido el actual según [todayLocal]),
  /// ordenados del más viejo al más nuevo. Si un mes no tiene movimientos, se completa con 0.
  Stream<List<MonthTotals>> watchEvolution({
    required int months,
    required DateTime todayLocal,
  }) {
    if (months <= 0) {
      return Stream.value(const []);
    }

    final targetMonths = <({int year, int month})>[];
    for (var i = months - 1; i >= 0; i--) {
      var y = todayLocal.year;
      var m = todayLocal.month - i;
      while (m <= 0) {
        y--;
        m += 12;
      }
      targetMonths.add((year: y, month: m));
    }

    final oldest = targetMonths.first;
    final startUtc = monthRangeUtc(oldest.year, oldest.month).startUtc;
    final newest = targetMonths.last;
    final endUtc = monthRangeUtc(newest.year, newest.month).endUtc;

    final query = db.select(db.transactions)
      ..where((t) =>
          t.deletedAt.isNull() &
          t.occurredAt.isBiggerOrEqualValue(startUtc) &
          t.occurredAt.isSmallerThanValue(endUtc));

    return query.watch().map((txs) {
      // Agrupar transacciones por año y mes local
      final expenseMap = <(int, int), int>{};
      final incomeMap = <(int, int), int>{};

      for (final tx in txs) {
        final localDate = toLocal(tx.occurredAt);
        final key = (localDate.year, localDate.month);
        if (tx.type == TxType.expense) {
          expenseMap[key] = (expenseMap[key] ?? 0) + tx.amount;
        } else if (tx.type == TxType.income) {
          incomeMap[key] = (incomeMap[key] ?? 0) + tx.amount;
        }
      }

      return targetMonths.map((m) {
        final key = (m.year, m.month);
        return MonthTotals(
          year: m.year,
          month: m.month,
          expense: expenseMap[key] ?? 0,
          income: incomeMap[key] ?? 0,
        );
      }).toList();
    });
  }

  /// Emite los gastos agrupados por comercio normalizado para [year] y [month],
  /// ordenados de mayor a menor total y limitados a [limit].
  /// Muestra la grafía original más usada para cada comercio.
  Stream<List<MerchantTotal>> watchByMerchant(
    int year,
    int month, {
    int limit = 10,
    DatePeriod? period,
  }) {
    final effectivePeriod = period ?? periodFor(DateTime(year, month, 1));

    final query = db.select(db.transactions)
      ..where((t) =>
          t.deletedAt.isNull() &
          t.type.equalsValue(TxType.expense) &
          t.merchant.isNotNull() &
          t.occurredAt.isBiggerOrEqualValue(effectivePeriod.startUtc) &
          t.occurredAt.isSmallerThanValue(effectivePeriod.endUtc));

    return query.watch().map((txs) {
      final groups = <String, ({int total, Map<String, int> spellings})>{};

      for (final tx in txs) {
        final raw = tx.merchant?.trim();
        if (raw == null || raw.isEmpty) continue;
        final norm = normalizeKeyword(raw);
        if (norm.isEmpty) continue;

        final current = groups[norm];
        if (current == null) {
          groups[norm] = (
            total: tx.amount,
            spellings: {raw: 1},
          );
        } else {
          final spellings = current.spellings;
          spellings[raw] = (spellings[raw] ?? 0) + 1;
          groups[norm] = (
            total: current.total + tx.amount,
            spellings: spellings,
          );
        }
      }

      final list = groups.entries.map((e) {
        final spellings = e.value.spellings;
        var bestSpelling = spellings.keys.first;
        var bestCount = spellings.values.first;
        var totalCount = 0;

        for (final sEntry in spellings.entries) {
          totalCount += sEntry.value;
          if (sEntry.value > bestCount) {
            bestCount = sEntry.value;
            bestSpelling = sEntry.key;
          }
        }

        return MerchantTotal(
          merchant: bestSpelling,
          total: e.value.total,
          count: totalCount,
        );
      }).toList();

      list.sort((a, b) => b.total.compareTo(a.total));
      if (list.length > limit) {
        return list.sublist(0, limit);
      }
      return list;
    });
  }

  /// Emite la comparación del mes de [todayLocal] contra el mes anterior.
  Stream<Comparison> watchComparison({required DateTime todayLocal}) {
    final curYear = todayLocal.year;
    final curMonth = todayLocal.month;

    final prevYear = curMonth == 1 ? curYear - 1 : curYear;
    final prevMonth = curMonth == 1 ? 12 : curMonth - 1;

    final prevRange = monthRangeUtc(prevYear, prevMonth);
    final curRange = monthRangeUtc(curYear, curMonth);

    final query = db.select(db.transactions)
      ..where((t) =>
          t.deletedAt.isNull() &
          t.type.equalsValue(TxType.expense) &
          t.occurredAt.isBiggerOrEqualValue(prevRange.startUtc) &
          t.occurredAt.isSmallerThanValue(curRange.endUtc));

    return query.watch().map((txs) {
      final dailyMap = <DateTime, int>{};
      for (final tx in txs) {
        final local = toLocal(tx.occurredAt);
        final dayKey = DateTime(local.year, local.month, local.day);
        dailyMap[dayKey] = (dailyMap[dayKey] ?? 0) + tx.amount;
      }

      return compareToPreviousMonth(
        todayLocal: todayLocal,
        dailyExpenseByLocalDay: dailyMap,
      );
    });
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(databaseProvider));
});
