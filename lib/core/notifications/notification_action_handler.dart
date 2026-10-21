import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pockt/core/background/background_tasks.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/features/reminders/data/day_marks_repository.dart';
import 'package:pockt/features/reminders/data/reminder_scheduler.dart';
import 'package:pockt/features/widget/home_widget_bridge.dart';

const String kNotificationActionNoSpend = 'action_no_spend';
const String kNotificationActionEntry = 'action_entry';

/// Maneja la respuesta de una notificación (acciones o toque en el cuerpo).
/// Función pura y desacoplada del plugin para testing unitario.
Future<void> handleNotificationResponse({
  required NotificationResponse response,
  required DayMarksRepository marksRepo,
  required ReminderScheduler scheduler,
  required Notifier notifier,
  required AppDatabase db,
  required DateTime nowLocal,
  VoidCallback? onOpenEntry,
}) async {
  final actionId = response.actionId;
  final payload = response.payload;

  if (actionId == kNotificationActionNoSpend) {
    // 1. Marcar el día local actual como noSpend ("Hoy no gasté nada")
    await marksRepo.markNoSpend(nowLocal);

    // 2. Reprogramar: reschedule cancela todo y omite el día ya marcado
    await scheduler.reschedule(nowLocal: nowLocal);

    // 3. Actualizar el widget de pantalla de inicio
    await HomeWidgetBridge.update(db: db, nowLocal: nowLocal);
    return;
  }

  final isReminder = payload != null && payload.startsWith('reminder:');
  if (actionId == kNotificationActionEntry ||
      ((actionId == null || actionId.isEmpty) && isReminder)) {
    onOpenEntry?.call();
  }
}

/// Handler de respuestas de notificaciones en segundo plano (app cerrada).
@pragma('vm:entry-point')
void notificationBackgroundResponseHandler(
  NotificationResponse response,
) async {
  if (response.actionId == kNotificationActionNoSpend) {
    try {
      final deps = await createBackgroundDeps();
      try {
        await handleNotificationResponse(
          response: response,
          marksRepo: deps.marksRepo,
          scheduler: deps.scheduler,
          notifier: deps.notifier,
          db: deps.db,
          nowLocal: deps.now,
        );
      } finally {
        await deps.db.close();
      }
    } catch (e) {
      debugPrint('Error en notificationBackgroundResponseHandler: $e');
    }
  }
}
