import 'package:flutter/services.dart';

class PocktGmail {
  static const MethodChannel channel = MethodChannel('pockt/gmail');

  static Future<String?> authorize() {
    return channel.invokeMethod<String>('authorize');
  }

  static Future<List<Map<dynamic, dynamic>>> fetchSince(int sinceMillis) async {
    final result = await channel.invokeListMethod<Map<dynamic, dynamic>>(
      'fetchSince',
      {'sinceMillis': sinceMillis},
    );
    return result ?? const [];
  }

  static Future<void> disconnect() {
    return channel.invokeMethod<void>('disconnect');
  }
}
