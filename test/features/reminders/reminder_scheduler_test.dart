import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/reminders/data/day_marks_repository.dart';
import 'package:pockt/features/reminders/data/reminder_scheduler.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase db;
  late FakeNotifier fakeNotifier;
  late TransactionsRepository txRepo;
  late DayMarksRepository marksRepo;
  late SettingsRepository settingsRepo;
  late ReminderScheduler scheduler;
  late String comidaId;

  final nowLocal = DateTime(2026, 10, 9, 10, 0); // Viernes 10:00

  setUp(() async {
    setLocalZone('America/Asuncion');
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    fakeNotifier = FakeNotifier();
    txRepo = TransactionsRepository(db, notifier: fakeNotifier);
    marksRepo = DayMarksRepository(db);
    settingsRepo = SettingsRepository(db);
    scheduler = ReminderScheduler(fakeNotifier, txRepo, marksRepo, settingsRepo);

    final cats = await db.select(db.categories).get();
    comidaId = cats.firstWhere((c) => c.name == 'Comida').id;
  });

  tearDown(() async {
    await db.close();
  });

  test('reschedule con Normal programa 13:00 y 21:00 de hoy', () async {
    await settingsRepo.set(SettingsKeys.remindersIntensity, 'normal');
    await scheduler.reschedule(nowLocal: nowLocal);

    expect(fakeNotifier.scheduled, isNotEmpty);
    final todayReminders = fakeNotifier.scheduled
        .where((r) => r.atLocal.year == 2026 && r.atLocal.month == 10 && r.atLocal.day == 9)
        .toList();

    expect(todayReminders.length, 2);
    expect(todayReminders[0].atLocal.hour, 13);
    expect(todayReminders[0].atLocal.minute, 0);
    expect(todayReminders[1].atLocal.hour, 21);
    expect(todayReminders[1].atLocal.minute, 0);
  });

  test('guardar un gasto cancela los de hoy', () async {
    await settingsRepo.set(SettingsKeys.remindersIntensity, 'normal');
    await scheduler.reschedule(nowLocal: nowLocal);

    expect(fakeNotifier.scheduled, isNotEmpty);

    await txRepo.add(
      type: TxType.expense,
      amount: 45000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 9, 11, 30),
    );

    // Debe haber llamado a cancel para los IDs de hoy (base 2026100900..03)
    expect(fakeNotifier.cancelled, contains(2026100900));
    expect(fakeNotifier.cancelled, contains(2026100901));
  });

  test('marcar "Hoy no gasté nada" cancela los de hoy y crea el mark', () async {
    await settingsRepo.set(SettingsKeys.remindersIntensity, 'normal');
    await scheduler.reschedule(nowLocal: nowLocal);

    // Marcar no gasté y reprogramar
    await marksRepo.markNoSpend(DateTime(2026, 10, 9));
    await scheduler.reschedule(nowLocal: nowLocal);

    final marks = await marksRepo.noSpendDays(
      DateTime(2026, 10, 9),
      DateTime(2026, 10, 9),
    );
    expect(marks.any((m) => m.year == 2026 && m.month == 10 && m.day == 9), isTrue);

    // Al reprogramar, hoy no debe tener ningún recordatorio
    final todayReminders = fakeNotifier.scheduled
        .where((r) => r.atLocal.year == 2026 && r.atLocal.month == 10 && r.atLocal.day == 9);
    expect(todayReminders, isEmpty);
  });

  test('cambiar intensidad reprograma con los nuevos horarios', () async {
    // 1. Suave
    await settingsRepo.set(SettingsKeys.remindersIntensity, 'soft');
    await scheduler.reschedule(nowLocal: nowLocal);

    final todaySoft = fakeNotifier.scheduled
        .where((r) => r.atLocal.year == 2026 && r.atLocal.month == 10 && r.atLocal.day == 9)
        .toList();
    expect(todaySoft.length, 1);
    expect(todaySoft.first.atLocal.hour, 21);

    // 2. Cambiar a Insistente
    await settingsRepo.set(SettingsKeys.remindersIntensity, 'insistent');
    await scheduler.reschedule(nowLocal: nowLocal);

    final todayInsistent = fakeNotifier.scheduled
        .where((r) => r.atLocal.year == 2026 && r.atLocal.month == 10 && r.atLocal.day == 9)
        .toList();
    expect(todayInsistent.length, 4);
    expect(todayInsistent.map((r) => r.atLocal.hour).toList(), [12, 15, 18, 21]);
  });
}
