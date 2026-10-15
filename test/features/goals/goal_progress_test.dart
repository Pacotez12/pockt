import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/features/goals/domain/goal_progress.dart';

void main() {
  group('GoalProgress domain logic', () {
    final now = DateTime(2026, 10, 15, 12, 0);

    Goal makeGoal({
      String id = 'goal-1',
      String name = 'Vacaciones en Brasil',
      String icon = 'airplane-tilt',
      int targetAmount = 5000000,
      DateTime? targetDate,
      DateTime? createdAt,
      bool archived = false,
    }) {
      final created = createdAt ?? DateTime(2026, 8, 1);
      return Goal(
        id: id,
        name: name,
        icon: icon,
        targetAmount: targetAmount,
        targetDate: targetDate,
        createdAt: created,
        archived: archived,
      );
    }

    GoalContribution makeContribution({
      String id = 'c1',
      String goalId = 'goal-1',
      required int amount,
      required DateTime date,
      String? note,
    }) {
      return GoalContribution(
        id: id,
        goalId: goalId,
        amount: amount,
        date: date,
        note: note,
        createdAt: date,
      );
    }

    test('sin aportes: ahorrado 0, % 0, restante total, sin ritmo real', () {
      final goal = makeGoal(
        targetAmount: 3000000,
        targetDate: DateTime(2026, 12, 15),
      );

      final progress = calculateGoalProgress(
        goal: goal,
        contributions: const [],
        now: now,
      );

      expect(progress.saved, equals(0));
      expect(progress.percent, equals(0.0));
      expect(progress.remaining, equals(3000000));
      expect(progress.isCompleted, isFalse);
      expect(progress.realDailyPace, equals(0.0));
      expect(progress.realMonthlyPace, equals(0));
      expect(progress.projectedFinishDate, isNull);
      expect(progress.delayDaysFor(500000), isNull);
      expect(progress.status, isA<GoalStatusLate>());
      // Al no tener ritmo y tener fecha objetivo, está atrasada
      final lateStatus = progress.status as GoalStatusLate;
      expect(lateStatus.months, greaterThanOrEqualTo(1));
    });

    test('sin fecha objetivo: ritmo necesario null, estado noDate', () {
      final goal = makeGoal(targetAmount: 2000000, targetDate: null);
      final contributions = [
        makeContribution(amount: 500000, date: DateTime(2026, 9, 15)),
      ];

      final progress = calculateGoalProgress(
        goal: goal,
        contributions: contributions,
        now: now,
      );

      expect(progress.saved, equals(500000));
      expect(progress.percent, closeTo(0.25, 0.001));
      expect(progress.remaining, equals(1500000));
      expect(progress.requiredMonthlyPace, isNull);
      expect(progress.status, equals(const GoalStatus.noDate()));
      expect(progress.realDailyPace, greaterThan(0.0));
      expect(progress.delayDaysFor(100000), isNotNull);
    });

    test('con aportes y retiros: cálculo de saldo neto ahorrado y ritmo de 90 días', () {
      final goal = makeGoal(
        targetAmount: 6000000,
        targetDate: DateTime(2027, 4, 15), // ~6 meses adelante
      );

      final contributions = [
        // Fuera de la ventana de 90 días (hace 100 días):
        makeContribution(
          id: 'c-old',
          amount: 1000000,
          date: now.subtract(const Duration(days: 100)),
        ),
        // Dentro de la ventana de 90 días:
        makeContribution(
          id: 'c1',
          amount: 1200000,
          date: now.subtract(const Duration(days: 60)),
        ),
        makeContribution(
          id: 'c2',
          amount: 800000,
          date: now.subtract(const Duration(days: 30)),
        ),
        // Retiro dentro de la ventana:
        makeContribution(
          id: 'c-withdraw',
          amount: -200000,
          date: now.subtract(const Duration(days: 10)),
        ),
      ];

      final progress = calculateGoalProgress(
        goal: goal,
        contributions: contributions,
        now: now,
      );

      // Ahorrado total = 1.000.000 + 1.200.000 + 800.000 - 200.000 = 2.800.000
      expect(progress.saved, equals(2800000));
      expect(progress.remaining, equals(3200000));
      expect(progress.percent, closeTo(2800000 / 6000000, 0.001));

      // Ventana de 90 días: 1.200.000 + 800.000 - 200.000 = 1.800.000
      // Ritmo diario = 1.800.000 / 90 = 20.000 Gs/día
      expect(progress.realDailyPace, closeTo(20000.0, 0.1));
      // Ritmo mensual ~ 20.000 * 30.4375 ≈ 608.750 (o * 30 = 600.000)
      expect(progress.realMonthlyPace, greaterThanOrEqualTo(600000));

      // delayDaysFor: 200.000 / 20.000 = 10 días
      expect(progress.delayDaysFor(200000), equals(10));

      // Días restantes para 3.200.000 a 20.000/día = 160 días (~5.3 meses)
      // Como faltan ~182 días hasta el 15/4/2027, termina antes -> onTrack
      expect(progress.status, equals(const GoalStatus.onTrack()));
      expect(progress.projectedFinishDate, isNotNull);
      expect(progress.projectedFinishDate!.isBefore(goal.targetDate!), isTrue);
    });

    test('meta con proyección atrasada resulta en late(meses)', () {
      final goal = makeGoal(
        targetAmount: 10000000,
        targetDate: DateTime(2026, 11, 15), // a 1 mes
      );

      // Aporte de 90.000 en 90 días -> ritmo diario 1.000 Gs/día
      // Restante: 9.910.000 -> tomaría ~9.910 días (mucho más que 1 mes)
      final contributions = [
        makeContribution(
          amount: 90000,
          date: now.subtract(const Duration(days: 10)),
        ),
      ];

      final progress = calculateGoalProgress(
        goal: goal,
        contributions: contributions,
        now: now,
      );

      expect(progress.status, isA<GoalStatusLate>());
      final lateStatus = progress.status as GoalStatusLate;
      expect(lateStatus.months, greaterThanOrEqualTo(1));
    });

    test('meta cumplida (saldo alcanzado o superado): onTrack, restante 0, delayDays 0', () {
      final goal = makeGoal(
        targetAmount: 2000000,
        targetDate: DateTime(2026, 12, 31),
      );

      final contributions = [
        makeContribution(
          amount: 2500000,
          date: now.subtract(const Duration(days: 5)),
        ),
      ];

      final progress = calculateGoalProgress(
        goal: goal,
        contributions: contributions,
        now: now,
      );

      expect(progress.saved, equals(2500000));
      expect(progress.remaining, equals(0));
      expect(progress.percent, equals(1.0));
      expect(progress.isCompleted, isTrue);
      expect(progress.requiredMonthlyPace, equals(0));
      expect(progress.status, equals(const GoalStatus.onTrack()));
      expect(progress.delayDaysFor(100000), equals(0));
    });
  });
}
