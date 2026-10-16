import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:pockt/features/income/domain/period_summary.dart';

/// Datos del período actual (quincena / mes) calculados para la pantalla de Inicio.
class HomePeriodSummary {
  final PeriodLine? periodLine;
  final DateTime? payPeriodStart;
  final IncomeSchedule? schedule;

  const HomePeriodSummary({
    this.periodLine,
    this.payPeriodStart,
    this.schedule,
  });
}

/// Función pura que calcula el resumen de período (quedan, inicio de período, etc.)
/// a partir de los datos actuales de esquema, cobros, movimientos y deducciones.
HomePeriodSummary calculateHomePeriodSummary({
  required DateTime todayLocal,
  required IncomeSchedule? schedule,
  required DateTime? lastConfirmedSalaryDate,
  required int carryOver,
  required int incomeSincePay,
  required int expenseSincePay,
  required int contributionsSincePay,
  required List<SalaryDeduction> deductions,
}) {
  if (schedule == null) {
    return const HomePeriodSummary();
  }

  final payDays = parsePayDays(schedule.payDays);
  final rules = parsePayDayRules(schedule.payDayRules, payDays);
  final prevWindow = previousPayWindow(todayLocal, payDays, rules);

  if (prevWindow == null) {
    return HomePeriodSummary(schedule: schedule);
  }

  DateTime periodStart = prevWindow.earliest;
  if (lastConfirmedSalaryDate != null) {
    final cleanSalary = DateTime(
      lastConfirmedSalaryDate.year,
      lastConfirmedSalaryDate.month,
      lastConfirmedSalaryDate.day,
    );
    if (!cleanSalary.isBefore(prevWindow.earliest)) {
      periodStart = cleanSalary;
    }
  }

  final expected = expectedAmountForPeriod(
    schedule,
    todayLocal,
    deductions: deductions,
  );

  final pLine = periodLine(
    todayLocal: todayLocal,
    schedule: schedule,
    incomeSincePay: incomeSincePay,
    expenseSincePay: expenseSincePay,
    contributionsSincePay: contributionsSincePay,
    carryOver: carryOver,
    lastConfirmedSalaryDate: lastConfirmedSalaryDate,
    deductions: deductions,
    expectedForPeriod: expected,
  );

  return HomePeriodSummary(
    periodLine: pLine,
    payPeriodStart: periodStart,
    schedule: schedule,
  );
}
