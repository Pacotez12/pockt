import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/features/budgets/data/budgets_repository.dart';
import 'package:pockt/features/income/data/income_schedule_repository.dart';
import 'package:pockt/features/recurring/data/recurring_repository.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/transactions/data/categories_repository.dart';
import 'package:pockt/features/transactions/data/keywords_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref.watch(databaseProvider));
});

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository(ref.watch(databaseProvider));
});

final keywordsRepositoryProvider = Provider<KeywordsRepository>((ref) {
  return KeywordsRepository(ref.watch(databaseProvider));
});

final incomeScheduleRepositoryProvider =
    Provider<IncomeScheduleRepository>((ref) {
  return IncomeScheduleRepository(ref.watch(databaseProvider));
});

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(ref.watch(databaseProvider));
});

final suggestionsRepositoryProvider = Provider<SuggestionsRepository>((ref) {
  return SuggestionsRepository(ref.watch(databaseProvider));
});

final budgetsRepositoryProvider = Provider<BudgetsRepository>((ref) {
  return BudgetsRepository(ref.watch(databaseProvider));
});

