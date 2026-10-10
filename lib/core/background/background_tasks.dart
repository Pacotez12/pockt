import 'package:flutter/foundation.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/recurring/domain/suggestion_generator.dart';
import 'package:pockt/features/reminders/data/day_marks_repository.dart';
import 'package:pockt/features/reminders/data/reminder_scheduler.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/widget/home_widget_bridge.dart';
import 'package:workmanager/workmanager.dart';

/// Punto de entrada top-level ejecutado en segundo plano por Workmanager.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await initLocalZone();
      final db = AppDatabase();
      final notifier = LocalNotifier();
      final txRepo = TransactionsRepository(db, notifier: notifier);
      final marksRepo = DayMarksRepository(db);
      final settingsRepo = SettingsRepository(db);
      final scheduler =
          ReminderScheduler(notifier, txRepo, marksRepo, settingsRepo);
      final now = DateTime.now();

      // 1. Generar sugerencias pendientes de cobro y recurrentes
      final generator = SuggestionGenerator(db, notifier, clock: () => now);
      await generator.run();

      // 2. Reprogramar recordatorios según el estado actual
      await scheduler.reschedule(nowLocal: now);

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

/// Inicializa Workmanager y registra la tarea periódica de 12 horas.
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
  } catch (e) {
    debugPrint('Workmanager no pudo inicializarse: $e');
  }
}
