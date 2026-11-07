import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/loans/domain/loan_progress.dart';

Loan _loan({
  required String id,
  required String name,
  required LoanKind kind,
  required LoanDirection direction,
  required int totalAmount,
  int? installmentAmount,
  int? installmentsTotal,
  int? dueDay,
  required DateTime startDate,
  int paidBeforeCount = 0,
  DateTime? closedAt,
}) {
  return Loan(
    id: id,
    name: name,
    kind: kind,
    direction: direction,
    totalAmount: totalAmount,
    installmentAmount: installmentAmount,
    installmentsTotal: installmentsTotal,
    dueDay: dueDay,
    startDate: startDate,
    paidBeforeCount: paidBeforeCount,
    closedAt: closedAt,
    reminderDays: 3,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

Transaction _tx({
  required String id,
  required TxType type,
  required int amount,
  required DateTime occurredAt,
  bool isExtra = false,
  DateTime? deletedAt,
}) {
  return Transaction(
    id: id,
    type: type,
    amount: amount,
    occurredAt: occurredAt,
    categoryId: 'c_prestamo',
    isExtra: isExtra,
    deletedAt: deletedAt,
    currency: 'PYG',
    source: TxSource.manual,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

LoanInstallment _inst({
  required String id,
  required String loanId,
  required int number,
  required DateTime dueDate,
  required int amount,
}) {
  return LoanInstallment(
    id: id,
    loanId: loanId,
    number: number,
    dueDate: dueDate,
    amount: amount,
  );
}

void main() {
  test('loan_progress golden test', () {
    final now = DateTime(2026, 10, 15);

    final rawCases = [
      {
        'name': 'préstamo cuotas con cronograma y pagos regulares',
        'loan': {
          'id': 'l1',
          'name': 'Préstamo Auto',
          'kind': 'installments',
          'direction': 'owe',
          'totalAmount': 12000000,
          'installmentAmount': 1000000,
          'installmentsTotal': 12,
          'dueDay': 20,
          'startDate': '2026-05-01',
          'paidBeforeCount': 0,
          'closedAt': null,
        },
        'schedule': [
          for (var i = 1; i <= 12; i++)
            {
              'id': 'l1:$i',
              'loanId': 'l1',
              'number': i,
              'dueDate':
                  '${2026 + ((i + 3) ~/ 12)}-${(((i + 3) % 12) + 1).toString().padLeft(2, '0')}-20',
              'amount': 1000000,
            }
        ],
        'payments': [
          {'id': 'p1', 'type': 'expense', 'amount': 1000000, 'occurredAt': '2026-05-19', 'isExtra': false},
          {'id': 'p2', 'type': 'expense', 'amount': 1000000, 'occurredAt': '2026-06-20', 'isExtra': false},
        ],
      },
      {
        'name': 'préstamo con cuotas previas pagadas (paidBeforeCount > 0)',
        'loan': {
          'id': 'l2',
          'name': 'Préstamo Moto',
          'kind': 'installments',
          'direction': 'owe',
          'totalAmount': 9000000,
          'installmentAmount': 500000,
          'installmentsTotal': 18,
          'dueDay': 25,
          'startDate': '2026-01-01',
          'paidBeforeCount': 5,
          'closedAt': null,
        },
        'schedule': <Map<String, dynamic>>[],
        'payments': [
          {'id': 'p3', 'type': 'expense', 'amount': 500000, 'occurredAt': '2026-06-24', 'isExtra': false},
        ],
      },
      {
        'name': 'préstamo con cronograma variable y adelanto extra (isExtra = true)',
        'loan': {
          'id': 'l3',
          'name': 'Préstamo Variable',
          'kind': 'installments',
          'direction': 'owe',
          'totalAmount': 5000000,
          'installmentAmount': null,
          'installmentsTotal': 4,
          'dueDay': 10,
          'startDate': '2026-07-01',
          'paidBeforeCount': 0,
          'closedAt': null,
        },
        'schedule': [
          {'id': 'l3:1', 'loanId': 'l3', 'number': 1, 'dueDate': '2026-08-10', 'amount': 2000000},
          {'id': 'l3:2', 'loanId': 'l3', 'number': 2, 'dueDate': '2026-09-10', 'amount': 1500000},
          {'id': 'l3:3', 'loanId': 'l3', 'number': 3, 'dueDate': '2026-10-10', 'amount': 1000000},
          {'id': 'l3:4', 'loanId': 'l3', 'number': 4, 'dueDate': '2026-11-10', 'amount': 500000},
        ],
        'payments': [
          {'id': 'p4', 'type': 'expense', 'amount': 2000000, 'occurredAt': '2026-08-09', 'isExtra': false},
          {'id': 'p5', 'type': 'expense', 'amount': 1000000, 'occurredAt': '2026-08-15', 'isExtra': true},
        ],
      },
      {
        'name': 'préstamo prestado a amigo (direction = lent, pagos son ingresos)',
        'loan': {
          'id': 'l4',
          'name': 'Préstamo a Juan',
          'kind': 'loan',
          'direction': 'lent',
          'totalAmount': 2000000,
          'installmentAmount': null,
          'installmentsTotal': null,
          'dueDay': 15,
          'startDate': '2026-08-01',
          'paidBeforeCount': 0,
          'closedAt': null,
        },
        'schedule': <Map<String, dynamic>>[],
        'payments': [
          {'id': 'p6', 'type': 'income', 'amount': 800000, 'occurredAt': '2026-09-01', 'isExtra': false},
          {'id': 'p7', 'type': 'expense', 'amount': 500000, 'occurredAt': '2026-09-05', 'isExtra': false}, // egreso ignorado
        ],
      },
      {
        'name': 'préstamo cerrado o completado (balance <= 0)',
        'loan': {
          'id': 'l5',
          'name': 'Préstamo Saldado',
          'kind': 'installments',
          'direction': 'owe',
          'totalAmount': 3000000,
          'installmentAmount': 1000000,
          'installmentsTotal': 3,
          'dueDay': 5,
          'startDate': '2026-01-01',
          'paidBeforeCount': 0,
          'closedAt': '2026-04-01',
        },
        'schedule': [
          {'id': 'l5:1', 'loanId': 'l5', 'number': 1, 'dueDate': '2026-02-05', 'amount': 1000000},
          {'id': 'l5:2', 'loanId': 'l5', 'number': 2, 'dueDate': '2026-03-05', 'amount': 1000000},
          {'id': 'l5:3', 'loanId': 'l5', 'number': 3, 'dueDate': '2026-04-05', 'amount': 1000000},
        ],
        'payments': [
          {'id': 'p8', 'type': 'expense', 'amount': 3000000, 'occurredAt': '2026-03-30', 'isExtra': false},
        ],
      },
      {
        'name': 'préstamo sin cronograma con cuota fija y fecha de vencimiento futura',
        'loan': {
          'id': 'l6',
          'name': 'Préstamo Personal',
          'kind': 'installments',
          'direction': 'owe',
          'totalAmount': 6000000,
          'installmentAmount': 1000000,
          'installmentsTotal': 6,
          'dueDay': 28,
          'startDate': '2026-09-01',
          'paidBeforeCount': 0,
          'closedAt': null,
        },
        'schedule': <Map<String, dynamic>>[],
        'payments': [
          {'id': 'p9', 'type': 'expense', 'amount': 1000000, 'occurredAt': '2026-09-27', 'isExtra': false},
        ],
      },
    ];

    final goldenFile = File('shared/golden/loan_progress.json');
    if (!goldenFile.existsSync()) {
      final cases = <Map<String, dynamic>>[];
      for (final rc in rawCases) {
        final lMap = rc['loan'] as Map<String, dynamic>;
        final loan = _loan(
          id: lMap['id'],
          name: lMap['name'],
          kind: lMap['kind'] == 'installments' ? LoanKind.installments : LoanKind.loan,
          direction: lMap['direction'] == 'owe' ? LoanDirection.owe : LoanDirection.lent,
          totalAmount: lMap['totalAmount'],
          installmentAmount: lMap['installmentAmount'],
          installmentsTotal: lMap['installmentsTotal'],
          dueDay: lMap['dueDay'],
          startDate: DateTime.parse(lMap['startDate']),
          paidBeforeCount: lMap['paidBeforeCount'] ?? 0,
          closedAt: lMap['closedAt'] != null ? DateTime.parse(lMap['closedAt']) : null,
        );

        final sList = (rc['schedule'] as List).map((s) {
          final sm = s as Map<String, dynamic>;
          return _inst(
            id: sm['id'],
            loanId: sm['loanId'],
            number: sm['number'],
            dueDate: DateTime.parse(sm['dueDate']),
            amount: sm['amount'],
          );
        }).toList();

        final pList = (rc['payments'] as List).map((p) {
          final pm = p as Map<String, dynamic>;
          return _tx(
            id: pm['id'],
            type: pm['type'] == 'expense' ? TxType.expense : TxType.income,
            amount: pm['amount'],
            occurredAt: DateTime.parse(pm['occurredAt']),
            isExtra: pm['isExtra'] ?? false,
          );
        }).toList();

        final progress = calculateLoanProgress(
          loan: loan,
          payments: pList,
          schedule: sList.isNotEmpty ? sList : null,
          now: now,
        );

        String? fmt(DateTime? d) => d != null
            ? '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
            : null;

        cases.add({
          'name': rc['name'],
          'input': {
            'loan': rc['loan'],
            'schedule': rc['schedule'],
            'payments': rc['payments'],
            'now': '2026-10-15',
          },
          'expected': {
            'paid': progress.paid,
            'balance': progress.balance,
            'installmentsPaid': progress.installmentsPaid,
            'installmentsRemaining': progress.installmentsRemaining,
            'percent': (progress.percent * 1000).round() / 1000,
            'isClosed': progress.isClosed,
            'nextDueDate': fmt(progress.nextDueDate),
            'estimatedEndDate': fmt(progress.estimatedEndDate),
            'daysUntilNextDue': progress.daysUntilNextDue,
            'paidBeforeCount': progress.paidBeforeCount,
            'paidBeforeAmount': progress.paidBeforeAmount,
          },
        });
      }
      goldenFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'cases': cases}));
    }

    final data = jsonDecode(goldenFile.readAsStringSync()) as Map<String, dynamic>;
    final cases = data['cases'] as List<dynamic>;
    expect(cases.length, greaterThanOrEqualTo(6));

    for (final c in cases) {
      final name = c['name'] as String;
      final input = c['input'] as Map<String, dynamic>;
      final lMap = input['loan'] as Map<String, dynamic>;
      final loan = _loan(
        id: lMap['id'],
        name: lMap['name'],
        kind: lMap['kind'] == 'installments' ? LoanKind.installments : LoanKind.loan,
        direction: lMap['direction'] == 'owe' ? LoanDirection.owe : LoanDirection.lent,
        totalAmount: lMap['totalAmount'],
        installmentAmount: lMap['installmentAmount'],
        installmentsTotal: lMap['installmentsTotal'],
        dueDay: lMap['dueDay'],
        startDate: DateTime.parse(lMap['startDate']),
        paidBeforeCount: lMap['paidBeforeCount'] ?? 0,
        closedAt: lMap['closedAt'] != null ? DateTime.parse(lMap['closedAt']) : null,
      );

      final sList = (input['schedule'] as List).map((s) {
        final sm = s as Map<String, dynamic>;
        return _inst(
          id: sm['id'],
          loanId: sm['loanId'],
          number: sm['number'],
          dueDate: DateTime.parse(sm['dueDate']),
          amount: sm['amount'],
        );
      }).toList();

      final pList = (input['payments'] as List).map((p) {
        final pm = p as Map<String, dynamic>;
        return _tx(
          id: pm['id'],
          type: pm['type'] == 'expense' ? TxType.expense : TxType.income,
          amount: pm['amount'],
          occurredAt: DateTime.parse(pm['occurredAt']),
          isExtra: pm['isExtra'] ?? false,
        );
      }).toList();

      final actual = calculateLoanProgress(
        loan: loan,
        payments: pList,
        schedule: sList.isNotEmpty ? sList : null,
        now: DateTime.parse(input['now']),
      );

      final exp = c['expected'] as Map<String, dynamic>;
      String? fmt(DateTime? d) => d != null
          ? '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
          : null;

      expect(actual.paid, equals(exp['paid']), reason: '$name: paid');
      expect(actual.balance, equals(exp['balance']), reason: '$name: balance');
      expect(actual.installmentsPaid, equals(exp['installmentsPaid']), reason: '$name: installmentsPaid');
      expect(actual.installmentsRemaining, equals(exp['installmentsRemaining']), reason: '$name: installmentsRemaining');
      expect((actual.percent * 1000).round() / 1000, equals(exp['percent']), reason: '$name: percent');
      expect(actual.isClosed, equals(exp['isClosed']), reason: '$name: isClosed');
      expect(fmt(actual.nextDueDate), equals(exp['nextDueDate']), reason: '$name: nextDueDate');
      expect(fmt(actual.estimatedEndDate), equals(exp['estimatedEndDate']), reason: '$name: estimatedEndDate');
      expect(actual.daysUntilNextDue, equals(exp['daysUntilNextDue']), reason: '$name: daysUntilNextDue');
      expect(actual.paidBeforeCount, equals(exp['paidBeforeCount']), reason: '$name: paidBeforeCount');
      expect(actual.paidBeforeAmount, equals(exp['paidBeforeAmount']), reason: '$name: paidBeforeAmount');
    }
  });
}
