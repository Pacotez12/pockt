import 'dart:math';

import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';

/// Indica si un movimiento ligado a un préstamo es un pago extra / adelanto.
/// Se decide por la columna `isExtra`, no por el texto de la nota.
bool isLoanExtraPayment(Transaction tx) => tx.isExtra;

/// Estado y avance calculado de un préstamo (spec §7c).
class LoanProgress {
  final int paid;
  final int balance;
  final int installmentsPaid;
  final int? installmentsRemaining;
  final double percent;
  final bool isClosed;
  final DateTime? nextDueDate;
  final DateTime? estimatedEndDate;
  final int? daysUntilNextDue;
  final LoanInstallment? nextInstallment;
  final int paidBeforeCount;
  final int paidBeforeAmount;

  const LoanProgress({
    required this.paid,
    required this.balance,
    required this.installmentsPaid,
    this.installmentsRemaining,
    required this.percent,
    required this.isClosed,
    this.nextDueDate,
    this.estimatedEndDate,
    this.daysUntilNextDue,
    this.nextInstallment,
    this.paidBeforeCount = 0,
    this.paidBeforeAmount = 0,
  });
}

/// Cronograma a usar en los cálculos. Un préstamo de cuota fija con cuotas
/// ya pagadas antes de Pockt no tiene filas propias: se arma uno con la cuota
/// fija, empezando en el primer vencimiento desde la fecha de inicio, para saber
/// qué cuota y qué fecha siguen.
List<LoanInstallment>? effectiveSchedule(
  Loan loan,
  List<LoanInstallment>? schedule,
) {
  if (schedule != null && schedule.isNotEmpty) return schedule;
  final amount = loan.installmentAmount;
  final count = loan.installmentsTotal;
  final dueDay = loan.dueDay;
  if (loan.paidBeforeCount <= 0 ||
      loan.kind != LoanKind.installments ||
      amount == null ||
      count == null ||
      dueDay == null) {
    return schedule;
  }
  DateTime dueIn(int year, int month) =>
      DateTime(year, month, min(dueDay, DateTime(year, month + 1, 0).day));
  final start = DateTime(
    loan.startDate.year,
    loan.startDate.month,
    loan.startDate.day,
  );
  var first = dueIn(start.year, start.month);
  if (first.isBefore(start)) first = dueIn(start.year, start.month + 1);
  return [
    for (var i = 0; i < count; i++)
      LoanInstallment(
        loanId: loan.id,
        number: i + 1,
        dueDate: dueIn(first.year, first.month + i),
        amount: amount,
      ),
  ];
}

