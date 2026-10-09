import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/reminders/data/day_marks_repository.dart';
import 'package:pockt/features/reminders/data/reminder_scheduler.dart';
import 'package:pockt/features/reminders/ui/reminders_screen.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase db;
  late FakeNotifier fakeNotifier;
  late TransactionsRepository txRepo;
  late DayMarksRepository marksRepo;
  late SettingsRepository settingsRepo;
  late ReminderScheduler scheduler;

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
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpRemindersScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notifierProvider.overrideWithValue(fakeNotifier),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          dayMarksRepositoryProvider.overrideWithValue(marksRepo),
          reminderSchedulerProvider.overrideWithValue(scheduler),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: const RemindersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra las 4 intensidades y las horas de silencio', (tester) async {
    await settingsRepo.set(SettingsKeys.remindersIntensity, 'normal');
    await pumpRemindersScreen(tester);

    expect(find.text('Recordatorios'), findsOneWidget);
    expect(find.text('Apagado'), findsOneWidget);
    expect(find.text('Suave'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Insistente'), findsOneWidget);
    expect(find.text('Horas de silencio'), findsOneWidget);
  });

  testWidgets('tocar una intensidad la guarda y reprograma', (tester) async {
    await settingsRepo.set(SettingsKeys.remindersIntensity, 'normal');
    await pumpRemindersScreen(tester);

    // Tocar Suave
    await tester.tap(find.text('Suave'));
    await tester.pumpAndSettle();

    final saved = await settingsRepo.get(SettingsKeys.remindersIntensity);
    expect(saved, 'soft');
  });

  testWidgets('Probar recordatorio programa uno real en unos segundos', (tester) async {
    await settingsRepo.set(SettingsKeys.remindersIntensity, 'insistent');
    await pumpRemindersScreen(tester);

    final button = find.text('Probar recordatorio');
    await tester.scrollUntilVisible(button, 200);
    await tester.tap(button);
    await tester.pumpAndSettle();

    final test = fakeNotifier.scheduled.single;
    expect(test.notificationId, kTestReminderId);
    expect(test.body, 'ANOTÁ TUS GASTOS DE HOY.');
    final secs = test.atLocal.difference(DateTime.now()).inSeconds;
    expect(secs, inInclusiveRange(1, 10));
  });

  testWidgets('si permiso está desactivado muestra aviso para activarlo', (tester) async {
    fakeNotifier.hasPermission = false;
    await pumpRemindersScreen(tester);

    expect(find.textContaining('desactivadas'), findsOneWidget);
    final button = find.text('Activar notificaciones');
    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(fakeNotifier.permissionRequestedCount, greaterThan(0));
  });
}
