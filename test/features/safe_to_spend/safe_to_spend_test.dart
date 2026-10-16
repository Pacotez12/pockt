import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/goals/domain/goal_progress.dart';
import 'package:pockt/features/safe_to_spend/domain/safe_to_spend.dart';

void main() {
  group('safeToSpendToday pure domain calculation', () {
    test('sin esquema de cobro (usa fin de mes): reparte quedan entre los días restantes hasta fin de mes', () {
      // 15 de octubre en un mes de 31 días.
      // Días hasta fin de mes (31 de octubre): 31 - 15 = 16 días.
      final today = DateTime(2026, 10, 15);
      final result = safeToSpendToday(
        todayLocal: today,
        remaining: 1600000,
        nextPayDate: null, // Sin esquema de cobro -> fin de mes
      );

      expect(result.daysUntilPay, equals(16));
      expect(result.hasIncomeSchedule, isFalse);
      // 1.600.000 / 16 días = 100.000 / día
      expect(result.amount, equals(100000));
      expect(result.quedan, equals(1600000));
    });

    test(
      'sin esquema de cobro en el último día del mes: divisor mínimo 1 día',
      () {
        // 31 de octubre. Días hasta fin de mes: 0. Divisor mínimo 1.
        final today = DateTime(2026, 10, 31);
        final result = safeToSpendToday(
          todayLocal: today,
          remaining: 500000,
          nextPayDate: null,
        );

        expect(result.daysUntilPay, equals(0));
        expect(result.amount, equals(500000));
      },
    );

    test('con fecha de cobro (esquema quincenal/mensual): divide por los días hasta el cobro', () {
      // 10 de octubre, cobra el 20 de octubre (10 días)
      final today = DateTime(2026, 10, 10);
      final nextPay = DateTime(2026, 10, 20);
      final result = safeToSpendToday(
        todayLocal: today,
        remaining: 2000000,
        nextPayDate: nextPay,
      );

      expect(result.daysUntilPay, equals(10));
      expect(result.hasIncomeSchedule, isTrue);
      // 2.000.000 / 10 = 200.000
      expect(result.amount, equals(200000));
    });

    test('con recurrentes pendientes antes del cobro: descuenta del numerador', () {
      // 10 de octubre, cobra el 20 de octubre (10 días).
      // Regla recurrente de gasto vence el 15 de octubre por 300.000.
      // Regla después del cobro vence el 25 de octubre por 150.000 (no cuenta).
      // Regla inactiva vence el 12 de octubre por 100.000 (no cuenta).
      final today = DateTime(2026, 10, 10);
      final nextPay = DateTime(2026, 10, 20);

      final rules = [
        RecurringRule(
          id: 'r1',
          name: 'Internet',
          type: TxType.expense,
          amount: 300000,
          categoryId: 'servicios',
          frequency: 'monthly',
          nextDueDate: DateTime(2026, 10, 15),
          active: true,
        ),
        RecurringRule(
          id: 'r2',
          name: 'Gimnasio',
          type: TxType.expense,
          amount: 150000,
          categoryId: 'salud',
          frequency: 'monthly',
          nextDueDate: DateTime(2026, 10, 25), // Posterior al cobro
          active: true,
        ),
        RecurringRule(
          id: 'r3',
          name: 'Streaming cancelado',
          type: TxType.expense,
          amount: 100000,
          categoryId: 'ocio',
          frequency: 'monthly',
          nextDueDate: DateTime(2026, 10, 12),
          active: false, // Inactivo
        ),
      ];

      final result = safeToSpendToday(
        todayLocal: today,
        remaining: 1500000,
        nextPayDate: nextPay,
        recurringRules: rules,
      );

      expect(result.pendingRecurring, equals(300000));
      // (1.500.000 - 300.000) / 10 = 1.200.000 / 10 = 120.000
      expect(result.amount, equals(120000));
    });

    test(
      'con metas de ahorro con fecha objetivo: prorratea el aporte necesario',
      () {
        // 10 de octubre, cobra el 20 de octubre (10 días).
        // Meta con fecha objetivo que necesita 913.125 / mes (aprox 30.000 / día).
        // Prorrateado para 10 días = 300.000.
        // Meta sin fecha objetivo no exige prorrateo obligatorio.
        final today = DateTime(2026, 10, 10);
        final nextPay = DateTime(2026, 10, 20);

        final goalWithDate = Goal(
          id: 'g1',
          name: 'Vacaciones',
          icon: 'airplane-tilt',
          targetAmount: 3000000,
          targetDate: DateTime(2026, 11, 10), // ~31 días restantes
          createdAt: DateTime(2026, 9, 1),
          archived: false,
        );

        final goalNoDate = Goal(
          id: 'g2',
          name: 'Ahorro libre',
          icon: 'piggy-bank',
          targetAmount: 5000000,
          targetDate: null,
          createdAt: DateTime(2026, 9, 1),
          archived: false,
        );

        final activeGoals = [
          GoalWithProgress(
            goal: goalWithDate,
            contributions: const [],
            progress: calculateGoalProgress(
              goal: goalWithDate,
              contributions: const [],
              now: today,
            ),
          ),
          GoalWithProgress(
            goal: goalNoDate,
            contributions: const [],
            progress: calculateGoalProgress(
              goal: goalNoDate,
              contributions: const [],
              now: today,
            ),
          ),
        ];

        final result = safeToSpendToday(
          todayLocal: today,
          remaining: 2000000,
          nextPayDate: nextPay,
          activeGoals: activeGoals,
        );

        expect(result.proratedGoals, greaterThan(0));
        // El resultado es menor a 2.000.000 / 10 = 200.000 porque descuenta el aporte prorrateado
        expect(result.amount, lessThan(200000));
        // Verifica la fórmula exacta
        final expectedAmount = ((2000000 - result.proratedGoals) / 10).round();
        expect(result.amount, equals(expectedAmount));
      },
    );

    test(
      'negativo: cuando los gastos o compromisos superan los fondos restantes',
      () {
        final today = DateTime(2026, 10, 10);
        final nextPay = DateTime(2026, 10, 20);

        // Quedan 100.000 pero recurrente pendiente de 600.000
        final rules = [
          RecurringRule(
            id: 'r1',
            name: 'Alquiler',
            type: TxType.expense,
            amount: 600000,
            categoryId: 'vivienda',
            frequency: 'monthly',
            nextDueDate: DateTime(2026, 10, 15),
            active: true,
          ),
        ];

        final result = safeToSpendToday(
          todayLocal: today,
          remaining: 100000,
          nextPayDate: nextPay,
          recurringRules: rules,
        );

        expect(result.amount, isNegative);
        // (100.000 - 600.000) / 10 = -500.000 / 10 = -50.000
        expect(result.amount, equals(-50000));
      },
    );

    test('con sugerencias de gasto pendientes: descuenta del numerador en pendingRecurring', () {
      final today = DateTime(2026, 10, 10);
      final nextPay = DateTime(2026, 10, 20);

      final suggestions = [
        SuggestedTransaction(
          id: 's1',
          type: TxType.expense,
          amount: 150000,
          currency: 'PYG',
          occurredAt: DateTime(2026, 10, 5), // Vencido hace 5 días
          source: TxSource.recurring,
          sourceRef: 'r-ande',
          status: 'pending',
          createdAt: DateTime(2026, 10, 5),
        ),
        SuggestedTransaction(
          id: 's2',
          type: TxType.expense,
          amount: 80000,
          currency: 'PYG',
          occurredAt: DateTime(2026, 10, 8),
          source: TxSource.recurring,
          sourceRef: 'r-netflix',
          status: 'pending',
          createdAt: DateTime(2026, 10, 8),
        ),
        SuggestedTransaction(
          id: 's3',
          type: TxType.income,
          amount: 500000,
          currency: 'PYG',
          occurredAt: DateTime(2026, 10, 8),
          source: TxSource.recurring,
          status: 'pending',
          createdAt: DateTime(2026, 10, 8),
        ),
        SuggestedTransaction(
          id: 's4',
          type: TxType.expense,
          amount: 40000,
          currency: 'PYG',
          occurredAt: DateTime(2026, 10, 7),
          source: TxSource.recurring,
          status: 'confirmed', // ya confirmado
          createdAt: DateTime(2026, 10, 7),
        ),
      ];

      final result = safeToSpendToday(
        todayLocal: today,
        remaining: 1500000,
        nextPayDate: nextPay,
        pendingSuggestions: suggestions,
      );

      // Solo s1 (150.000) + s2 (80.000) = 230.000
      expect(result.pendingRecurring, equals(230000));
      // (1.500.000 - 230.000) / 10 = 1.270.000 / 10 = 127.000
      expect(result.amount, equals(127000));
    });

    test('no cuenta dos veces una regla cuyo vencimiento ya generó una sugerencia pendiente', () {
      final today = DateTime(2026, 10, 10);
      final nextPay = DateTime(2026, 10, 20);

      // Regla que vence hoy
      final rules = [
        RecurringRule(
          id: 'r1',
          name: 'ANDE',
          type: TxType.expense,
          amount: 150000,
          categoryId: 'servicios',
          frequency: 'monthly',
          nextDueDate: DateTime(2026, 10, 10),
          active: true,
        ),
      ];

      // Sugerencia pendiente ya generada para esa regla
      final suggestions = [
        SuggestedTransaction(
          id: 's1',
          type: TxType.expense,
          amount: 150000,
          currency: 'PYG',
          occurredAt: DateTime(2026, 10, 10),
          source: TxSource.recurring,
          sourceRef: 'r1',
          status: 'pending',
          createdAt: DateTime(2026, 10, 10),
        ),
      ];

      final result = safeToSpendToday(
        todayLocal: today,
        remaining: 1500000,
        nextPayDate: nextPay,
        recurringRules: rules,
        pendingSuggestions: suggestions,
      );

      // Debe ser 150.000, NO 300.000
      expect(result.pendingRecurring, equals(150000));
      // (1.500.000 - 150.000) / 10 = 1.350.000 / 10 = 135.000
      expect(result.amount, equals(135000));
    });
  });

  group('safeToSpendProvider reactive stream with AppDatabase', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test(
      'reacciona a sugerencias de gasto pendientes y las descuenta',
      () async {
        final cat = await (db.select(db.categories)..limit(1)).getSingle();

        // 1. Ingreso de 3.000.000
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                id: 'tx-1',
                type: TxType.income,
                amount: 3000000,
                categoryId: cat.id,
                occurredAt: DateTime.now(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                source: TxSource.manual,
              ),
            );

        final queue = <SafeToSpend>[];
        final sub = container.listen(safeToSpendProvider, (prev, next) {
          final val = next.value;
          if (val != null) {
            queue.add(val);
          }
        });
        addTearDown(sub.close);

        // Esperamos la primera emisión
        while (queue.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(queue.last.pendingRecurring, equals(0));

        // 2. Insertamos sugerencia de gasto pendiente
        await db
            .into(db.suggestedTransactions)
            .insert(
              SuggestedTransactionsCompanion.insert(
                id: 'sug-1',
                type: TxType.expense,
                amount: 200000,
                occurredAt: DateTime.now(),
                source: TxSource.recurring,
                status: 'pending',
                createdAt: DateTime.now(),
              ),
            );

        // Esperamos la actualización reactiva
        while (queue.length < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(queue.last.pendingRecurring, equals(200000));
      },
    );

    test('con esquema quincenal y cobro registrado hoy, reparte entre los días hasta la siguiente quincena', () async {
      final cat = await (db.select(db.categories)..limit(1)).getSingle();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Creamos esquema quincenal con cobro el día de hoy
      await db
          .into(db.incomeSchedules)
          .insert(
            IncomeSchedulesCompanion.insert(
              id: 'sched-1',
              mode: 'biweekly',
              payDays: '[${today.day}, -1]',
              payDayRules: '["either", "previous"]',
              paySplitPercents: '[50, 50]',
              categoryId: cat.id,
              monthlyAmount: Value(4000000),
              effectiveFrom: DateTime(today.year, today.month, 1),
            ),
          );

      // Cobro de hoy ya registrado
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: 'tx-salary-today',
              type: TxType.income,
              amount: 2000000,
              categoryId: cat.id,
              occurredAt: today,
              createdAt: today,
              updatedAt: today,
              source: TxSource.incomeSchedule,
            ),
          );

      final queue = <SafeToSpend>[];
      final sub = container.listen(safeToSpendProvider, (prev, next) {
        final val = next.value;
        if (val != null) {
          queue.add(val);
        }
      });
      addTearDown(sub.close);

      while (queue.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final val = queue.last;
      expect(val.daysUntilPay, greaterThan(1));
      expect(val.amount, lessThan(2000000));
    });
  });
}
