import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/loans/domain/loan_progress.dart';

void main() {
  late AppDatabase db;
  late LoansRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    repo = LoansRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('crear préstamo owe y registrar pagos hasta saldo 0 cierra el préstamo automáticamente', () async {
    final loanId = await repo.createLoan(
      direction: LoanDirection.owe,
      kind: LoanKind.installments,
      name: 'Smart TV',
      totalAmount: 300000,
      installmentAmount: 100000,
      installmentsTotal: 3,
      dueDay: 10,
      startDate: DateTime(2026, 1, 1),
    );

    var active = await repo.watchActive().first;
    expect(active.length, equals(1));
    expect(active.first.id, equals(loanId));
    expect(active.first.closedAt, isNull);

    // Pago 1: 100.000 Gs
    await repo.recordPayment(
      loanId: loanId,
      amount: 100000,
      date: DateTime(2026, 1, 10),
    );

    var loan = await repo.getLoan(loanId);
    expect(loan!.closedAt, isNull);

    // Pago 2: 200.000 Gs (completa el saldo de 300.000 Gs)
    await repo.recordPayment(
      loanId: loanId,
      amount: 200000,
      date: DateTime(2026, 2, 10),
      isExtra: true,
    );

    loan = await repo.getLoan(loanId);
    expect(loan!.closedAt, isNotNull);

    active = await repo.watchActive().first;
    expect(active, isEmpty);

    final closed = await repo.watchClosed().first;
    expect(closed.length, equals(1));
    expect(closed.first.id, equals(loanId));

    final payments = await repo.watchPayments(loanId).first;
    expect(payments.length, equals(2));
    expect(payments.any((p) => p.note == 'Pago extra'), isTrue);
    // El pago extra queda marcado en la columna, no solo en la nota.
    expect(payments.where((p) => p.isExtra).length, equals(1));
    expect(payments.where((p) => p.isExtra).first.note, equals('Pago extra'));
  });

  test('una cuota normal con "extra" en la nota no se guarda como pago extra', () async {
    final loanId = await repo.createLoan(
      direction: LoanDirection.owe,
      kind: LoanKind.installments,
      name: 'Auto',
      totalAmount: 1000000,
      installmentAmount: 100000,
      dueDay: 10,
      startDate: DateTime(2026, 1, 1),
    );

    await repo.recordPayment(
      loanId: loanId,
      amount: 110000,
      date: DateTime(2026, 2, 10),
      note: 'incluye extra por mora',
    );

    final payments = await repo.watchPayments(loanId).first;
    expect(payments.single.isExtra, isFalse);
    expect(payments.single.note, equals('incluye extra por mora'));
    final loan = await repo.getLoan(loanId);
    final progress = calculateLoanProgress(loan: loan!, payments: payments);
    expect(progress.installmentsPaid, equals(1));
  });

  test('crear préstamo lent con desembolso inicial genera gasto, y pagos son ingresos', () async {
    final loanId = await repo.createLoan(
      direction: LoanDirection.lent,
      kind: LoanKind.loan,
      name: 'Préstamo a Pedro',
      counterparty: 'Pedro',
      totalAmount: 500000,
      dueDay: 25,
      startDate: DateTime(2026, 2, 1),
      recordInitialDisbursement: true,
    );

    // Desembolso inicial registrado como gasto
    final allTxs = await db.select(db.transactions).get();
    expect(allTxs.length, equals(1));
    expect(allTxs.first.type, equals(TxType.expense));
    expect(allTxs.first.amount, equals(500000));

    // Registrar devolución (ingreso)
    final payId = await repo.recordPayment(
      loanId: loanId,
      amount: 250000,
      date: DateTime(2026, 2, 25),
    );

    final payTx = await (db.select(db.transactions)..where((t) => t.id.equals(payId))).getSingle();
    expect(payTx.type, equals(TxType.income));
    expect(payTx.amount, equals(250000));
    expect(payTx.loanId, equals(loanId));
  });
}
