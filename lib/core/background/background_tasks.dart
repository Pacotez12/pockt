import 'package:flutter/foundation.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/capture/data/email_capture_service.dart';
import 'package:pockt/features/capture/data/email_source.dart';
import 'package:pockt/features/loans/domain/loan_reminders.dart';
import 'package:pockt/features/recurring/domain/suggestion_generator.dart';
import 'package:pockt/features/reminders/data/day_marks_repository.dart';
import 'package:pockt/features/reminders/data/reminder_scheduler.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/widget/home_widget_bridge.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:workmanager/workmanager.dart';

class BackgroundDeps {
  final AppDatabase db;
  final SettingsRepository settingsRepo;
  final Notifier notifier;
  final TransactionsRepository txRepo;
  final DayMarksRepository marksRepo;
  final ReminderScheduler scheduler;
  final SuggestionGenerator generator;
  final EmailCaptureService? emailService;
  final DateTime now;

  BackgroundDeps({
    required this.db,
    required this.settingsRepo,
    required this.notifier,
    required this.txRepo,
    required this.marksRepo,
    required this.scheduler,
    required this.generator,
    this.emailService,
    required this.now,
  });
}

Future<bool> runBackgroundTask(String task, BackgroundDeps deps) async {
  if (task == 'pockt-email') {
    if (deps.emailService != null) {
      await deps.emailService!.sync();
    }
    return true;
  }

  // 1. Generar sugerencias pendientes de cobro y recurrentes
  await deps.generator.run();

  // 2. Reprogramar recordatorios según el estado actual
  await deps.scheduler.reschedule(nowLocal: deps.now);
  await rescheduleLoanReminders(
    db: deps.db,
    notifier: deps.notifier,
    settingsRepo: deps.settingsRepo,
    nowLocal: deps.now,
  );

  // 3. Actualizar widget de pantalla de inicio
  await HomeWidgetBridge.update(db: deps.db, nowLocal: deps.now);

  return true;
}

/// Punto de entrada top-level ejecutado en segundo plano por Workmanager.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // El isolate de fondo no comparte la base de zonas cargada en main().
      tz.initializeTimeZones();
      await initLocalZone();
      final db = AppDatabase();
      final settingsRepo = SettingsRepository(db);

      final notifier = LocalNotifier();
      final txRepo = TransactionsRepository(db, notifier: notifier);
      final marksRepo = DayMarksRepository(db);
      final scheduler =
          ReminderScheduler(notifier, txRepo, marksRepo, settingsRepo);
      final now = DateTime.now();
      final generator = SuggestionGenerator(db, notifier, clock: () => now);
      final emailService = EmailCaptureService(
        db: db,
        notifier: notifier,
        source: const AndroidEmailSource(),
      );

      final deps = BackgroundDeps(
        db: db,
        settingsRepo: settingsRepo,
        notifier: notifier,
        txRepo: txRepo,
        marksRepo: marksRepo,
        scheduler: scheduler,
        generator: generator,
        emailService: emailService,
        now: now,
      );

      final ok = await runBackgroundTask(task, deps);
      await db.close();
      return ok;
    } catch (e) {
      debugPrint('Error en callbackDispatcher de Workmanager: $e');
      return false;
    }
  });
}

/// Inicializa Workmanager y registra las tareas periódicas:
/// - `pockt-daily` cada 12 horas (recurrentes, recordatorios y widget).
/// - `pockt-email` cada 15 minutos (lectura de correos con conexión a internet).
Future<void> initBackgroundTasks() async {
  try {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      'pockt-daily',
      'pockt-daily',
      frequency: const Duration(hours: 12),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
    );
    await Workmanager().registerPeriodicTask(
      'pockt-email',
      'pockt-email',
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    await Workmanager().cancelByUniqueName('pockt-backup');
    await Workmanager().cancelByUniqueName('pockt-email-probe');
  } catch (e) {
    debugPrint('Workmanager no pudo inicializarse: $e');
  }
}
