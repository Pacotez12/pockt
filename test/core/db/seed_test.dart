import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/transactions/data/categories_repository.dart';

void main() {
  late AppDatabase db;
  late CategoriesRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CategoriesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('seed: 10 categorías de gasto y 3 de ingreso', () async {
    final expenses = await repo.watchActive(CategoryKind.expense).first;
    final incomes = await repo.watchActive(CategoryKind.income).first;
    expect(expenses, hasLength(10));
    expect(incomes, hasLength(3));
  });
}
