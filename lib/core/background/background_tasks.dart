import 'package:flutter/foundation.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/loans/domain/loan_reminders.dart';
import 'package:pockt/features/recurring/domain/suggestion_generator.dart';
import 'package:pockt/features/reminders/data/day_marks_repository.dart';
import 'package:pockt/features/reminders/data/reminder_scheduler.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/widget/home_widget_bridge.dart';
import 'package:pockt/features/capture/data/email_source.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:workmanager/workmanager.dart';

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

      if (task == 'pockt-email-probe') {
        final emailSource = const AndroidEmailSource();
        try {
          final emails = await emailSource.fetchSince(
            now.subtract(const Duration(days: 7)),
          );
          await notifier.show(
            'Gmail en segundo plano',
            '${emails.length} correos',
          );
        } on GmailReconnectRequired {
          await notifier.show(
            'Gmail en segundo plano',
            'necesita reconectar',
          );
        } catch (e) {
          await notifier.show(
            'Gmail en segundo plano',
            'error: $e',
          );
        }
        await db.close();
        return true;
      }

      // 1. Generar sugerencias pendientes de cobro y recurrentes
      final generator = SuggestionGenerator(db, notifier, clock: () => now);
      await generator.run();

      // 2. Reprogramar recordatorios según el estado actual
      await scheduler.reschedule(nowLocal: now);
      await rescheduleLoanReminders(
        db: db,
        notifier: notifier,
        settingsRepo: settingsRepo,
        nowLocal: now,
      );

      // 3. Actualizar widget de pantalla de inicio
      await HomeWidgetBridge.update(db: db, nowLocal: now);

      await db.close();
      return true;
    } catch (e) {
      debugPrint('Error en callbackDispatcher de Workmanager: $e');
      return false;
    }
  });
}

/// Inicializa Workmanager y registra las tareas periódicas:
/// - `pockt-daily` cada 12 horas (recurrentes, recordatorios y widget).
/// El backup ya no corre en segundo plano (se hace al abrir la app, spec §7):
/// se cancela la tarea `pockt-backup` que versiones anteriores registraron.
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
    await Workmanager().cancelByUniqueName('pockt-backup');
  } catch (e) {
    debugPrint('Workmanager no pudo inicializarse: $e');
  }
}
