import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/loans/domain/loan_progress.dart';
import 'package:pockt/features/loans/domain/loan_reminders.dart';
import 'package:uuid/uuid.dart';

class LoansRepository {
  final AppDatabase _db;
  final Notifier? notifier;
  final _uuid = const Uuid();

  LoansRepository(this._db, {this.notifier});

  Future<void> _triggerRemindersUpdate() async {
    final notif = notifier;
    if (notif != null) {
      try {
        await rescheduleLoanReminders(
          db: _db,
          notifier: notif,
          settingsRepo: SettingsRepository(_db),
          nowLocal: DateTime.now(),
        );
      } catch (_) {}
    }
  }

  Future<List<Loan>> getActive({LoanDirection? direction}) async {
    final query = _db.select(_db.loans)
      ..where((l) => l.closedAt.isNull());
    if (direction != null) {
      query.where((l) => l.direction.equals(direction.name));
    }
    query.orderBy([
      (l) => OrderingTerm.asc(l.dueDay),
      (l) => OrderingTerm.asc(l.startDate),
    ]);
    return query.get();
  }

  Stream<List<Loan>> watchActive({LoanDirection? direction}) {
    final query = _db.select(_db.loans)
      ..where((l) => l.closedAt.isNull());
    if (direction != null) {
      query.where((l) => l.direction.equals(direction.name));
    }
    query.orderBy([
      (l) => OrderingTerm.asc(l.dueDay),
      (l) => OrderingTerm.asc(l.startDate),
    ]);
    return query.watch();
  }

  Stream<List<LoanWithProgress>> watchActiveWithProgress() {
    final query = _db.select(_db.loans)
      ..where((l) => l.closedAt.isNull());
    return query
        .join([
          leftOuterJoin(
            _db.transactions,
            _db.transactions.loanId.equalsExp(_db.loans.id) &
                _db.transactions.deletedAt.isNull(),
          ),
        ])
        .watch()
        .map((rows) {
          final Map<String, Loan> loansMap = {};
          final Map<String, List<Transaction>> paymentsMap = {};

          for (final row in rows) {
            final loan = row.readTable(_db.loans);
            loansMap[loan.id] = loan;
            final tx = row.readTableOrNull(_db.transactions);
            if (tx != null) {
              paymentsMap.putIfAbsent(loan.id, () => []).add(tx);
            }
          }

          final now = DateTime.now();
          final list = <LoanWithProgress>[];
          for (final loan in loansMap.values) {
            final payments = paymentsMap[loan.id] ?? const [];
            final progress = calculateLoanProgress(loan: loan, payments: payments, now: now);
            if (!progress.isClosed) {
              list.add(LoanWithProgress(loan: loan, progress: progress));
            }
          }
          return list;
        });
  }

  Stream<List<Loan>> watchClosed() {
    final query = _db.select(_db.loans)
      ..where((l) => l.closedAt.isNotNull())
      ..orderBy([(l) => OrderingTerm.desc(l.closedAt)]);
    return query.watch();
  }

