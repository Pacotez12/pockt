import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/sync/auth_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Supabase AuthOptions (mitigación other-login-csrf)', () {
    test('por defecto Supabase detectSessionInUri es true (demuestra riesgo)', () {
      const defaultOptions = FlutterAuthClientOptions();
      expect(defaultOptions.detectSessionInUri, isTrue);
    });

    test('pocktAuthOptions desactiva detectSessionInUri para evitar inyección de sesión', () {
      expect(pocktAuthOptions.detectSessionInUri, isFalse);
    });
  });
}
