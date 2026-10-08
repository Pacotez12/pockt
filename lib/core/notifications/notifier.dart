import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;

abstract class Notifier {
  Future<void> show(String title, String body, {String? payload});
  Future<bool> ensurePermission();
}

class FakeNotifier implements Notifier {
  final List<({String title, String body, String? payload})> shown = [];
  bool hasPermission = true;

  @override
  Future<void> show(String title, String body, {String? payload}) async {
    shown.add((title: title, body: body, payload: payload));
  }

  @override
  Future<bool> ensurePermission() async {
    return hasPermission;
  }
}

final notifierProvider = Provider<Notifier>((ref) {
  // En Task 4 se reemplazará por la implementación real con flutter_local_notifications.
  return FakeNotifier();
});
