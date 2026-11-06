import 'package:supabase_flutter/supabase_flutter.dart';

/// Opciones de autenticación de Supabase para Pockt.
///
/// [detectSessionInUri] está configurado explícitamente en `false` para impedir
/// la inyección no solicitada de sesiones mediante enlaces profundos (deep-links),
/// mitigando el riesgo de login CSRF y secuestro de sesión (HIGH: other-login-csrf).
const pocktAuthOptions = FlutterAuthClientOptions(
  detectSessionInUri: false,
);
