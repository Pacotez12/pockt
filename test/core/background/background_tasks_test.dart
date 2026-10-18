import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/background/background_tasks.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/capture/data/email_capture_service.dart';
import 'package:pockt/features/capture/data/email_source.dart';
import 'package:pockt/features/recurring/domain/suggestion_generator.dart';
import 'package:pockt/features/reminders/data/day_marks_repository.dart';
import 'package:pockt/features/reminders/data/reminder_scheduler.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:drift/native.dart';

class _FakeEmailCaptureService extends EmailCaptureService {
  int syncCalls = 0;

  _FakeEmailCaptureService({
    required super.db,
    required super.notifier,
    required super.source,
  });

  @override
  Future<int> sync({bool notify = true}) async {
    syncCalls++;
    return 1;
  }
}

class _FakeSuggestionGenerator extends SuggestionGenerator {
  int runCalls = 0;

  _FakeSuggestionGenerator(super.db, super.notifier);

  @override
  Future<int> run({DateTime? nowLocal}) async {
    runCalls++;
    return 0;
  }
}

class _FakeReminderScheduler extends ReminderScheduler {
  int rescheduleCalls = 0;

  _FakeReminderScheduler(
    super.notifier,
    super.txRepo,
    super.marksRepo,
    super.settingsRepo,
  );

  @override
  Future<void> reschedule({DateTime? nowLocal}) async {
    rescheduleCalls++;
  }
}

void main() {
  late AppDatabase db;
  late FakeNotifier notifier;
  late SettingsRepository settingsRepo;
  late TransactionsRepository txRepo;
  late DayMarksRepository marksRepo;
  late _FakeReminderScheduler scheduler;
  late _FakeSuggestionGenerator generator;
  late _FakeEmailCaptureService emailService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifier = FakeNotifier();
    settingsRepo = SettingsRepository(db);
    txRepo = TransactionsRepository(db, notifier: notifier);
    marksRepo = DayMarksRepository(db);
    scheduler = _FakeReminderScheduler(notifier, txRepo, marksRepo, settingsRepo);
    generator = _FakeSuggestionGenerator(db, notifier);
    emailService = _FakeEmailCaptureService(
      db: db,
      notifier: notifier,
      source: FakeEmailSource(),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('runBackgroundTask con pockt-email llama solo a email sync y no a suggestion generator', () async {
    final deps = BackgroundDeps(
      db: db,
      settingsRepo: settingsRepo,
      notifier: notifier,
      txRepo: txRepo,
      marksRepo: marksRepo,
      scheduler: scheduler,
      generator: generator,
      emailService: emailService,
      now: DateTime(2026, 10, 16, 10, 0),
    );

    final result = await runBackgroundTask('pockt-email', deps);

    expect(result, isTrue);
    expect(emailService.syncCalls, 1);
    expect(generator.runCalls, 0);
    expect(scheduler.rescheduleCalls, 0);
  });

  test('runBackgroundTask con pockt-daily corre generador y recordatorios, no email sync', () async {
    final deps = BackgroundDeps(
      db: db,
      settingsRepo: settingsRepo,
      notifier: notifier,
      txRepo: txRepo,
      marksRepo: marksRepo,
      scheduler: scheduler,
      generator: generator,
      emailService: emailService,
      now: DateTime(2026, 10, 16, 10, 0),
    );

    final result = await runBackgroundTask('pockt-daily', deps);

    expect(result, isTrue);
    expect(emailService.syncCalls, 0);
    expect(generator.runCalls, 1);
    expect(scheduler.rescheduleCalls, 1);
  });
}
