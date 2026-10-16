import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/capture/data/capture_service.dart';
import 'package:timezone/data/latest.dart' as tz;

class AndroidSmsSource implements SmsSource {
  AndroidSmsSource() {
    _channel.setMethodCallHandler(_handleCall);
  }

  static const MethodChannel _channel = MethodChannel('pockt/sms');
  final _incomingController = StreamController<RawSms>.broadcast();

  Future<dynamic> _handleCall(MethodCall call) async {
    if (call.method == 'onSmsReceived') {
      final map = call.arguments as Map<dynamic, dynamic>?;
      if (map != null) {
        final sender = (map['sender'] ?? '').toString();
        final body = (map['body'] ?? '').toString();
        final ms =
            (map['receivedAtMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch;
        _incomingController.add(
          RawSms(
            sender: sender,
            body: body,
            receivedAt: DateTime.fromMillisecondsSinceEpoch(ms),
          ),
        );
      }
    }
    return null;
  }

  @override
  Future<bool> hasPermissions() async {
    try {
      final granted = await _channel.invokeMethod<bool>('hasPermissions');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermissions');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<RawSms>> readInboxSince(DateTime since) async {
    try {
      final rawList = await _channel.invokeMethod<List<dynamic>>(
        'readInboxSince',
        {'sinceEpochMs': since.millisecondsSinceEpoch},
      );
      if (rawList == null) return const [];
      final out = <RawSms>[];
      for (final item in rawList) {
        if (item is Map) {
          final sender = (item['sender'] ?? '').toString();
          final body = (item['body'] ?? '').toString();
          final ms = (item['receivedAtMs'] as num?)?.toInt();
          if (sender.isNotEmpty && body.isNotEmpty && ms != null) {
            out.add(
              RawSms(
                sender: sender,
                body: body,
                receivedAt: DateTime.fromMillisecondsSinceEpoch(ms),
              ),
            );
          }
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  @override
  Stream<RawSms> get incomingSms => _incomingController.stream;

  void dispose() {
    _incomingController.close();
  }
}

/// Punto de entrada top-level invocado por `SmsCaptureReceiver` cuando llega un
/// SMS del 4828 con la app cerrada.
@pragma('vm:entry-point')
Future<void> smsBackgroundMain(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    tz.initializeTimeZones();
    await initLocalZone();
    final db = AppDatabase();
    try {
      final settingsRepo = SettingsRepository(db);
      final enabled = await settingsRepo.get(SettingsKeys.captureSmsEnabled);
      if (enabled == 'true' && args.length >= 3) {
        final sender = args[0];
        final body = args[1];
        final ms =
            int.tryParse(args[2]) ?? DateTime.now().millisecondsSinceEpoch;
        final notifier = LocalNotifier();
        final service = CaptureService(
          db: db,
          notifier: notifier,
          smsSource: FakeSmsSource(),
          settingsRepository: settingsRepo,
        );
        await service.ingest([
          RawSms(
            sender: sender,
            body: body,
            receivedAt: DateTime.fromMillisecondsSinceEpoch(ms),
          ),
        ]);
      }
    } finally {
      await db.close();
    }
  } catch (e) {
    debugPrint('Error en smsBackgroundMain: $e');
  }
}
