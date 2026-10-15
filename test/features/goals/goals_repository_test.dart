import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';

void main() {
  late AppDatabase db;
  late GoalsRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repo = GoalsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('crear meta, editar y archivar', () async {
    final goalId = await repo.createGoal(
      name: 'Fondo de emergencia',
      icon: 'shield-check',
      targetAmount: 10000000,
      targetDate: DateTime(2027, 1, 1),
    );

    var active = await repo.watchActive().first;
    expect(active.length, equals(1));
    expect(active.first.id, equals(goalId));
    expect(active.first.name, equals('Fondo de emergencia'));
    expect(active.first.icon, equals('shield-check'));
    expect(active.first.targetAmount, equals(10000000));
    expect(active.first.targetDate, equals(DateTime(2027, 1, 1)));
    expect(active.first.archived, isFalse);

    // Editar
    await repo.updateGoal(
      id: goalId,
      name: 'Fondo de emergencia ampliado',
      icon: 'piggy-bank',
      targetAmount: 15000000,
      targetDate: null,
    );

    active = await repo.watchActive().first;
    expect(active.first.name, equals('Fondo de emergencia ampliado'));
    expect(active.first.icon, equals('piggy-bank'));
    expect(active.first.targetAmount, equals(15000000));
    expect(active.first.targetDate, isNull);

    // Archivar
    await repo.archiveGoal(goalId, archived: true);

    active = await repo.watchActive().first;
    expect(active, isEmpty);

    final archived = await repo.watchArchived().first;
    expect(archived.length, equals(1));
    expect(archived.first.id, equals(goalId));

    // Desarchivar
    await repo.archiveGoal(goalId, archived: false);
    active = await repo.watchActive().first;
    expect(active.length, equals(1));
  });

  test('watchActiveWithProgress se actualiza al aportar', () async {
    final goalId = await repo.createGoal(
      name: 'PC Gamer',
      icon: 'laptop',
      targetAmount: 15000000,
    );
    final emitted = <int>[];
    final sub = repo.watchActiveWithProgress().listen(
      (list) => emitted.add(list.single.progress.saved),
    );
    await pumpEventQueue();

    await repo.addContribution(
      goalId: goalId,
      amount: 2000000,
      date: DateTime(2026, 10, 15),
    );
    await pumpEventQueue();
    await sub.cancel();

    expect(emitted.last, equals(2000000));
  });

  test('aportar y retirar (= aporte negativo) y vigilar historial', () async {
    final goalId = await repo.createGoal(
      name: 'Nueva notebook',
      icon: 'laptop',
      targetAmount: 7000000,
    );

    final contribId1 = await repo.addContribution(
      goalId: goalId,
      amount: 1500000,
      date: DateTime(2026, 10, 1),
      note: 'Ahorro mes 1',
    );

    final contribId2 = await repo.addContribution(
      goalId: goalId,
      amount: -500000,
      date: DateTime(2026, 10, 10),
      note: 'Retiro para imprevisto',
    );

    final contribs = await repo.watchContributions(goalId).first;
    expect(contribs.length, equals(2));
    // Más reciente primero
    expect(contribs.first.id, equals(contribId2));
    expect(contribs.first.amount, equals(-500000));
    expect(contribs.last.id, equals(contribId1));
    expect(contribs.last.amount, equals(1500000));

    // Borrar aporte
    await repo.deleteContribution(contribId2);
    final contribsAfterDelete = await repo.watchContributions(goalId).first;
    expect(contribsAfterDelete.length, equals(1));
    expect(contribsAfterDelete.first.amount, equals(1500000));
  });

  test(
    'watchActiveWithProgress emite lista de metas con su avance calculado',
    () async {
      final goalId = await repo.createGoal(
        name: 'Auto nuevo',
        icon: 'car',
        targetAmount: 20000000,
      );

      await repo.addContribution(
        goalId: goalId,
        amount: 5000000,
        date: DateTime.now(),
      );

      final list = await repo.watchActiveWithProgress().first;
      expect(list.length, equals(1));
      expect(list.first.goal.id, equals(goalId));
      expect(list.first.progress.saved, equals(5000000));
      expect(list.first.progress.remaining, equals(15000000));
      expect(list.first.progress.percent, equals(0.25));
    },
  );

  test('watchContributionsTotalSince y getContributionsTotalSince calculan neto desde una fecha', () async {
    final g1 = await repo.createGoal(
      name: 'G1',
      icon: 'gift',
      targetAmount: 1000000,
    );
    final g2 = await repo.createGoal(
      name: 'G2',
      icon: 'car',
      targetAmount: 1000000,
    );

    final periodStart = DateTime(2026, 10, 15);

    // Aporte antes del período (no debe contar)
    await repo.addContribution(
      goalId: g1,
      amount: 500000,
      date: DateTime(2026, 10, 10),
    );

    // Aportes dentro del período
    await repo.addContribution(
      goalId: g1,
      amount: 300000,
      date: DateTime(2026, 10, 16),
    );
    await repo.addContribution(
      goalId: g2,
      amount: 200000,
      date: DateTime(2026, 10, 18),
    );
    // Retiro dentro del período (-100.000)
    await repo.addContribution(
      goalId: g2,
      amount: -100000,
      date: DateTime(2026, 10, 19),
    );

    final total = await repo.getContributionsTotalSince(periodStart);
    // 300.000 + 200.000 - 100.000 = 400.000
    expect(total, equals(400000));

    final totalStream = await repo
        .watchContributionsTotalSince(periodStart)
        .first;
    expect(totalStream, equals(400000));
  });
}
