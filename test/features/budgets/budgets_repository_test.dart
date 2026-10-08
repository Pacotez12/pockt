import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/features/budgets/data/budgets_repository.dart';

void main() {
  late AppDatabase db;
  late BudgetsRepository repo;
  const comidaId = '018f0000-0000-7000-8000-000000000001';

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    repo = BudgetsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('setLimit crea o actualiza tope de categoría', () async {
    await repo.setLimit(comidaId, 1500000);

    var list = await repo.watchAll().first;
    expect(list, hasLength(1));
    expect(list.first.budget.monthlyLimit, 1500000);
    expect(list.first.category.name, 'Comida');

    // Actualizar mismo categoryId
    await repo.setLimit(comidaId, 1800000);
    list = await repo.watchAll().first;
    expect(list, hasLength(1));
    expect(list.first.budget.monthlyLimit, 1800000);
  });

  test('markAlertSent actualiza alert80SentFor o alert100SentFor', () async {
    await repo.setLimit(comidaId, 2000000);
    var list = await repo.watchAll().first;
    final budgetId = list.first.budget.id;

    await repo.markAlertSent(budgetId, threshold: 80, yearMonth: '2026-10');
    list = await repo.watchAll().first;
    expect(list.first.budget.alert80SentFor, '2026-10');
    expect(list.first.budget.alert100SentFor, isNull);

    await repo.markAlertSent(budgetId, threshold: 100, yearMonth: '2026-10');
    list = await repo.watchAll().first;
    expect(list.first.budget.alert80SentFor, '2026-10');
    expect(list.first.budget.alert100SentFor, '2026-10');
  });

  test('remove elimina el presupuesto de la categoría', () async {
    await repo.setLimit(comidaId, 1000000);
    expect(await repo.watchAll().first, hasLength(1));

    await repo.remove(comidaId);
    expect(await repo.watchAll().first, isEmpty);
  });
}
