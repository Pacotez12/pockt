import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/features/income/domain/period_summary.dart';

void main() {
  group('periodLine', () {
    test('sin esquema devuelve null', () {
      final line = periodLine(
        todayLocal: DateTime(2026, 10, 14),
        schedule: null,
        monthIncome: 5000000,
        monthExpense: 2000000,
      );

      expect(line, isNull);
    });

    test('esquema [15, -1] sin corrimiento: 14/10 -> 1ª quincena, cobrás mañana', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        shiftToPreviousBusinessDay: false,
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 10, 1),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 10, 14),
        schedule: schedule,
        monthIncome: 5000000,
        monthExpense: 1000000,
      );

      expect(line, isNotNull);
      expect(line!.label, '1ª quincena');
      expect(line.daysToNextPay, 1);
      expect(line.payDayText, 'cobrás mañana');
      expect(line.remaining, 4000000);
      expect(line.nextPayDate, DateTime(2026, 10, 15));
    });

    test('16/10 -> 2ª, 15 días al 31 sin corrimiento', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        shiftToPreviousBusinessDay: false,
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 10, 1),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 10, 16),
        schedule: schedule,
        monthIncome: 5000000,
        monthExpense: 4180000,
      );

      expect(line, isNotNull);
      expect(line!.label, '2ª quincena');
      expect(line.daysToNextPay, 15);
      expect(line.nextPayDate, DateTime(2026, 10, 31));
      expect(line.remaining, 820000);
      expect(line.payDayText, 'cobrás en 15 días');
    });

    test('con corrimiento: 16/10 -> 14 días al viernes 30', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        shiftToPreviousBusinessDay: true,
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 10, 1),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 10, 16),
        schedule: schedule,
        monthIncome: 5000000,
        monthExpense: 4180000,
      );

      expect(line, isNotNull);
      expect(line!.label, '2ª quincena');
      expect(line.daysToNextPay, 14);
      expect(line.nextPayDate, DateTime(2026, 10, 30));
      expect(line.remaining, 820000);
      expect(line.payDayText, 'cobrás en 14 días');
    });

    test('restante negativo con gastos mayores a ingresos', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        shiftToPreviousBusinessDay: false,
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 10, 1),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 10, 16),
        schedule: schedule,
        monthIncome: 1000000,
        monthExpense: 1820000,
      );

      expect(line, isNotNull);
      expect(line!.remaining, -820000);
    });

    test('cobrás hoy cuando hoy es día de cobro', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        shiftToPreviousBusinessDay: false,
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 10, 1),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 10, 15),
        schedule: schedule,
        monthIncome: 5000000,
        monthExpense: 1000000,
      );

      expect(line, isNotNull);
      expect(line!.daysToNextPay, 0);
      expect(line.payDayText, 'cobrás hoy');
      expect(line.label, '1ª quincena');
    });

    test('esquema mensual usa label Este mes', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'monthly',
        payDays: '[-1]',
        shiftToPreviousBusinessDay: false,
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 10, 1),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 10, 8),
        schedule: schedule,
        monthIncome: 6000000,
        monthExpense: 2000000,
      );

      expect(line, isNotNull);
      expect(line!.label, 'Este mes');
      expect(line.daysToNextPay, 23);
      expect(line.remaining, 4000000);
    });
  });
}
