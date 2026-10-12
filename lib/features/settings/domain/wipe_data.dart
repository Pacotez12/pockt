import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/features/widget/home_widget_bridge.dart';

/// Borra todos los datos del usuario y deja la app coherente con la base vacía:
/// cancela los avisos programados (recordatorios, presupuestos y préstamos) y
/// redibuja el widget de inicio con las categorías de fábrica.
Future<void> wipeAllUserData({
  required AppDatabase db,
  required Notifier notifier,
  required HomeWidgetPlatform homeWidget,
  DateTime? nowLocal,
}) async {
  await db.wipeAllData();
  try {
    // Cancela todo lo programado: ya no hay nada a lo que avisar.
    await notifier.cancelAllReminders();
  } catch (_) {
    // Los datos ya se borraron; un fallo del plugin no debe frenar el refresco del widget.
  }
  await HomeWidgetBridge.update(
    db: db,
    nowLocal: nowLocal ?? DateTime.now(),
    platform: homeWidget,
  );
}
