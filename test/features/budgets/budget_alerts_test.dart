import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/features/budgets/data/budgets_repository.dart';
import 'package:pockt/features/budgets/domain/budget_status.dart';
import 'package:pockt/features/recurring/data/recurring_repository.dart';
import 'package:pockt/features/recurring/domain/recurrence.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase db;
  late FakeNotifier notifier;
  late BudgetsRepository budgetsRepo;
  late TransactionsRepository txRepo;
  const comidaId = '018f0000-0000-7000-8000-000000000001';

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    notifier = FakeNotifier();
    budgetsRepo = BudgetsRepository(db, notifier: notifier);
    txRepo = TransactionsRepository(db, notifier: notifier);
  });

  tearDown(() async {
    await db.close();
  });

  test('alerta 80 % una sola vez en el mes aunque se agreguen más gastos', () async {
    await budgetsRepo.setLimit(comidaId, 1000000);

    // Gasto de 800.000 cruza el 80 %
    await evaluateBudgetAlerts(
      comidaId,
      nowLocal: DateTime(2026, 10, 10),
      db: db,
      notifier: notifier,
    );
    // Como aún no había transacciones en la DB, no debe notificar
    expect(notifier.shown, isEmpty);

    // Agregamos transacción de 800.000
    await txRepo.add(
      type: TxType.expense,
      amount: 800000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 10),
    );

    // txRepo ya disparó evaluateBudgetAlerts
    expect(notifier.shown, hasLength(1));
    expect(notifier.shown.first.body, 'Comida: llegaste al 80 % de tu presupuesto');

    // Nuevo gasto de 50.000 en el mismo mes (85 %) -> no re-notifica el 80 %
    await txRepo.add(
      type: TxType.expense,
      amount: 50000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 12),
    );

    expect(notifier.shown, hasLength(1));
  });

  test('mes siguiente vuelve a avisar la alerta de 80 %', () async {
    await budgetsRepo.setLimit(comidaId, 1000000);

    // Octubre: cruza 80 %
    await txRepo.add(
      type: TxType.expense,
      amount: 800000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 10),
    );
    expect(notifier.shown, hasLength(1));

    // Noviembre: nuevo mes, cruza 80 % de nuevo
    await txRepo.add(
      type: TxType.expense,
      amount: 850000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 11, 5),
    );
    expect(notifier.shown, hasLength(2));
    expect(notifier.shown.last.body, 'Comida: llegaste al 80 % de tu presupuesto');
  });

  test('cruzar de golpe al 100 % manda solo la de 100 %', () async {
    await budgetsRepo.setLimit(comidaId, 1000000);

    // Gasto directo de 1.012.000 (pasa de 0 a >100 %, excedido en 12.000)
    await txRepo.add(
      type: TxType.expense,
      amount: 1012000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 15),
    );

    expect(notifier.shown, hasLength(1));
    expect(notifier.shown.first.body, 'Comida: te pasaste por Gs. 12.000');
  });

  test('cruce de 80 % y luego 100 % en el mismo mes envía ambas alertas una sola vez', () async {
    await budgetsRepo.setLimit(comidaId, 1000000);

    // Primero 80 %
    await txRepo.add(
      type: TxType.expense,
      amount: 800000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 10),
    );
    expect(notifier.shown, hasLength(1));
    expect(notifier.shown[0].body, 'Comida: llegaste al 80 % de tu presupuesto');

    // Luego cruza 100 %
    await txRepo.add(
      type: TxType.expense,
      amount: 250000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 12),
    );
    expect(notifier.shown, hasLength(2));
    expect(notifier.shown[1].body, 'Comida: te pasaste por Gs. 50.000');

    // Otro gasto adicional en el mismo mes no genera más alertas
    await txRepo.add(
      type: TxType.expense,
      amount: 50000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 14),
    );
    expect(notifier.shown, hasLength(2));
  });

  test('ensurePermission se solicita al crear el primer presupuesto y el primer recurrente', () async {
    expect(notifier.permissionRequestedCount, 0);

    // Primer presupuesto pide permiso
    await budgetsRepo.setLimit(comidaId, 500000);
    expect(notifier.permissionRequestedCount, 1);

    // Segundo presupuesto no vuelve a pedir
    await budgetsRepo.setLimit('018f0000-0000-7000-8000-000000000002', 300000);
    expect(notifier.permissionRequestedCount, 1);

    // Primer recurrente pide permiso
    final recurringRepo = RecurringRepository(db, notifier: notifier);
    await recurringRepo.add(
      name: 'Internet',
      type: TxType.expense,
      amount: 150000,
      categoryId: comidaId,
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 10,
    );
    expect(notifier.permissionRequestedCount, 2);

    // Segundo recurrente no vuelve a pedir
    await recurringRepo.add(
      name: 'Luz',
      type: TxType.expense,
      amount: 200000,
      categoryId: comidaId,
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 15,
    );
    expect(notifier.permissionRequestedCount, 2);
  });
}
