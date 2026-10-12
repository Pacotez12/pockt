import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/loans/domain/loan_progress.dart';

void main() {
  group('LoanProgress domain logic', () {
    final baseLoan = Loan(
      id: 'loan-1',
      direction: LoanDirection.owe,
      kind: LoanKind.installments,
      name: 'Heladera en cuotas',
      counterparty: 'Bristol',
      totalAmount: 1200000,
      installmentAmount: 100000,
      installmentsTotal: 12,
      dueDay: 15,
      startDate: DateTime(2026, 1, 1),
      reminderDays: 2,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    Transaction makePayment({
      required String id,
      required int amount,
      required DateTime date,
      String? note,
      TxType type = TxType.expense,
    }) {
      return Transaction(
        id: id,
        type: type,
        amount: amount,
        currency: 'PYG',
        categoryId: 'cat-prestamos',
        loanId: 'loan-1',
        occurredAt: date,
        createdAt: date,
        updatedAt: date,
        source: TxSource.manual,
        note: note,
      );
    }

    test('pagado, saldo y cuotas con pagos regulares y un extra', () {
      final payments = [
        makePayment(id: 'p1', amount: 100000, date: DateTime(2026, 1, 15)),
        makePayment(id: 'p2', amount: 100000, date: DateTime(2026, 2, 15)),
        makePayment(id: 'p3', amount: 200000, date: DateTime(2026, 2, 20), note: 'Pago extra adelanto'),
      ];

      final progress = calculateLoanProgress(loan: baseLoan, payments: payments);

      // Total pagado: 100k + 100k + 200k = 400.000 Gs
      expect(progress.paid, equals(400000));
      // Saldo restante: 1.200.000 - 400.000 = 800.000 Gs
      expect(progress.balance, equals(800000));
      // Cuotas regulares pagadas: 2 (el pago extra no suma cuota regular, pero sí baja el saldo)
      expect(progress.installmentsPaid, equals(2));
      // Cuotas restantes teóricas: 800k / 100k = 8 cuotas
      expect(progress.installmentsRemaining, equals(8));
      // Porcentaje pagado: 400k / 1.2M = 33.33%
      expect(progress.percent, closeTo(0.333, 0.005));
      expect(progress.isClosed, isFalse);
    });

    test('fin estimado calcula meses desde el próximo vencimiento', () {
      final payments = [
        makePayment(id: 'p1', amount: 100000, date: DateTime(2026, 1, 15)),
        makePayment(id: 'p2', amount: 100000, date: DateTime(2026, 2, 15)),
      ];

      // Saldo restante: 1.000.000 Gs -> 10 cuotas restantes de 100.000 Gs
      // A fecha 1 de marzo 2026 con dueDay = 15:
      // Próximo vencimiento: 15 de marzo 2026 (mes 1 de 10).
      // Cuota 10 (última) vence en diciembre 2026.
      final progress = calculateLoanProgress(
        loan: baseLoan,
        payments: payments,
        now: DateTime(2026, 3, 1),
      );

      expect(progress.estimatedEndDate, isNotNull);
      expect(progress.estimatedEndDate!.year, equals(2026));
      expect(progress.estimatedEndDate!.month, equals(12));
      expect(progress.estimatedEndDate!.day, equals(15));
    });

    test('saldo 0 o negativo cierra el préstamo', () {
      final payments = [
        makePayment(id: 'p1', amount: 1200000, date: DateTime(2026, 1, 15)),
      ];

      final progress = calculateLoanProgress(loan: baseLoan, payments: payments);

      expect(progress.paid, equals(1200000));
      expect(progress.balance, equals(0));
      expect(progress.percent, equals(1.0));
      expect(progress.isClosed, isTrue);
    });

    test('un pago en préstamo lent (presté) es un ingreso que reduce el saldo', () {
      final lentLoan = Loan(
        id: 'loan-lent',
        direction: LoanDirection.lent,
        kind: LoanKind.loan,
        name: 'Préstamo a Juan',
        counterparty: 'Juan',
        totalAmount: 500000,
        installmentAmount: null,
        installmentsTotal: null,
        dueDay: 20,
        startDate: DateTime(2026, 2, 1),
        reminderDays: 2,
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
      );

      final payments = [
        makePayment(
          id: 'p-in-1',
          amount: 200000,
          date: DateTime(2026, 2, 20),
          type: TxType.income,
        ),
      ];

      final progress = calculateLoanProgress(loan: lentLoan, payments: payments);

      expect(progress.paid, equals(200000));
      expect(progress.balance, equals(300000));
      expect(progress.isClosed, isFalse);
    });
  
    test('si la cuota del mes ya está pagada, el próximo vencimiento pasa al mes siguiente', () {
      final payments = [
        makePayment(id: 'p1', amount: 100000, date: DateTime(2026, 10, 3)),
      ];
      final progress = calculateLoanProgress(
        loan: baseLoan,
        payments: payments,
        now: DateTime(2026, 10, 12),
      );
      expect(progress.nextDueDate, DateTime(2026, 11, 15));
      expect(progress.daysUntilNextDue, 34);
    });
});
}
