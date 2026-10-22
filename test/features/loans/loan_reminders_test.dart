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
        paidBeforeCount: 0,
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

    test('aviso con cronograma: título "Vence la cuota k de N" y cuerpo con monto y día', () {
      final now = DateTime(2026, 12, 1, 10, 0);
      final loan = Loan(
        id: 'loan-sched',
        direction: LoanDirection.owe,
        kind: LoanKind.installments,
        name: 'Préstamo Itaú',
        totalAmount: 2415000,
        installmentAmount: null,
        installmentsTotal: 3,
        dueDay: 2,
        paidBeforeCount: 0,
        reminderDays: 2,
        startDate: DateTime(2027, 1, 1),
        createdAt: now,
        updatedAt: now,
      );
      final schedule = [
        LoanInstallment(loanId: 'loan-sched', number: 1, dueDate: DateTime(2027, 1, 2), amount: 905000),
        LoanInstallment(loanId: 'loan-sched', number: 2, dueDate: DateTime(2027, 2, 2), amount: 805000),
        LoanInstallment(loanId: 'loan-sched', number: 3, dueDate: DateTime(2027, 3, 2), amount: 705000),
      ];

      final reminder = planLoanReminder(
        loan: loan,
        payments: const [],
        schedule: schedule,
        nowLocal: now,
        quietStart: quietStart,
        quietEnd: quietEnd,
      );

      expect(reminder, isNotNull);
      // 02 de enero 2027 - 2 días = 31 de diciembre 2026 a las 09:00
      expect(reminder!.atLocal, DateTime(2026, 12, 31, 9, 0));
      expect(reminder.title, equals('Vence la cuota 1 de 3'));
      expect(reminder.body, equals('Préstamo Itaú · Gs. 905.000 el sábado 02/01'));
    });

    test('aviso con cronograma y paidBeforeCount usa la cuota siguiente correspondiente', () {
      final now = DateTime(2027, 1, 15, 10, 0);
      final loan = Loan(
        id: 'loan-sched',
        direction: LoanDirection.owe,
        kind: LoanKind.installments,
        name: 'Préstamo Itaú',
        totalAmount: 2415000,
        installmentAmount: null,
        installmentsTotal: 3,
        dueDay: 2,
        paidBeforeCount: 1, // Cuota 1 ya pagada antes de Pockt
        reminderDays: 2,
        startDate: DateTime(2027, 1, 1),
        createdAt: now,
        updatedAt: now,
      );
      final schedule = [
        LoanInstallment(loanId: 'loan-sched', number: 1, dueDate: DateTime(2027, 1, 2), amount: 905000),
        LoanInstallment(loanId: 'loan-sched', number: 2, dueDate: DateTime(2027, 2, 2), amount: 805000),
        LoanInstallment(loanId: 'loan-sched', number: 3, dueDate: DateTime(2027, 3, 2), amount: 705000),
      ];

      final reminder = planLoanReminder(
        loan: loan,
        payments: const [],
        schedule: schedule,
        nowLocal: now,
        quietStart: quietStart,
        quietEnd: quietEnd,
      );

      expect(reminder, isNotNull);
      // 02 de febrero 2027 - 2 días = 31 de enero 2027 a las 09:00
      expect(reminder!.atLocal, DateTime(2027, 1, 31, 9, 0));
      expect(reminder.title, equals('Vence la cuota 2 de 3'));
      expect(reminder.body, equals('Préstamo Itaú · Gs. 805.000 el martes 02/02'));
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
        paidBeforeCount: 0,
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
        isExtra: false,
        note: 'incluye extra por mora',
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
        paidBeforeCount: 0,
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
        isExtra: true,
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
        paidBeforeCount: 0,
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
        paidBeforeCount: 0,
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
