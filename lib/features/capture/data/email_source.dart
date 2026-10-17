import 'package:flutter/services.dart';

class RawEmail {
  final String id;
  final DateTime receivedAt;
  final String subject;
  final String bodyText;

  const RawEmail({
    required this.id,
    required this.receivedAt,
    required this.subject,
    required this.bodyText,
  });
}

class GmailReconnectRequired implements Exception {
  final String message;
  const GmailReconnectRequired([this.message = 'Gmail reconnect required']);

  @override
  String toString() => 'GmailReconnectRequired: $message';
}

abstract class EmailSource {
  Future<bool> authorize();
  Future<List<RawEmail>> fetchSince(DateTime since);
  Future<void> disconnect();
}

class AndroidEmailSource implements EmailSource {
  static const MethodChannel _channel = MethodChannel('pockt/gmail');

  const AndroidEmailSource();

  @override
  Future<bool> authorize() async {
    try {
      final res = await _channel.invokeMethod<String>('authorize');
      return res == 'connected';
    } on PlatformException catch (e) {
      if (e.code == 'needsReconnect') {
        throw const GmailReconnectRequired();
      }
      return false;
    }
  }

  @override
  Future<List<RawEmail>> fetchSince(DateTime since) async {
    try {
      final res = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'fetchSince',
        {'sinceMillis': since.millisecondsSinceEpoch},
      );
      if (res == null) return const [];
      return res.map((m) {
        final id = m['id'] as String? ?? '';
        final internalDateMs = m['internalDate'] as int? ?? 0;
        final subject = m['subject'] as String? ?? '';
        final bodyText = m['bodyText'] as String? ?? '';
        return RawEmail(
          id: id,
          receivedAt: DateTime.fromMillisecondsSinceEpoch(internalDateMs),
          subject: subject,
          bodyText: bodyText,
        );
      }).toList();
    } on PlatformException catch (e) {
      if (e.code == 'needsReconnect') {
        throw const GmailReconnectRequired();
      }
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod<void>('disconnect');
    } catch (_) {}
  }
}

class FakeEmailSource implements EmailSource {
  List<RawEmail> inbox;
  bool connected;
  bool requireReconnect;
  int fetchCalls;

  FakeEmailSource({
    List<RawEmail>? inbox,
    this.connected = true,
    this.requireReconnect = false,
    this.fetchCalls = 0,
  }) : inbox = inbox ?? [];

  @override
  Future<bool> authorize() async {
    if (requireReconnect) {
      throw const GmailReconnectRequired();
    }
    connected = true;
    return true;
  }

  @override
  Future<List<RawEmail>> fetchSince(DateTime since) async {
    fetchCalls++;
    if (requireReconnect) {
      throw const GmailReconnectRequired();
    }
    return inbox.where((e) => !e.receivedAt.isBefore(since)).toList();
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }
}
