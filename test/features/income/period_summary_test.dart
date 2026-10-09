import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/features/income/domain/period_summary.dart';

void main() {
  group('periodLine', () {
    test('sin esquema devuelve null', () {
      final line = periodLine(
        todayLocal: DateTime(2026, 10, 14),
        schedule: null,
        incomeSincePay: 5000000,
        expenseSincePay: 2000000,
      );

      expect(line, isNull);
    });

    test('esquema [15, -1]: 14/10 -> 1ª quincena, cobrás mañana al 15/10', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        payDayRules: '["either", "previous"]',
        paySplitPercents: '[50, 50]',
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 10, 1),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 10, 14),
        schedule: schedule,
        incomeSincePay: 5000000,
        expenseSincePay: 1000000,
      );

      expect(line, isNotNull);
      expect(line!.label, '1ª quincena');
      expect(line.daysToNextPay, 1);
      expect(line.payDayText, 'cobrás mañana');
      expect(line.remaining, 4000000);
      expect(line.nextPayDate, DateTime(2026, 10, 15));
    });

    test('16/10 -> 2ª quincena, 14 días al viernes 30/10 (31 sábado con previous)', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        payDayRules: '["either", "previous"]',
        paySplitPercents: '[50, 50]',
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 10, 1),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 10, 16),
        schedule: schedule,
        incomeSincePay: 5000000,
        expenseSincePay: 4180000,
      );

      expect(line, isNotNull);
      expect(line!.label, '2ª quincena');
      expect(line.daysToNextPay, 14);
      expect(line.nextPayDate, DateTime(2026, 10, 30));
      expect(line.remaining, 820000);
      expect(line.payDayText, 'cobrás en 14 días');
    });

    test('15/11/2026 (domingo) con either -> ventana 13/11 a 16/11: cobrás entre el vie 13 y el lun 16', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        payDayRules: '["either", "previous"]',
        paySplitPercents: '[50, 50]',
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 11, 1),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 11, 10),
        schedule: schedule,
        incomeSincePay: 3500000,
        expenseSincePay: 1200000,
      );

      expect(line, isNotNull);
      expect(line!.nextPayWindow!.isRange, isTrue);
      expect(line.payDayText, 'cobrás entre el vie 13 y el lun 16');
      expect(line.fullText, '1ª quincena · quedan Gs. 2.300.000 · cobrás entre el vie 13 y el lun 16');
    });

    test('periodLine con sueldo confirmado el 16/11 arranca el 16 aunque la ventana empiece el 13', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        payDayRules: '["either", "previous"]',
        paySplitPercents: '[50, 50]',
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 11, 1),
      );

      // Hoy es 18/11/2026, ventana pasada fue [13/11, 16/11]
      // El sueldo se confirmó efectivamente el lunes 16/11
      final line = periodLine(
        todayLocal: DateTime(2026, 11, 18),
        schedule: schedule,
        incomeSincePay: 3500000,
        expenseSincePay: 500000,
        lastConfirmedSalaryDate: DateTime(2026, 11, 16),
      );

      expect(line, isNotNull);
      expect(line!.periodStartDate, DateTime(2026, 11, 16));
    });

    test('periodLine sin sueldo confirmado arranca en ventana previous earliest (13/11)', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        payDayRules: '["either", "previous"]',
        paySplitPercents: '[50, 50]',
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 11, 1),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 11, 18),
        schedule: schedule,
        incomeSincePay: 3500000,
        expenseSincePay: 500000,
        lastConfirmedSalaryDate: null,
      );

      expect(line, isNotNull);
      expect(line!.periodStartDate, DateTime(2026, 11, 13));
    });

    test('sueldo confirmado anterior a la ventana (e.g. mes anterior) no se usa y arranca en 13/11', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        payDayRules: '["either", "previous"]',
        paySplitPercents: '[50, 50]',
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 11, 1),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 11, 18),
        schedule: schedule,
        incomeSincePay: 3500000,
        expenseSincePay: 500000,
        lastConfirmedSalaryDate: DateTime(2026, 10, 30),
      );

      expect(line, isNotNull);
      expect(line!.periodStartDate, DateTime(2026, 11, 13));
    });

    test('restante negativo con gastos mayores a ingresos', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        payDayRules: '["either", "previous"]',
        paySplitPercents: '[50, 50]',
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 10, 1),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 10, 16),
        schedule: schedule,
        incomeSincePay: 1000000,
        expenseSincePay: 1820000,
      );

      expect(line, isNotNull);
      expect(line!.remaining, -820000);
    });

    test('cobrás hoy cuando hoy es día de cobro', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        payDayRules: '["previous", "previous"]',
        paySplitPercents: '[50, 50]',
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 10, 1),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 10, 15),
        schedule: schedule,
        incomeSincePay: 5000000,
        expenseSincePay: 1000000,
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
        payDayRules: '["previous"]',
        paySplitPercents: '[100]',
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 10, 1),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 10, 8),
        schedule: schedule,
        incomeSincePay: 6000000,
        expenseSincePay: 2000000,
      );

      expect(line, isNotNull);
      expect(line!.label, 'Este mes');
      expect(line.daysToNextPay, 22); // 30/10 es el último día hábil de octubre (31 sábado)
      expect(line.remaining, 4000000);
    });

    test('sin ingresos confirmados y gastos 820.000 con 4.900.000 esperados -> remaining 4.080.000 e isEstimate == true', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        payDayRules: '["either", "previous"]',
        paySplitPercents: '[30, 70]',
        monthlyAmount: 7000000,
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 10, 9),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 10, 9),
        schedule: schedule,
        incomeSincePay: 0,
        expenseSincePay: 820000,
        expectedForPeriod: 4900000,
      );

      expect(line, isNotNull);
      expect(line!.remaining, 4080000);
      expect(line.isEstimate, isTrue);
      expect(line.fullText, contains('quedan ~Gs. 4.080.000 (estimado)'));
    });

    test('con ingreso confirmado y gastos 820.000 -> remaining 4.080.000 e isEstimate == false', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        payDayRules: '["either", "previous"]',
        paySplitPercents: '[30, 70]',
        monthlyAmount: 7000000,
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 10, 9),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 10, 9),
        schedule: schedule,
        incomeSincePay: 4900000,
        expenseSincePay: 820000,
        expectedForPeriod: 4900000,
      );

      expect(line, isNotNull);
      expect(line!.remaining, 4080000);
      expect(line.isEstimate, isFalse);
      expect(line.fullText, contains('quedan Gs. 4.080.000 ·'));
      expect(line.fullText, isNot(contains('(estimado)')));
    });

    test('sin monthlyAmount y sin ingresos confirmados funciona como antes (isEstimate == false)', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        payDayRules: '["either", "previous"]',
        paySplitPercents: '[50, 50]',
        monthlyAmount: null,
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 10, 9),
      );

      final line = periodLine(
        todayLocal: DateTime(2026, 10, 9),
        schedule: schedule,
        incomeSincePay: 0,
        expenseSincePay: 820000,
        expectedForPeriod: null,
      );

      expect(line, isNotNull);
      expect(line!.remaining, -820000);
      expect(line.isEstimate, isFalse);
      expect(line.fullText, contains('quedan −Gs. 820.000 ·'));
      expect(line.fullText, isNot(contains('(estimado)')));
    });

    test('expectedAmountForPeriod obtiene el monto del cobro que abrió el período', () {
      final schedule = IncomeSchedule(
        id: 'sched-1',
        mode: 'biweekly',
        payDays: '[15, -1]',
        payDayRules: '["either", "previous"]',
        paySplitPercents: '[30, 70]',
        monthlyAmount: 7000000,
        categoryId: 'cat-1',
        effectiveFrom: DateTime(2026, 10, 1),
      );

      // El 9/10, el cobro que abrió el período fue el 30/09 (70% = 4.900.000)
      expect(expectedAmountForPeriod(schedule, DateTime(2026, 10, 9)), 4900000);
      // El 16/10, el cobro que abrió el período fue el 15/10 (30% = 2.100.000)
      expect(expectedAmountForPeriod(schedule, DateTime(2026, 10, 16)), 2100000);
    });
  });
}

