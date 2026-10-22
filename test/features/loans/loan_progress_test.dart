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
      bool isExtra = false,
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
        isExtra: isExtra,
      );
    }

    test(
      'una cuota normal con "extra" en la nota sigue contando como cuota',
      () {
        final payments = [
          makePayment(id: 'p1', amount: 100000, date: DateTime(2026, 1, 15)),
          makePayment(
            id: 'p2',
            amount: 110000,
            date: DateTime(2026, 2, 15),
            note: 'incluye extra por mora',
          ),
        ];

        final progress = calculateLoanProgress(
          loan: baseLoan,
          payments: payments,
        );

        expect(progress.installmentsPaid, equals(2));
      },
    );

    test(
      'un pago marcado isExtra no cuenta como cuota aunque la nota no lo diga',
      () {
        final payments = [
          makePayment(id: 'p1', amount: 100000, date: DateTime(2026, 1, 15)),
          makePayment(
            id: 'p2',
            amount: 200000,
            date: DateTime(2026, 2, 20),
            isExtra: true,
          ),
        ];

        final progress = calculateLoanProgress(
          loan: baseLoan,
          payments: payments,
        );

        expect(progress.installmentsPaid, equals(1));
        expect(progress.paid, equals(300000));
      },
    );

    test('pagado, saldo y cuotas con pagos regulares y un extra', () {
      final payments = [
        makePayment(id: 'p1', amount: 100000, date: DateTime(2026, 1, 15)),
        makePayment(id: 'p2', amount: 100000, date: DateTime(2026, 2, 15)),
        makePayment(
          id: 'p3',
          amount: 200000,
          date: DateTime(2026, 2, 20),
          note: 'Pago extra adelanto',
          isExtra: true,
        ),
      ];

      final progress = calculateLoanProgress(
        loan: baseLoan,
        payments: payments,
      );

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

      final progress = calculateLoanProgress(
        loan: baseLoan,
        payments: payments,
      );

      expect(progress.paid, equals(1200000));
      expect(progress.balance, equals(0));
      expect(progress.percent, equals(1.0));
      expect(progress.isClosed, isTrue);
    });

    test(
      'un pago en préstamo lent (presté) es un ingreso que reduce el saldo',
      () {
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

        final progress = calculateLoanProgress(
          loan: lentLoan,
          payments: payments,
        );

        expect(progress.paid, equals(200000));
        expect(progress.balance, equals(300000));
        expect(progress.isClosed, isFalse);
      },
    );

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

    test('préstamo con cronograma calcula próxima cuota, vencimiento, restantes y fin estimado', () {
      final schedule = [
        LoanInstallment(loanId: 'loan-sched', number: 1, dueDate: DateTime(2027, 1, 2), amount: 905000),
        LoanInstallment(loanId: 'loan-sched', number: 2, dueDate: DateTime(2027, 2, 2), amount: 805000),
        LoanInstallment(loanId: 'loan-sched', number: 3, dueDate: DateTime(2027, 3, 2), amount: 705000),
      ];

      final schedLoan = Loan(
        id: 'loan-sched',
        direction: LoanDirection.owe,
        kind: LoanKind.installments,
        name: 'Préstamo Itaú',
        totalAmount: 905000 + 805000 + 705000,
        installmentAmount: null,
        installmentsTotal: 3,
        dueDay: 2,
        startDate: DateTime(2027, 1, 1),
        reminderDays: 2,
        createdAt: DateTime(2027, 1, 1),
        updatedAt: DateTime(2027, 1, 1),
      );

      // Sin pagos: próxima cuota es la 1
      final p0 = calculateLoanProgress(
        loan: schedLoan,
        payments: [],
        schedule: schedule,
        now: DateTime(2026, 12, 28),
      );
      expect(p0.installmentsPaid, 0);
      expect(p0.installmentsRemaining, 3);
      expect(p0.nextInstallment, equals(schedule[0]));
      expect(p0.nextDueDate, DateTime(2027, 1, 2));
      expect(p0.daysUntilNextDue, 5);
      expect(p0.estimatedEndDate, DateTime(2027, 3, 2));

      // 1 pago regular + 1 extra: próxima cuota es la 2 (el extra no avanza la cuota)
      final p1 = calculateLoanProgress(
        loan: schedLoan,
        payments: [
          makePayment(id: 'p1', amount: 905000, date: DateTime(2027, 1, 2)),
          makePayment(id: 'p-extra', amount: 100000, date: DateTime(2027, 1, 15), isExtra: true),
        ],
        schedule: schedule,
        now: DateTime(2027, 1, 20),
      );
      expect(p1.installmentsPaid, 1);
      expect(p1.installmentsRemaining, 2);
      expect(p1.nextInstallment, equals(schedule[1]));
      expect(p1.nextDueDate, DateTime(2027, 2, 2));
      expect(p1.estimatedEndDate, DateTime(2027, 3, 2));

      // Pagadas todas las cuotas
      final pAll = calculateLoanProgress(
        loan: schedLoan,
        payments: [
          makePayment(id: 'p1', amount: 905000, date: DateTime(2027, 1, 2)),
          makePayment(id: 'p2', amount: 805000, date: DateTime(2027, 2, 2)),
          makePayment(id: 'p3', amount: 705000, date: DateTime(2027, 3, 2)),
        ],
        schedule: schedule,
        now: DateTime(2027, 3, 2),
      );
      expect(pAll.isClosed, isTrue);
      expect(pAll.nextInstallment, isNull);
      expect(pAll.nextDueDate, isNull);
      expect(pAll.installmentsRemaining, 0);
      expect(pAll.estimatedEndDate, DateTime(2027, 3, 2));
    });
  });

  group('installmentsSummary', () {
    test('en curso muestra N de M cuotas', () {
      expect(
        installmentsSummary(paid: 5, total: 12, closed: false),
        '5 de 12 cuotas',
      );
    });
    test('terminado con adelantos no muestra cuotas faltantes', () {
      expect(
        installmentsSummary(paid: 5, total: 12, closed: true),
        'Pagado antes de tiempo · 5 de 12 cuotas',
      );
    });
    test('terminado con todas las cuotas', () {
      expect(
        installmentsSummary(paid: 12, total: 12, closed: true),
        'Pagado · 12 de 12 cuotas',
      );
    });
    test('sin cantidad de cuotas', () {
      expect(
        installmentsSummary(paid: 1, total: null, closed: false),
        '1 cuota',
      );
      expect(
        installmentsSummary(paid: 3, total: null, closed: true),
        'Pagado · 3 cuotas',
      );
    });
  });
}
