import 'dart:math';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';

/// Helper para detectar si un movimiento ligado a un préstamo es un pago extra / adelanto.
bool isLoanExtraPayment(Transaction tx) {
  final note = tx.note?.toLowerCase();
  if (note == null) return false;
  return note.contains('extra') || note.contains('adelanto');
}

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
  });
}

/// Calcula el avance de un préstamo a partir de sus pagos ligados.
LoanProgress calculateLoanProgress({
  required Loan loan,
  required List<Transaction> payments,
  DateTime? now,
}) {
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

  final paid = relevantPayments.fold<int>(0, (sum, p) => sum + p.amount);
  final balance = max(0, loan.totalAmount - paid);
  final isClosed = balance <= 0 || loan.closedAt != null;

  // Cuotas pagadas: solo pagos regulares (los extra no suman cuota, pero sí bajan el saldo)
  final regularPaymentsCount = relevantPayments.where((p) => !isLoanExtraPayment(p)).length;
  final installmentsPaid = loan.installmentsTotal != null
      ? min(loan.installmentsTotal!, regularPaymentsCount)
      : regularPaymentsCount;

  int? installmentsRemaining;
  if (loan.installmentAmount != null && loan.installmentAmount! > 0) {
    installmentsRemaining = (balance / loan.installmentAmount!).ceil();
  } else if (loan.installmentsTotal != null) {
    installmentsRemaining = max(0, loan.installmentsTotal! - installmentsPaid);
  }

  final percent = loan.totalAmount > 0
      ? (paid / loan.totalAmount).clamp(0.0, 1.0)
      : 1.0;

  DateTime? nextDueDate;
  int? daysUntilNextDue;
  DateTime? estimatedEndDate;

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
    final paidThisMonth = relevantPayments.any((p) =>
        !isLoanExtraPayment(p) &&
        p.occurredAt.year == today.year &&
        p.occurredAt.month == today.month);
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
  );
}
