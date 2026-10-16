import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/capture/data/android_sms_source.dart';
import 'package:pockt/features/capture/data/capture_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('pockt/sms');
  late List<MethodCall> log;

  setUp(() {
    log = [];
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('AndroidSmsSource consulta permisos y lee inbox desde sinceEpochMs por el canal pockt/sms', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          log.add(call);
          switch (call.method) {
            case 'hasPermissions':
              return true;
            case 'requestPermissions':
              return true;
            case 'readInboxSince':
              return [
                {
                  'sender': '4828',
                  'body': 'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****34.500 por PIZZA HUT-MULTIPLAZA al 15/10/2026 12:15:51',
                  'receivedAtMs': DateTime(
                    2026,
                    10,
                    15,
                    12,
                    16,
                  ).millisecondsSinceEpoch,
                },
              ];
            default:
              return null;
          }
        });

    final source = AndroidSmsSource();
    expect(await source.hasPermissions(), isTrue);
    expect(await source.requestPermissions(), isTrue);

    final since = DateTime(2026, 10, 15);
    final messages = await source.readInboxSince(since);
    expect(messages.length, 1);
    expect(messages.single.sender, '4828');
    expect(messages.single.receivedAt, DateTime(2026, 10, 15, 12, 16));
    expect(log.map((c) => c.method), [
      'hasPermissions',
      'requestPermissions',
      'readInboxSince',
    ]);
  });

  test('AndroidSmsSource devuelve false / lista vacía sin romper cuando el canal falla', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'UNAVAILABLE');
        });

    final source = AndroidSmsSource();
    expect(await source.hasPermissions(), isFalse);
    expect(await source.requestPermissions(), isFalse);
    expect(await source.readInboxSince(DateTime(2026, 10, 15)), isEmpty);
  });

  test('AndroidSmsSource emite en incomingSms cuando el receptor nativo invoca onSmsReceived', () async {
    final source = AndroidSmsSource();
    final received = <RawSms>[];
    final sub = source.incomingSms.listen(received.add);
    addTearDown(() async {
      await sub.cancel();
      source.dispose();
    });

    final codec = const StandardMethodCodec();
    final data = codec.encodeMethodCall(
      MethodCall('onSmsReceived', {
        'sender': '4828',
        'body': 'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****34.500 por PEDIDOS YA al 15/10/2026 13:00:00',
        'receivedAtMs': DateTime(2026, 10, 15, 13, 0).millisecondsSinceEpoch,
      }),
    );

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage('pockt/sms', data, (_) {});

    await Future<void>.delayed(Duration.zero);
    expect(received.length, 1);
    expect(received.single.sender, '4828');
    expect(received.single.body, contains('PEDIDOS YA'));
  });
}
