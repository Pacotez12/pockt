import 'dart:convert';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/income/domain/pay_days.dart';

/// Representa el resumen de período (quincena / mes) mostrado en el Inicio.
class PeriodLine {
  /// Etiqueta del período: "1ª quincena", "2ª quincena", o "Este mes".
  final String label;

  /// Restante del mes (= ingresos registrados − gastos registrados). Puede ser negativo.
  final int remaining;

  /// Cantidad de días hasta el próximo cobro (0 si hoy es día de cobro).
  final int daysToNextPay;

  /// Fecha exacta del próximo cobro.
  final DateTime nextPayDate;

  const PeriodLine({
    required this.label,
    required this.remaining,
    required this.daysToNextPay,
    required this.nextPayDate,
  });

  /// Mensaje del próximo cobro según los días restantes.
  String get payDayText {
    if (daysToNextPay == 0) return 'cobrás hoy';
    if (daysToNextPay == 1) return 'cobrás mañana';
    return 'cobrás en $daysToNextPay días';
  }

  /// Texto completo según la spec §5.2.4:
  /// "2ª quincena · quedan Gs. 820.000 · cobrás en 6 días".
  String get fullText => '$label · quedan ${formatGs(remaining)} · $payDayText';
}

/// Calcula la línea de período para el Inicio según el esquema de cobro vigente.
/// Devuelve `null` si no hay esquema configurado o si no se puede determinar la fecha de cobro.
PeriodLine? periodLine({
  required DateTime todayLocal,
  required IncomeSchedule? schedule,
  required int monthIncome,
  required int monthExpense,
}) {
  if (schedule == null) return null;

  List<int> payDays;
  try {
    payDays = (jsonDecode(schedule.payDays) as List)
        .map((e) => (e as num).toInt())
        .toList();
  } catch (_) {
    return null;
  }

  if (payDays.isEmpty) return null;

  final next = nextPayDay(
    todayLocal,
    payDays,
    shiftToPreviousBusinessDay: schedule.shiftToPreviousBusinessDay,
  );

  if (next == null) return null;

  final today = DateTime(todayLocal.year, todayLocal.month, todayLocal.day);
  final target = DateTime(next.year, next.month, next.day);
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

  final remaining = monthIncome - monthExpense;

  return PeriodLine(
    label: label,
    remaining: remaining,
    daysToNextPay: daysToNextPay,
    nextPayDate: next,
  );
}