/// Calcula el avance de un préstamo a partir de sus pagos ligados.
LoanProgress calculateLoanProgress({
  required Loan loan,
  required List<Transaction> payments,
  List<LoanInstallment>? schedule,
  DateTime? now,
}) {
  schedule = effectiveSchedule(loan, schedule);
  final currentNow = now ?? DateTime.now();

  // Filtrar movimientos válidos (no eliminados)
  final validPayments = payments.where((p) => p.deletedAt == null).toList();

  // En préstamos 'owe', los pagos son egresos; en 'lent', las devoluciones son ingresos
  final relevantPayments = validPayments.where((p) {
    if (loan.direction == LoanDirection.owe) {
      return p.type == TxType.expense;
    } else {
      return p.type == TxType.income;
    }
  }).toList();

  final hasSchedule = schedule != null && schedule.isNotEmpty;
  final paidBeforeCount = loan.paidBeforeCount;
  final int paidBeforeAmount;
  if (hasSchedule) {
    paidBeforeAmount = schedule
        .take(paidBeforeCount)
        .fold<int>(0, (sum, i) => sum + i.amount);
  } else if (loan.kind == LoanKind.installments && loan.installmentAmount != null) {
    paidBeforeAmount = paidBeforeCount * loan.installmentAmount!;
  } else {
    paidBeforeAmount = 0;
  }

  final paidFromPayments = relevantPayments.fold<int>(0, (sum, p) => sum + p.amount);
  final paid = paidBeforeAmount + paidFromPayments;
  final balance = max(0, loan.totalAmount - paid);
  final isClosed = balance <= 0 || loan.closedAt != null;

  // Cuotas pagadas: cuotas previas a Pockt + pagos regulares en Pockt
  final regularPaymentsCount = relevantPayments
      .where((p) => !isLoanExtraPayment(p))
      .length;
  final totalCount = hasSchedule ? schedule.length : loan.installmentsTotal;
  final totalRegularAndBefore = paidBeforeCount + regularPaymentsCount;
  final installmentsPaid = totalCount != null
      ? min(totalCount, totalRegularAndBefore)
      : totalRegularAndBefore;

  final percent = loan.totalAmount > 0
      ? (paid / loan.totalAmount).clamp(0.0, 1.0)
      : 1.0;

  int? installmentsRemaining;
  DateTime? nextDueDate;
  int? daysUntilNextDue;
  DateTime? estimatedEndDate;
  LoanInstallment? nextInstallment;

  if (hasSchedule) {
    if (isClosed) {
      installmentsRemaining = 0;
      estimatedEndDate = schedule.last.dueDate;
    } else {
      installmentsRemaining = max(0, schedule.length - installmentsPaid);
      if (installmentsPaid < schedule.length) {
        nextInstallment = schedule[installmentsPaid];
        nextDueDate = nextInstallment.dueDate;
        final today = DateTime(currentNow.year, currentNow.month, currentNow.day);
        daysUntilNextDue = nextDueDate.difference(today).inDays;
      }
      estimatedEndDate = schedule.last.dueDate;
    }
  } else {
    if (loan.installmentAmount != null && loan.installmentAmount! > 0) {
      installmentsRemaining = (balance / loan.installmentAmount!).ceil();
    } else if (loan.installmentsTotal != null) {
      installmentsRemaining = max(0, loan.installmentsTotal! - installmentsPaid);
    }

    if (loan.dueDay != null && !isClosed) {
      final today = DateTime(currentNow.year, currentNow.month, currentNow.day);
      final dueDay = loan.dueDay!;

      DateTime makeDate(int year, int month, int targetDay) {
        final daysInMonth = DateTime(year, month + 1, 0).day;
        final day = min(targetDay, daysInMonth);
        return DateTime(year, month, day);
      }

      final currentMonthDue = makeDate(today.year, today.month, dueDay);
      // Misma regla que el aviso: una cuota regular pagada este mes la cubre.
      final paidThisMonth = relevantPayments.any(
        (p) =>
            !isLoanExtraPayment(p) &&
            p.occurredAt.year == today.year &&
            p.occurredAt.month == today.month,
      );
      if (!currentMonthDue.isBefore(today) && !paidThisMonth) {
        nextDueDate = currentMonthDue;
      } else {
        nextDueDate = makeDate(today.year, today.month + 1, dueDay);
      }

      daysUntilNextDue = nextDueDate.difference(today).inDays;

      if (installmentsRemaining != null && installmentsRemaining > 0) {
        // Si faltan N cuotas, la última vence N-1 meses después de nextDueDate
        final endMonth = nextDueDate.month + (installmentsRemaining - 1);
        final endYear = nextDueDate.year + ((endMonth - 1) ~/ 12);
        final normalizedMonth = ((endMonth - 1) % 12) + 1;
        estimatedEndDate = makeDate(endYear, normalizedMonth, dueDay);
      }
    }
  }

  return LoanProgress(
    paid: paid,
    balance: balance,
    installmentsPaid: installmentsPaid,
    installmentsRemaining: installmentsRemaining,
    percent: percent,
    isClosed: isClosed,
    nextDueDate: nextDueDate,
    estimatedEndDate: estimatedEndDate,
    daysUntilNextDue: daysUntilNextDue,
    nextInstallment: nextInstallment,
    paidBeforeCount: paidBeforeCount,
    paidBeforeAmount: paidBeforeAmount,
  );
}

/// Texto de cuotas de un préstamo. Si se terminó de pagar con adelantos antes
/// de completar las cuotas, no muestra las que "faltan".
String installmentsSummary({
  required int paid,
  required int? total,
  required bool closed,
}) {
  final count = total != null
      ? '$paid de $total cuotas'
      : '$paid cuota${paid == 1 ? '' : 's'}';
  if (!closed) return count;
  if (total != null && paid < total) return 'Pagado antes de tiempo · $count';
  return 'Pagado · $count';
}
