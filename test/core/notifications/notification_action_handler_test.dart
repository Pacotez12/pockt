import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/notifications/notification_action_handler.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/reminders/data/day_marks_repository.dart';
import 'package:pockt/features/reminders/data/reminder_scheduler.dart';
import 'package:pockt/features/shell/ui/app_shell.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/widget/home_widget_bridge.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  late AppDatabase db;
  late FakeNotifier fakeNotifier;
  late TransactionsRepository txRepo;
  late DayMarksRepository marksRepo;
  late SettingsRepository settingsRepo;
  late ReminderScheduler scheduler;

  final nowLocal = DateTime(2026, 10, 20, 14, 0); // Martes 14:00

  setUpAll(() {
    tz.initializeTimeZones();
  });

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

    // Configurar intensidad normal (slots 13:00 y 21:00)
    await settingsRepo.set(SettingsKeys.remindersIntensity, 'normal');
  });

  tearDown(() async {
    await db.close();
  });

  group('NotificationActionHandler lógica pura', () {
    test('action_no_spend marca el día y no quedan recordatorios de hoy en FakeNotifier.scheduled', () async {
      // 1. Programar recordatorios previos para hoy
      await scheduler.reschedule(nowLocal: nowLocal);
      final todayBefore = fakeNotifier.scheduled.where(
        (r) => r.atLocal.year == 2026 && r.atLocal.month == 10 && r.atLocal.day == 20,
      );
      expect(todayBefore, isNotEmpty);

      // 2. Procesar respuesta de notificación con acción action_no_spend
      const response = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotificationAction,
        id: 2026102001,
        actionId: kNotificationActionNoSpend,
        payload: 'reminder:2026102001',
      );

      bool entryOpened = false;
      await handleNotificationResponse(
        response: response,
        marksRepo: marksRepo,
        scheduler: scheduler,
        notifier: fakeNotifier,
        db: db,
        nowLocal: nowLocal,
        onOpenEntry: () => entryOpened = true,
      );

      // 3. Comprobar que el día fue marcado como sin gastos
      final marks = await marksRepo.noSpendDays(
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 20),
      );
      expect(marks.any((m) => m.year == 2026 && m.month == 10 && m.day == 20), isTrue);

      // 4. Comprobar que NO quedan recordatorios de hoy en scheduled
      final todayAfter = fakeNotifier.scheduled.where(
        (r) => r.atLocal.year == 2026 && r.atLocal.month == 10 && r.atLocal.day == 20,
      );
      expect(todayAfter, isEmpty);

      // 5. Comprobar que los días futuros sí conservan sus recordatorios
      final tomorrow = fakeNotifier.scheduled.where(
        (r) => r.atLocal.year == 2026 && r.atLocal.month == 10 && r.atLocal.day == 21,
      );
      expect(tomorrow, isNotEmpty);

      // No debe abrir pantalla de carga
      expect(entryOpened, isFalse);
    });

    test('action_entry dispara la apertura de carga (onOpenEntry)', () async {
      const response = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotificationAction,
        id: 2026102001,
        actionId: kNotificationActionEntry,
        payload: 'reminder:2026102001',
      );

      bool entryOpened = false;
      await handleNotificationResponse(
        response: response,
        marksRepo: marksRepo,
        scheduler: scheduler,
        notifier: fakeNotifier,
        db: db,
        nowLocal: nowLocal,
        onOpenEntry: () => entryOpened = true,
      );

      expect(entryOpened, isTrue);
    });

    test('tocar el cuerpo de la notificación de recordatorio dispara onOpenEntry', () async {
      const response = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: 2026102001,
        actionId: null,
        payload: 'reminder:2026102001',
      );

      bool entryOpened = false;
      await handleNotificationResponse(
        response: response,
        marksRepo: marksRepo,
        scheduler: scheduler,
        notifier: fakeNotifier,
        db: db,
        nowLocal: nowLocal,
        onOpenEntry: () => entryOpened = true,
      );

      expect(entryOpened, isTrue);
    });

    test('notificación no relacionada no dispara onOpenEntry ni marca día', () async {
      const response = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: 99999,
        actionId: null,
        payload: 'other:something',
      );

      bool entryOpened = false;
      await handleNotificationResponse(
        response: response,
        marksRepo: marksRepo,
        scheduler: scheduler,
        notifier: fakeNotifier,
        db: db,
        nowLocal: nowLocal,
        onOpenEntry: () => entryOpened = true,
      );

      expect(entryOpened, isFalse);
    });
  });

  group('Integración con AppShell (foreground y cold start)', () {
    testWidgets('arranque en frío desde notificación con payload reminder abre pantalla de carga', (tester) async {
      fakeNotifier.appLaunchResponse = const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: 2026102001,
        actionId: null,
        payload: 'reminder:2026102001',
      );

      final fakePlatform = FakeHomeWidgetPlatform();
      addTearDown(fakePlatform.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notifierProvider.overrideWithValue(fakeNotifier),
            homeWidgetPlatformProvider.overrideWithValue(fakePlatform),
            homeHeadlineProvider.overrideWith(
              (ref) => Stream.value(HomeHeadline.monthSpent),
            ),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: const AppShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EntryCategoryPickerScreen), findsOneWidget);
    });

    testWidgets('respuesta de notificación action_entry en primer plano abre pantalla de carga', (tester) async {
      final fakePlatform = FakeHomeWidgetPlatform();
      addTearDown(fakePlatform.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notifierProvider.overrideWithValue(fakeNotifier),
            homeWidgetPlatformProvider.overrideWithValue(fakePlatform),
            homeHeadlineProvider.overrideWith(
              (ref) => Stream.value(HomeHeadline.monthSpent),
            ),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: const AppShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EntryCategoryPickerScreen), findsNothing);

      // Emitir respuesta en primer plano
      fakeNotifier.emitResponse(
        const NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotificationAction,
          id: 2026102001,
          actionId: kNotificationActionEntry,
          payload: 'reminder:2026102001',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EntryCategoryPickerScreen), findsOneWidget);
    });

    testWidgets('respuesta action_no_spend en primer plano marca noSpend y no abre carga', (tester) async {
      final fakePlatform = FakeHomeWidgetPlatform();
      addTearDown(fakePlatform.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notifierProvider.overrideWithValue(fakeNotifier),
            homeWidgetPlatformProvider.overrideWithValue(fakePlatform),
            homeHeadlineProvider.overrideWith(
              (ref) => Stream.value(HomeHeadline.monthSpent),
            ),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: const AppShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EntryCategoryPickerScreen), findsNothing);

      // Emitir action_no_spend
      fakeNotifier.emitResponse(
        const NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotificationAction,
          id: 2026102001,
          actionId: kNotificationActionNoSpend,
          payload: 'reminder:2026102001',
        ),
      );
      await tester.pumpAndSettle();

      // No debe abrir pantalla de carga
      expect(find.byType(EntryCategoryPickerScreen), findsNothing);

      // Debe haber guardado la marca del día de hoy
      final today = DateTime.now();
      final marks = await marksRepo.noSpendDays(
        DateTime(today.year, today.month, today.day),
        DateTime(today.year, today.month, today.day),
      );
      expect(marks.any((m) => m.year == today.year && m.month == today.month && m.day == today.day), isTrue);
    });
  });
}
