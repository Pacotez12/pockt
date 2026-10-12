import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/loans/domain/loan_reminders.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('planLoanReminder (lógica pura de avisos de préstamos)', () {
    const quietStart = (h: 23, m: 0);
    const quietEnd = (h: 9, m: 0);

    test('aviso 2 días antes por defecto a las 09:00', () {
      final now = DateTime(2026, 10, 5, 10, 0);
      final loan = Loan(
        id: 'loan-1',
        direction: LoanDirection.owe,
        kind: LoanKind.installments,
        name: 'Préstamo Auto',
        totalAmount: 12000000,
        installmentAmount: 1000000,
        dueDay: 15,
        reminderDays: 2,
        startDate: DateTime(2026, 10, 1),
        createdAt: now,
        updatedAt: now,
      );

      final reminder = planLoanReminder(
        loan: loan,
        payments: const [],
        nowLocal: now,
        quietStart: quietStart,
        quietEnd: quietEnd,
      );

      expect(reminder, isNotNull);
      // 15 de octubre - 2 días = 13 de octubre a las 09:00
      expect(reminder!.atLocal, DateTime(2026, 10, 13, 9, 0));
      expect(reminder.title, contains('Préstamo Auto'));
      expect(reminder.body, contains('1.000.000'));
      expect(reminder.body, contains('vence en 2 días'));
    });

    test('no se programa si ya se pagó la cuota del mes', () {
      final now = DateTime(2026, 10, 5, 10, 0);
      final loan = Loan(
        id: 'loan-1',
        direction: LoanDirection.owe,
        kind: LoanKind.installments,
        name: 'Préstamo Auto',
        totalAmount: 12000000,
        installmentAmount: 1000000,
        dueDay: 15,
        reminderDays: 2,
        startDate: DateTime(2026, 10, 1),
        createdAt: now,
        updatedAt: now,
      );

      // Pago regular realizado en octubre
      final payment = Transaction(
        id: 'tx-1',
        type: TxType.expense,
        amount: 1000000,
        categoryId: 'cat-1',
        occurredAt: DateTime(2026, 10, 3, 11, 0),
        createdAt: now,
        updatedAt: now,
        source: TxSource.manual,
        currency: 'PYG',
        loanId: 'loan-1',
      );

      final reminder = planLoanReminder(
        loan: loan,
        payments: [payment],
        nowLocal: now,
        quietStart: quietStart,
        quietEnd: quietEnd,
      );

      // No debe programarse para octubre porque la cuota del mes ya está pagada
      expect(reminder, isNull);
    });

    test('un pago extra no cuenta como cuota del mes pagada y el aviso sí se programa', () {
      final now = DateTime(2026, 10, 5, 10, 0);
      final loan = Loan(
        id: 'loan-1',
        direction: LoanDirection.owe,
        kind: LoanKind.installments,
        name: 'Préstamo Auto',
        totalAmount: 12000000,
        installmentAmount: 1000000,
        dueDay: 15,
        reminderDays: 2,
        startDate: DateTime(2026, 10, 1),
        createdAt: now,
        updatedAt: now,
      );

      // Pago EXTRA en octubre
      final extraPayment = Transaction(
        id: 'tx-extra',
        type: TxType.expense,
        amount: 500000,
        categoryId: 'cat-1',
        occurredAt: DateTime(2026, 10, 3, 11, 0),
        createdAt: now,
        updatedAt: now,
        source: TxSource.manual,
        currency: 'PYG',
        loanId: 'loan-1',
        note: 'Pago extra adelanto',
      );

      final reminder = planLoanReminder(
        loan: loan,
        payments: [extraPayment],
        nowLocal: now,
        quietStart: quietStart,
        quietEnd: quietEnd,
      );

      expect(reminder, isNotNull);
      expect(reminder!.atLocal, DateTime(2026, 10, 13, 9, 0));
    });

    test('respeta el horario de silencio corriendo la hora si cae dentro', () {
      final now = DateTime(2026, 10, 5, 10, 0);
      final loan = Loan(
        id: 'loan-1',
        direction: LoanDirection.owe,
        kind: LoanKind.installments,
        name: 'Préstamo Auto',
        totalAmount: 12000000,
        installmentAmount: 1000000,
        dueDay: 15,
        reminderDays: 2,
        startDate: DateTime(2026, 10, 1),
        createdAt: now,
        updatedAt: now,
      );

      // Horario de silencio hasta las 10:30
      const customQuietStart = (h: 23, m: 0);
      const customQuietEnd = (h: 10, m: 30);

      final reminder = planLoanReminder(
        loan: loan,
        payments: const [],
        nowLocal: now,
        quietStart: customQuietStart,
        quietEnd: customQuietEnd,
      );

      expect(reminder, isNotNull);
      // Debe correr la hora al fin del silencio (10:30) en vez de las 09:00
      expect(reminder!.atLocal, DateTime(2026, 10, 13, 10, 30));
    });

    test('no se programa si el préstamo está cerrado o saldo es 0', () {
      final now = DateTime(2026, 10, 5, 10, 0);
      final closedLoan = Loan(
        id: 'loan-closed',
        direction: LoanDirection.owe,
        kind: LoanKind.installments,
        name: 'Terminado',
        totalAmount: 1000000,
        installmentAmount: 1000000,
        dueDay: 15,
        reminderDays: 2,
        startDate: DateTime(2026, 10, 1),
        closedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final reminder = planLoanReminder(
        loan: closedLoan,
        payments: const [],
        nowLocal: now,
        quietStart: quietStart,
        quietEnd: quietEnd,
      );

      expect(reminder, isNull);
    });
  });

  group('rescheduleLoanReminders (integración con base de datos y Notifier)', () {
    late AppDatabase db;
    late LoansRepository loansRepo;
    late SettingsRepository settingsRepo;
    late FakeNotifier notifier;

    setUp(() {
      db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
      );
      loansRepo = LoansRepository(db);
      settingsRepo = SettingsRepository(db);
      notifier = FakeNotifier();
    });

    tearDown(() async {
      await db.close();
    });

    test('programa avisos para préstamos activos y cancela los no vigentes', () async {
      final now = DateTime(2026, 10, 5, 10, 0);

      await loansRepo.createLoan(
        direction: LoanDirection.owe,
        kind: LoanKind.installments,
        name: 'Cuota Heladera',
        totalAmount: 4000000,
        installmentAmount: 400000,
        installmentsTotal: 10,
        dueDay: 15,
        reminderDays: 2,
        startDate: DateTime(2026, 10, 1),
      );

      await rescheduleLoanReminders(
        db: db,
        notifier: notifier,
        settingsRepo: settingsRepo,
        nowLocal: now,
      );

      expect(notifier.scheduled.length, 1);
      final scheduled = notifier.scheduled.first;
      expect(scheduled.title, contains('Cuota Heladera'));
      expect(scheduled.atLocal, DateTime(2026, 10, 13, 9, 0));

      // Si se registra el pago de la cuota del mes
      await loansRepo.recordPayment(
        loanId: (await loansRepo.getActive()).first.id,
        amount: 400000,
        date: DateTime(2026, 10, 6, 12, 0),
      );

      // Reprogramar nuevamente
      await rescheduleLoanReminders(
        db: db,
        notifier: notifier,
        settingsRepo: settingsRepo,
        nowLocal: now,
      );

      // Debe haberse cancelado o ya no estar programado para octubre
      expect(notifier.scheduled, isEmpty);
    });
  });
}
