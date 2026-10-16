import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/features/home/domain/home_period_summary.dart';

void main() {
  group('calculateHomePeriodSummary', () {
    test('retorna resumen vacío cuando schedule es null', () {
      final summary = calculateHomePeriodSummary(
        todayLocal: DateTime(2026, 10, 8),
        schedule: null,
        lastConfirmedSalaryDate: null,
        carryOver: 0,
        incomeSincePay: 0,
        expenseSincePay: 0,
        contributionsSincePay: 0,
        deductions: const [],
      );

      expect(summary.periodLine, isNull);
      expect(summary.payPeriodStart, isNull);
      expect(summary.schedule, isNull);
    });

    test('sin cobro confirmado arranca en prevWindow.earliest y calcula restante', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        payDayRules: '["either", "previous"]',
        paySplitPercents: '[50, 50]',
        monthlyAmount: 6000000,
        categoryId: 'cat-salary',
        effectiveFrom: DateTime(2026, 9, 1),
      );

      final summary = calculateHomePeriodSummary(
        todayLocal: DateTime(2026, 10, 8),
        schedule: schedule,
        lastConfirmedSalaryDate: null,
        carryOver: 0,
        incomeSincePay: 0,
        expenseSincePay: 1500000,
        contributionsSincePay: 0,
        deductions: const [],
      );

      expect(summary.schedule, equals(schedule));
      expect(summary.payPeriodStart, equals(DateTime(2026, 9, 30)));
      expect(summary.periodLine, isNotNull);
      // Con sueldo estimado 3.000.000 - gasto 1.500.000 = quedan 1.500.000
      expect(summary.periodLine!.isEstimate, isTrue);
      expect(summary.periodLine!.remaining, equals(1500000));
    });

    test('con cobro confirmado posterior a prevWindow.earliest usa la fecha limpia del cobro', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        payDayRules: '["either", "previous"]',
        paySplitPercents: '[50, 50]',
        monthlyAmount: 6000000,
        categoryId: 'cat-salary',
        effectiveFrom: DateTime(2026, 9, 1),
      );

      final summary = calculateHomePeriodSummary(
        todayLocal: DateTime(2026, 10, 16),
        schedule: schedule,
        lastConfirmedSalaryDate: DateTime(2026, 10, 15, 10, 30),
        carryOver: 100000,
        incomeSincePay: 3000000,
        expenseSincePay: 800000,
        contributionsSincePay: 200000,
        deductions: const [],
      );

      expect(summary.payPeriodStart, equals(DateTime(2026, 10, 15)));
      expect(summary.periodLine, isNotNull);
      expect(summary.periodLine!.isEstimate, isFalse);
      // 3.000.000 - 800.000 - 200.000 + 100.000 = 2.100.000
      expect(summary.periodLine!.remaining, equals(2100000));
      expect(summary.periodLine!.carryOver, equals(100000));
    });
  });
}
