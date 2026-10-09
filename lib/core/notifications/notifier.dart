import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'package:pockt/features/reminders/domain/reminder_plan.dart';
import 'package:timezone/timezone.dart' as tz;

abstract class Notifier {
  Future<void> show(String title, String body, {String? payload});
  Future<void> schedule(PlannedReminder r);
  Future<void> cancel(int id);
  Future<void> cancelAllReminders();
  Future<bool> ensurePermission();
}

class LocalNotifier implements Notifier {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  int _nextId = 0;

  LocalNotifier({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  Future<void> _init() async {
    if (_initialized) return;
    const androidSettings =
        AndroidInitializationSettings('ic_launcher_monochrome');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: initSettings);
    _initialized = true;
  }

  @override
  Future<bool> ensurePermission() async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  @override
  Future<void> show(String title, String body, {String? payload}) async {
    await _init();
    const androidDetails = AndroidNotificationDetails(
      'pockt',
      'Pockt',
      channelDescription: 'Notificaciones de Pockt',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_launcher_monochrome',
    );
    const details = NotificationDetails(android: androidDetails);
    final id = _nextId++;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  @override
  Future<void> schedule(PlannedReminder r) async {
    await _init();
    final scheduledDate = tz.TZDateTime.from(r.atLocal, tz.local);
    const androidDetails = AndroidNotificationDetails(
      'pockt_reminders',
      'Recordatorios de gastos',
      channelDescription: 'Recordatorios diarios para registrar tus gastos',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_launcher_monochrome',
      actions: [
        AndroidNotificationAction(
          'action_entry',
          'Anotar',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'action_no_spend',
          'Hoy no gasté nada',
          showsUserInterface: false,
        ),
      ],
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.zonedSchedule(
      id: r.notificationId,
      title: r.title,
      body: r.body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'reminder:${r.notificationId}',
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> cancelAllReminders() async {
    await _init();
    await _plugin.cancelAll();
  }
}

class FakeNotifier implements Notifier {
  final List<({String title, String body, String? payload})> shown = [];
  final List<PlannedReminder> scheduled = [];
  final List<int> cancelled = [];
  bool cancelledAll = false;
  bool hasPermission = true;
  int permissionRequestedCount = 0;

  @override
  Future<void> show(String title, String body, {String? payload}) async {
    shown.add((title: title, body: body, payload: payload));
  }

  @override
  Future<void> schedule(PlannedReminder r) async {
    scheduled.add(r);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.removeWhere((r) => r.notificationId == id);
  }

  @override
  Future<void> cancelAllReminders() async {
    cancelledAll = true;
    scheduled.clear();
  }

  @override
  Future<bool> ensurePermission() async {
    permissionRequestedCount++;
    return hasPermission;
  }
}

final notifierProvider = Provider<Notifier>((ref) {
  return LocalNotifier();
});
