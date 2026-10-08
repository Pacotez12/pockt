import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/recurring/data/recurring_repository.dart';
import 'package:pockt/features/recurring/domain/recurrence.dart';

void main() {
  late AppDatabase db;
  late RecurringRepository repo;
  const comidaId = '018f0000-0000-7000-8000-000000000001';

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    repo = RecurringRepository(
      db,
      clock: () => DateTime(2026, 10, 15, 9, 0),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('add calcula nextDueDate desde ayer (si hoy coincide, hoy es la primera)', () async {
    // Hoy es 15/10/2026. Si el recurrente es día 15, nextDueDate debe ser hoy 15/10/2026.
    final id = await repo.add(
      name: 'Internet',
      type: TxType.expense,
      amount: 180000,
      categoryId: comidaId,
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 15,
    );

    final all = await repo.watchAll().first;
    expect(all, hasLength(1));
    final rule = all.first;
    expect(rule.id, id);
    expect(rule.name, 'Internet');
    expect(rule.amount, 180000);
    expect(rule.nextDueDate, DateTime(2026, 10, 15));
    expect(rule.active, isTrue);
  });

  test('add cuando el día ya pasó este mes pone nextDueDate en el mes siguiente', () async {
    // Hoy es 15/10/2026. Si el recurrente es día 10, nextDueDate debe ser 10/11/2026.
    final id = await repo.add(
      name: 'Netflix',
      type: TxType.expense,
      amount: 55000,
      categoryId: comidaId,
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 10,
    );

    final rule = (await repo.watchAll().first).firstWhere((r) => r.id == id);
    expect(rule.nextDueDate, DateTime(2026, 11, 10));
  });

  test('setActive pausa y reactiva regla', () async {
    final id = await repo.add(
      name: 'Spotify',
      type: TxType.expense,
      amount: 40000,
      categoryId: comidaId,
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 20,
    );

    await repo.setActive(id, false);
    var rule = (await repo.watchAll().first).first;
    expect(rule.active, isFalse);

    await repo.setActive(id, true);
    rule = (await repo.watchAll().first).first;
    expect(rule.active, isTrue);
  });

  test('update actualiza campos de la regla', () async {
    final id = await repo.add(
      name: 'Gimnasio',
      type: TxType.expense,
      amount: 200000,
      categoryId: comidaId,
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 1,
    );

    await repo.update(id, amount: 250000, name: 'Gym Smart');
    final rule = (await repo.watchAll().first).first;
    expect(rule.amount, 250000);
    expect(rule.name, 'Gym Smart');
  });

  test('delete elimina la regla', () async {
    final id = await repo.add(
      name: 'Temporal',
      type: TxType.expense,
      amount: 10000,
      categoryId: comidaId,
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 5,
    );

    expect(await repo.watchAll().first, hasLength(1));
    await repo.delete(id);
    expect(await repo.watchAll().first, isEmpty);
  });
}
