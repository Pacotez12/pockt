import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/capture/data/email_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FakeEmailSource', () {
    test('filtra por fecha y cuenta llamadas', () async {
      final fake = FakeEmailSource(
        inbox: [
          RawEmail(
            id: 'old-1',
            receivedAt: DateTime(2026, 10, 1),
            subject: 'Viejo',
            bodyText: 'Texto viejo',
          ),
          RawEmail(
            id: 'new-1',
            receivedAt: DateTime(2026, 10, 10),
            subject: 'Nuevo',
            bodyText: 'Texto nuevo',
          ),
        ],
      );

      final results = await fake.fetchSince(DateTime(2026, 10, 5));
      expect(results.length, 1);
      expect(results.first.id, 'new-1');
      expect(fake.fetchCalls, 1);
    });

    test('lanza GmailReconnectRequired si requireReconnect', () async {
      final fake = FakeEmailSource(requireReconnect: true);
      expect(
        () => fake.fetchSince(DateTime(2026, 10, 1)),
        throwsA(isA<GmailReconnectRequired>()),
      );
    });

    test('authorize y disconnect actualizan connected', () async {
      final fake = FakeEmailSource(connected: false);
      expect(await fake.authorize(), isTrue);
      expect(fake.connected, isTrue);

      await fake.disconnect();
      expect(fake.connected, isFalse);
    });
  });

  group('AndroidEmailSource', () {
    const channel = MethodChannel('pockt/gmail');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('mapea lista de mapas nativos a RawEmail con fecha local', () async {
      final epochMs = DateTime(2026, 10, 10, 12, 0).millisecondsSinceEpoch;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'fetchSince') {
              return [
                {
                  'id': 'msg-1',
                  'internalDate': epochMs,
                  'subject': 'Aviso de transferencia',
                  'bodyText': 'Cuerpo del mensaje',
                },
              ];
            }
            return null;
          });

      final source = AndroidEmailSource();
      final emails = await source.fetchSince(DateTime(2026, 10, 1));
      expect(emails.length, 1);
      expect(emails.first.id, 'msg-1');
      expect(
        emails.first.receivedAt.millisecondsSinceEpoch,
        epochMs,
      );
      expect(emails.first.subject, 'Aviso de transferencia');
      expect(emails.first.bodyText, 'Cuerpo del mensaje');
    });

    test('mapea PlatformException(needsReconnect) a GmailReconnectRequired', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'fetchSince') {
              throw PlatformException(
                code: 'needsReconnect',
                message: 'Interaction required',
              );
            }
            return null;
          });

      final source = AndroidEmailSource();
      expect(
        () => source.fetchSince(DateTime(2026, 10, 1)),
        throwsA(isA<GmailReconnectRequired>()),
      );
    });

    test('authorize devuelve true si connected', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'authorize') return 'connected';
            return null;
          });

      final source = AndroidEmailSource();
      expect(await source.authorize(), isTrue);
    });

    test('authorize devuelve false si cancelled', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'authorize') return 'cancelled';
            return null;
          });

      final source = AndroidEmailSource();
      expect(await source.authorize(), isFalse);
    });
  });
}
