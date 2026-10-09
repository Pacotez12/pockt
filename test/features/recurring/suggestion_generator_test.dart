import 'dart:convert';
import 'package:drift/drift.dart' show DatabaseConnection, OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/features/recurring/domain/suggestion_generator.dart';

void main() {
  late AppDatabase db;
  late FakeNotifier notifier;
  const comidaId = '018f0000-0000-7000-8000-000000000001';
  const sueldoId = '018f0000-0000-7000-8000-000000000011';

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    notifier = FakeNotifier();
  });

  tearDown(() async {
    await db.close();
  });

  test('catch-up de 3 meses de una recurrente genera 3 sugerencias y avanza nextDueDate al mes siguiente', () async {
    // Regla mensual con nextDueDate el 15/08/2026
    await db.into(db.recurringRules).insert(
          RecurringRulesCompanion.insert(
            id: 'rule-netflix',
            name: 'Netflix',
            type: TxType.expense,
            amount: 50000,
            categoryId: comidaId,
            frequency: 'monthly',
            dayOfMonth: const Value(15),
            nextDueDate: DateTime(2026, 8, 15),
            active: const Value(true),
          ),
        );

    final generator = SuggestionGenerator(
      db,
      notifier,
      clock: () => DateTime(2026, 10, 15, 10, 0),
    );

    final count = await generator.run();
    expect(count, 3);

    // 3 sugerencias pendientes generadas (15/08, 15/09, 15/10)
    final sugs = await (db.select(db.suggestedTransactions)
          ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
        .get();
    expect(sugs, hasLength(3));
    expect(sugs[0].occurredAt, DateTime(2026, 8, 15));
    expect(sugs[1].occurredAt, DateTime(2026, 9, 15));
    expect(sugs[2].occurredAt, DateTime(2026, 10, 15));
    expect(sugs.every((s) => s.source == TxSource.recurring), isTrue);
    expect(sugs.every((s) => s.sourceRef == 'rule-netflix'), isTrue);

    // nextDueDate avanzado al mes siguiente: 15/11/2026
    final rule = await (db.select(db.recurringRules)..where((r) => r.id.equals('rule-netflix'))).getSingle();
    expect(rule.nextDueDate, DateTime(2026, 11, 15));

    // Notificación enviada con el número 3
    expect(notifier.shown, hasLength(1));
    expect(notifier.shown.first.body, 'Tenés 3 movimientos por confirmar');
  });

  test('run() dos veces el mismo día es estrictamente idempotente: la segunda devuelve 0', () async {
    await db.into(db.recurringRules).insert(
          RecurringRulesCompanion.insert(
            id: 'rule-spotify',
            name: 'Spotify',
            type: TxType.expense,
            amount: 35000,
            categoryId: comidaId,
            frequency: 'monthly',
            dayOfMonth: const Value(10),
            nextDueDate: DateTime(2026, 10, 10),
            active: const Value(true),
          ),
        );

    final generator = SuggestionGenerator(
      db,
      notifier,
      clock: () => DateTime(2026, 10, 10, 14, 0),
    );

    final firstCount = await generator.run();
    expect(firstCount, 1);
    expect(notifier.shown, hasLength(1));

    // Segunda ejecución el mismo día
    final secondCount = await generator.run();
    expect(secondCount, 0);
    // No se envía otra notificación
    expect(notifier.shown, hasLength(1));

    final totalSugs = await db.select(db.suggestedTransactions).get();
    expect(totalSugs, hasLength(1));
  });

  test('cobro quincenal desde 1/10 con hoy 16/10 genera una sugerencia el 15/10', () async {
    await db.into(db.incomeSchedules).insert(
          IncomeSchedulesCompanion.insert(
            id: 'sched-1',
            mode: 'biweekly',
            payDays: jsonEncode([15, -1]),
            payDayRules: jsonEncode(['either', 'previous']),
            monthlyAmount: const Value(8000000),
            paySplitPercents: jsonEncode([50, 50]),
            categoryId: sueldoId,
            effectiveFrom: DateTime(2026, 10, 1),
          ),
        );

    final generator = SuggestionGenerator(
      db,
      notifier,
      clock: () => DateTime(2026, 10, 16, 9, 0),
    );

    final count = await generator.run();
    expect(count, 1);

    final sugs = await db.select(db.suggestedTransactions).get();
    expect(sugs, hasLength(1));
    final sug = sugs.first;
    expect(sug.type, TxType.income);
    expect(sug.source, TxSource.incomeSchedule);
    expect(sug.sourceRef, 'sched-1');
    expect(sug.occurredAt, DateTime(2026, 10, 15));
    expect(sug.amount, 4000000);
    expect(sug.categoryId, sueldoId);

    expect(notifier.shown, hasLength(1));
    expect(notifier.shown.first.body, 'Tenés 1 movimiento por confirmar');

    // Idempotencia: segunda corrida el mismo día devuelve 0
    final second = await generator.run();
    expect(second, 0);
  });

  test('el generador crea 2100000 el 15 y 4900000 el último día con [30, 70]', () async {
    await db.into(db.incomeSchedules).insert(
          IncomeSchedulesCompanion.insert(
            id: 'sched-split',
            mode: 'biweekly',
            payDays: jsonEncode([15, -1]),
            payDayRules: jsonEncode(['previous', 'previous']),
            monthlyAmount: const Value(7000000),
            paySplitPercents: jsonEncode([30, 70]),
            categoryId: sueldoId,
            effectiveFrom: DateTime(2026, 10, 1),
          ),
        );

    final generator = SuggestionGenerator(
      db,
      notifier,
      clock: () => DateTime(2026, 10, 31, 10, 0),
    );

    final count = await generator.run();
    expect(count, 2);

    final sugs = await db.select(db.suggestedTransactions).get();
    expect(sugs, hasLength(2));

    final sug15 = sugs.firstWhere((s) => s.occurredAt.day == 15);
    expect(sug15.amount, equals(2100000));

    // El 31/10/2026 es sábado; con regla 'previous' se corrió al viernes 30/10
    final sugLast = sugs.firstWhere((s) => s.occurredAt.day == 30);
    expect(sugLast.amount, equals(4900000));
  });

  test('si no hay nuevas sugerencias no se envía notificación', () async {
    final generator = SuggestionGenerator(
      db,
      notifier,
      clock: () => DateTime(2026, 10, 15),
    );

    final count = await generator.run();
    expect(count, 0);
    expect(notifier.shown, isEmpty);
  });

  test('regla inactiva o fecha futura no genera sugerencias', () async {
    await db.into(db.recurringRules).insert(
          RecurringRulesCompanion.insert(
            id: 'rule-inactive',
            name: 'Gimnasio',
            type: TxType.expense,
            amount: 200000,
            categoryId: comidaId,
            frequency: 'monthly',
            dayOfMonth: const Value(5),
            nextDueDate: DateTime(2026, 10, 5),
            active: const Value(false),
          ),
        );

    await db.into(db.recurringRules).insert(
          RecurringRulesCompanion.insert(
            id: 'rule-future',
            name: 'Seguro',
            type: TxType.expense,
            amount: 300000,
            categoryId: comidaId,
            frequency: 'monthly',
            dayOfMonth: const Value(25),
            nextDueDate: DateTime(2026, 10, 25),
            active: const Value(true),
          ),
        );

    final generator = SuggestionGenerator(
      db,
      notifier,
      clock: () => DateTime(2026, 10, 15),
    );

    final count = await generator.run();
    expect(count, 0);
    expect(notifier.shown, isEmpty);
  });

  test('esquema de cobro sin monto esperado genera sugerencia con monto 0', () async {
    await db.into(db.incomeSchedules).insert(
          IncomeSchedulesCompanion.insert(
            id: 'sched-variable',
            mode: 'monthly',
            payDays: jsonEncode([-1]),
            payDayRules: jsonEncode(['previous']),
            monthlyAmount: const Value(null),
            paySplitPercents: jsonEncode([100]),
            categoryId: sueldoId,
            effectiveFrom: DateTime(2026, 10, 1),
          ),
        );

    final generator = SuggestionGenerator(
      db,
      notifier,
      clock: () => DateTime(2026, 10, 31),
    );

    final count = await generator.run();
    expect(count, 1);

    final sugs = await db.select(db.suggestedTransactions).get();
    expect(sugs.first.amount, 0);
  });
}

