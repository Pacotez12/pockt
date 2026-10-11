import 'package:drift/drift.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';

enum BudgetLevel { ok, warning, over }

class BudgetStatus {
  final BudgetLevel level;
  final double ratio;
  final int remaining;

  const BudgetStatus({
    required this.level,
    required this.ratio,
    required this.remaining,
  });
}

BudgetStatus budgetStatus(int spent, int limit) {
  final ratio = limit > 0 ? spent / limit : (spent > 0 ? 1.0 : 0.0);
  final remaining = limit - spent;
  final BudgetLevel level;
  if (ratio >= 1.0) {
    level = BudgetLevel.over;
  } else if (ratio >= 0.8) {
    level = BudgetLevel.warning;
  } else {
    level = BudgetLevel.ok;
  }
  return BudgetStatus(
    level: level,
    ratio: ratio,
    remaining: remaining,
  );
}

Future<void> evaluateBudgetAlerts(
  String categoryId, {
  required DateTime nowLocal,
  required AppDatabase db,
  required Notifier notifier,
  DatePeriod? period,
}) async {
  final budget = await (db.select(db.budgets)
        ..where((b) => b.categoryId.equals(categoryId)))
      .getSingleOrNull();

  if (budget == null) return;

  final category = await (db.select(db.categories)
        ..where((c) => c.id.equals(categoryId)))
      .getSingleOrNull();
  final categoryName = category?.name ?? 'Categoría';

  final effectivePeriod = period ??
      await () async {
        final setting = await (db.select(db.settings)
              ..where((s) => s.key.equals(SettingsKeys.periodMonthStart)))
            .getSingleOrNull();
        final mode = MonthStartMode.parse(setting?.value);
        final sched = await (db.select(db.incomeSchedules)
              ..orderBy([(t) => OrderingTerm.desc(t.effectiveFrom)])
              ..limit(1))
            .getSingleOrNull();
        return periodFor(nowLocal, mode: mode, schedule: sched);
      }();

  final txs = await (db.select(db.transactions)
        ..where((t) =>
            t.categoryId.equals(categoryId) &
            t.type.equalsValue(TxType.expense) &
            t.deletedAt.isNull() &
            t.occurredAt.isBiggerOrEqualValue(effectivePeriod.startUtc) &
            t.occurredAt.isSmallerThanValue(effectivePeriod.endUtc)))
      .get();

  final totalSpent = txs.fold<int>(0, (sum, t) => sum + t.amount);
  final status = budgetStatus(totalSpent, budget.monthlyLimit);
  final yearMonth =
      '${nowLocal.year}-${nowLocal.month.toString().padLeft(2, '0')}';

  if (status.level == BudgetLevel.over) {
    if (budget.alert100SentFor != yearMonth) {
      final overAmount = totalSpent - budget.monthlyLimit;
      final body = overAmount > 0
          ? '$categoryName: te pasaste por ${formatGs(overAmount)}'
          : '$categoryName: llegaste al 100 % de tu presupuesto';

      await notifier.show('Pockt', body, payload: 'budget:$categoryId');
      await (db.update(db.budgets)..where((b) => b.id.equals(budget.id))).write(
        BudgetsCompanion(
          alert100SentFor: Value(yearMonth),
        ),
      );
    }
  } else if (status.level == BudgetLevel.warning) {
    if (budget.alert80SentFor != yearMonth) {
      final body = '$categoryName: llegaste al 80 % de tu presupuesto';

      await notifier.show('Pockt', body, payload: 'budget:$categoryId');
      await (db.update(db.budgets)..where((b) => b.id.equals(budget.id))).write(
        BudgetsCompanion(
          alert80SentFor: Value(yearMonth),
        ),
      );
    }
  }
}
