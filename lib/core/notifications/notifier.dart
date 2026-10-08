import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;

abstract class Notifier {
  Future<void> show(String title, String body, {String? payload});
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
}

class FakeNotifier implements Notifier {
  final List<({String title, String body, String? payload})> shown = [];
  bool hasPermission = true;
  int permissionRequestedCount = 0;

  @override
  Future<void> show(String title, String body, {String? payload}) async {
    shown.add((title: title, body: body, payload: payload));
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
