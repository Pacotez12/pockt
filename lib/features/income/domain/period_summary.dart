import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:pockt/features/income/domain/pay_split.dart';
import 'package:pockt/features/income/domain/salary_deduction.dart';

/// Representa el resumen de período (quincena / mes) mostrado en el Inicio.
class PeriodLine {
  /// Etiqueta del período: "1ª quincena", "2ª quincena", o "Este mes".
  final String label;

  /// Restante del mes (= ingresos registrados − gastos registrados). Puede ser negativo.
  final int remaining;

  /// Cantidad de días hasta el próximo cobro (0 si hoy es día de cobro).
  final int daysToNextPay;

  /// Fecha exacta o inicial del próximo cobro.
  final DateTime nextPayDate;

  /// Ventana del próximo cobro.
  final PayWindow? nextPayWindow;

  /// Fecha en la que arrancó este período para computar ingresos y gastos.
  final DateTime periodStartDate;

  /// Indica si el restante es un estimado calculado con el sueldo esperado
  /// en vez de ingresos reales confirmados.
  final bool isEstimate;

  const PeriodLine({
    required this.label,
    required this.remaining,
    required this.daysToNextPay,
    required this.nextPayDate,
    this.nextPayWindow,
    required this.periodStartDate,
    this.isEstimate = false,
  });

  /// Mensaje del próximo cobro según los días restantes o rango.
  String get payDayText {
    if (nextPayWindow != null && nextPayWindow!.isRange) {
      const weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
      final w1 = weekdays[nextPayWindow!.earliest.weekday - 1];
      final d1 = nextPayWindow!.earliest.day;
      final w2 = weekdays[nextPayWindow!.latest.weekday - 1];
      final d2 = nextPayWindow!.latest.day;
      return 'cobrás entre el $w1 $d1 y el $w2 $d2';
    }
    if (daysToNextPay == 0) return 'cobrás hoy';
    if (daysToNextPay == 1) return 'cobrás mañana';
    return 'cobrás en $daysToNextPay días';
  }

  /// Texto completo según la spec §5.2.4:
  /// "2ª quincena · quedan Gs. 820.000 · cobrás en 6 días".
  String get fullText => isEstimate
      ? '$label · quedan ~${formatGs(remaining)} (estimado) · $payDayText'
      : '$label · quedan ${formatGs(remaining)} · $payDayText';
}

/// Obtiene el monto esperado correspondiente al cobro que abrió el período actual,
/// teniendo en cuenta los descuentos aplicados al sueldo.
int? expectedAmountForPeriod(
  IncomeSchedule schedule,
  DateTime todayLocal, {
  Iterable<SalaryDeductionLike> deductions = const [],
}) {
  if (schedule.monthlyAmount == null) return null;
  final payDays = parsePayDays(schedule.payDays);
  if (payDays.isEmpty) return null;
  final rules = parsePayDayRules(schedule.payDayRules, payDays);
  final splits = parsePaySplitPercents(
    schedule.paySplitPercents,
    count: payDays.length,
  );
  final splitList = netPayAmounts(schedule.monthlyAmount!, splits, deductions);
  final prevWindow = previousPayWindow(todayLocal, payDays, rules);
  if (prevWindow == null) return null;

  final year = prevWindow.earliest.year;
  final month = prevWindow.earliest.month;
  final daysInMonth = DateTime(year, month + 1, 0).day;

  for (var i = 0; i < payDays.length; i++) {
    final rawDay = payDays[i];
    final rule = (i < rules.length)
        ? rules[i]
        : (rawDay == -1 ? PayDayRule.previous : PayDayRule.either);
    final int day;
    if (rawDay == -1 || rawDay > daysInMonth) {
      day = daysInMonth;
    } else if (rawDay <= 0) {
      day = 1;
    } else {
      day = rawDay;
    }
    final targetDate = DateTime(year, month, day);
    final w = resolvePayWindow(targetDate, rule);
    if (w.earliest == prevWindow.earliest && w.latest == prevWindow.latest) {
      return i < splitList.length ? splitList[i] : null;
    }
  }
  return null;
}

/// Calcula la línea de período para el Inicio según el esquema de cobro vigente.
/// Devuelve `null` si no hay esquema configurado o si no se puede determinar la fecha de cobro.
PeriodLine? periodLine({
  required DateTime todayLocal,
  required IncomeSchedule? schedule,
  required int incomeSincePay,
  required int expenseSincePay,
  DateTime? lastConfirmedSalaryDate,
  int? expectedForPeriod,
  Iterable<SalaryDeductionLike> deductions = const [],
}) {
  if (schedule == null) return null;

  final payDays = parsePayDays(schedule.payDays);
  if (payDays.isEmpty) return null;

  final rules = parsePayDayRules(schedule.payDayRules, payDays);

  final nextWindow = nextPayWindow(todayLocal, payDays, rules);
  if (nextWindow == null) return null;

  final today = DateTime(todayLocal.year, todayLocal.month, todayLocal.day);
  final target = DateTime(nextWindow.earliest.year, nextWindow.earliest.month, nextWindow.earliest.day);
  final daysToNextPay = target.difference(today).inDays;

  final String label;
  if (schedule.mode.toLowerCase() == 'monthly') {
    label = 'Este mes';
  } else {
    // Modo quincenal: dividimos el mes según el primer día de cobro
    final positiveDays = payDays.where((d) => d > 0).toList()..sort();
    final firstPayDay = positiveDays.isNotEmpty ? positiveDays.first : 15;

    if (todayLocal.day <= firstPayDay) {
      label = '1ª quincena';
    } else {
      label = '2ª quincena';
    }
  }

  // Determinación de periodStartDate:
  // spec §4: "El período de 'quedan' arranca en la fecha real del último ingreso
  // confirmado del esquema, si existe y es >= previousPayWindow.earliest; si no,
  // previousPayWindow.earliest."
  final prevWindow = previousPayWindow(todayLocal, payDays, rules);
  final fallbackStart = prevWindow?.earliest ?? today;
  DateTime periodStart = fallbackStart;

  if (lastConfirmedSalaryDate != null) {
    final cleanSalary = DateTime(
      lastConfirmedSalaryDate.year,
      lastConfirmedSalaryDate.month,
      lastConfirmedSalaryDate.day,
    );
    if (!cleanSalary.isBefore(fallbackStart)) {
      periodStart = cleanSalary;
    }
  }

  final effectiveExpected = expectedForPeriod ??
      expectedAmountForPeriod(schedule, todayLocal, deductions: deductions);
  final bool isEstimate;
  final int remaining;

  if (incomeSincePay <= 0 &&
      effectiveExpected != null &&
      effectiveExpected > 0) {
    remaining = effectiveExpected - expenseSincePay;
    isEstimate = true;
  } else {
    remaining = incomeSincePay - expenseSincePay;
    isEstimate = false;
  }

  return PeriodLine(
    label: label,
    remaining: remaining,
    daysToNextPay: daysToNextPay,
    nextPayDate: nextWindow.earliest,
    nextPayWindow: nextWindow,
    periodStartDate: periodStart,
    isEstimate: isEstimate,
  );
}