  Stream<List<Transaction>> watchPayments(String loanId) {
    final query = _db.select(_db.transactions)
      ..where((t) => t.loanId.equals(loanId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    return query.watch();
  }

  Stream<Loan?> watchLoan(String id) {
    return (_db.select(_db.loans)..where((l) => l.id.equals(id))).watchSingleOrNull();
  }

  Future<Loan?> getLoan(String id) {
    return (_db.select(_db.loans)..where((l) => l.id.equals(id))).getSingleOrNull();
  }

  Future<String> createLoan({
    required LoanDirection direction,
    required LoanKind kind,
    required String name,
    String? counterparty,
    required int totalAmount,
    int? installmentAmount,
    int? installmentsTotal,
    int? dueDay,
    required DateTime startDate,
    int reminderDays = 2,
    bool recordInitialDisbursement = false,
  }) async {
    final loanId = _uuid.v4();
    final now = DateTime.now();

    await _db.into(_db.loans).insert(
      LoansCompanion.insert(
        id: loanId,
        direction: direction,
        kind: kind,
        name: name,
        counterparty: Value(counterparty),
        totalAmount: totalAmount,
        installmentAmount: Value(installmentAmount),
        installmentsTotal: Value(installmentsTotal),
        dueDay: Value(dueDay),
        startDate: startDate,
        reminderDays: Value(reminderDays),
        createdAt: now,
        updatedAt: now,
      ),
    );

    if (direction == LoanDirection.lent && recordInitialDisbursement) {
      // Registrar salida inicial como gasto en categoría "Préstamos"
      final prestamosCat = await _getPrestamosCategoryId();
      await _db.into(_db.transactions).insert(
        TransactionsCompanion.insert(
          id: _uuid.v4(),
          type: TxType.expense,
          amount: totalAmount,
          categoryId: prestamosCat,
          occurredAt: startDate,
          createdAt: now,
          updatedAt: now,
          source: TxSource.manual,
          note: Value('Préstamo a ${counterparty ?? name}'),
        ),
      );
    }

    await _triggerRemindersUpdate();
    return loanId;
  }

  Future<void> updateLoan({
    required String id,
    String? name,
    String? counterparty,
    int? totalAmount,
    int? installmentAmount,
    int? installmentsTotal,
    int? dueDay,
    int? reminderDays,
  }) async {
    final companion = LoansCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      counterparty: Value(counterparty),
      totalAmount: totalAmount != null ? Value(totalAmount) : const Value.absent(),
      installmentAmount: Value(installmentAmount),
      installmentsTotal: Value(installmentsTotal),
      dueDay: Value(dueDay),
      reminderDays: reminderDays != null ? Value(reminderDays) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    await (_db.update(_db.loans)..where((l) => l.id.equals(id))).write(companion);
    await _triggerRemindersUpdate();
  }

  Future<void> closeLoan(String id, {DateTime? closedAt}) async {
    await (_db.update(_db.loans)..where((l) => l.id.equals(id))).write(
      LoansCompanion(
        closedAt: Value(closedAt ?? DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _triggerRemindersUpdate();
  }

  Future<void> reopenLoan(String id) async {
    await (_db.update(_db.loans)..where((l) => l.id.equals(id))).write(
      LoansCompanion(
        closedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _triggerRemindersUpdate();
  }

  Future<void> deleteLoan(String id) async {
    // Desvincular pagos
    await (_db.update(_db.transactions)..where((t) => t.loanId.equals(id))).write(
      const TransactionsCompanion(loanId: Value(null)),
    );
    await (_db.delete(_db.loans)..where((l) => l.id.equals(id))).go();
    await _triggerRemindersUpdate();
  }

  Future<String> recordPayment({
    required String loanId,
    required int amount,
    required DateTime date,
    bool isExtra = false,
    String? note,
  }) async {
    final loan = await getLoan(loanId);
    if (loan == null) throw ArgumentError('Préstamo no encontrado: $loanId');

    final now = DateTime.now();
    final txId = _uuid.v4();

    final categoryId = await _getPrestamosCategoryId();
    final type = loan.direction == LoanDirection.owe ? TxType.expense : TxType.income;

    final noteText = isExtra
        ? (note != null && note.trim().isNotEmpty ? '$note (Pago extra)' : 'Pago extra')
        : note;

    await _db.into(_db.transactions).insert(
      TransactionsCompanion.insert(
        id: txId,
        type: type,
        amount: amount,
        categoryId: categoryId,
        occurredAt: date,
        createdAt: now,
        updatedAt: now,
        source: TxSource.manual,
        loanId: Value(loanId),
        note: Value(noteText),
      ),
    );

    // Verificar si el saldo llegó a 0 para cerrar automáticamente
    final allPayments = await (_db.select(_db.transactions)
          ..where((t) => t.loanId.equals(loanId) & t.deletedAt.isNull()))
        .get();

    final progress = calculateLoanProgress(loan: loan, payments: allPayments, now: date);
    if (progress.balance <= 0 && loan.closedAt == null) {
      await closeLoan(loanId, closedAt: date);
    } else {
      await _triggerRemindersUpdate();
    }

    return txId;
  }

  Future<String> _getPrestamosCategoryId() async {
    final cat = await (_db.select(_db.categories)..where((c) => c.name.equals('Préstamos'))).getSingleOrNull();
    if (cat != null) return cat.id;

    // Fallback: primera categoría de gasto
    final firstExpense = await (_db.select(_db.categories)..where((c) => c.kind.equals(CategoryKind.expense.name))).get();
    return firstExpense.first.id;
  }
}

final loansRepositoryProvider = Provider<LoansRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final notifier = ref.watch(notifierProvider);
  return LoansRepository(db, notifier: notifier);
});

final activeLoansProvider = StreamProvider.family<List<Loan>, LoanDirection?>((ref, direction) {
  final repo = ref.watch(loansRepositoryProvider);
  return repo.watchActive(direction: direction);
});

final closedLoansProvider = StreamProvider<List<Loan>>((ref) {
  final repo = ref.watch(loansRepositoryProvider);
  return repo.watchClosed();
});

final loanPaymentsProvider = StreamProvider.family<List<Transaction>, String>((ref, loanId) {
  final repo = ref.watch(loansRepositoryProvider);
  return repo.watchPayments(loanId);
});

final loanProvider = StreamProvider.family<Loan?, String>((ref, loanId) {
  final repo = ref.watch(loansRepositoryProvider);
  return repo.watchLoan(loanId);
});

class LoanWithProgress {
  final Loan loan;
  final LoanProgress progress;

  const LoanWithProgress({
    required this.loan,
    required this.progress,
  });
}

final activeLoansWithProgressProvider = StreamProvider<List<LoanWithProgress>>((ref) {
  final repo = ref.watch(loansRepositoryProvider);
  return repo.watchActiveWithProgress();
});

