import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstracción de datos de cuenta de Google para desacoplar el paquete en pruebas.
class GoogleSignInAccountData {
  final String? idToken;
  final String? accessToken;

  const GoogleSignInAccountData({
    this.idToken,
    this.accessToken,
  });
}

/// Interfaz para el inicio de sesión nativo de Google.
abstract interface class GoogleSignInDelegate {
  Future<void> initialize({required String serverClientId, String? nonce});
  Future<GoogleSignInAccountData?> authenticate();
  Future<void> signOut();
}

/// Implementación por defecto basada en `google_sign_in: 7.x`.
class DefaultGoogleSignInDelegate implements GoogleSignInDelegate {
  const DefaultGoogleSignInDelegate();

  @override
  Future<void> initialize({required String serverClientId, String? nonce}) {
    return GoogleSignIn.instance.initialize(
      serverClientId: serverClientId,
      nonce: nonce,
    );
  }

  @override
  Future<GoogleSignInAccountData?> authenticate() async {
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final auth = account.authentication;
      return GoogleSignInAccountData(
        idToken: auth.idToken,
        accessToken: null,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> signOut() {
    return GoogleSignIn.instance.signOut();
  }
}

/// Servicio de autenticación con Google y Supabase.
class AuthService {
  final SupabaseClient? client;
  final GoogleSignInDelegate _googleSignIn;
  final String webClientId;

  AuthService({
    this.client,
    GoogleSignInDelegate? googleSignIn,
    this.webClientId = const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
  })  : _googleSignIn = googleSignIn ?? const DefaultGoogleSignInDelegate();

  SupabaseClient? _resolveClient() {
    if (client != null) return client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Indica si Supabase está configurado en el entorno.
  bool get isConfigured => _resolveClient() != null;

  /// Sesión actual en Supabase o null si no hay sesión o no está configurado.
  Session? get currentSession => _resolveClient()?.auth.currentSession;

  /// Indica si hay una sesión activa.
  bool get isSignedIn => currentSession != null;

  /// Stream reactivo de cambios de sesión.
  Stream<Session?> get authStateChanges {
    final client = _resolveClient();
    if (client == null) return Stream.value(null);
    return client.auth.onAuthStateChange.map((data) => data.session);
  }

  /// Inicia sesión de forma nativa con Google pasando el nonce criptográfico.
  ///
  /// Con "Skip nonce checks" apagado en Supabase:
  /// 1. Genera un rawNonce criptográfico aleatorio en Supabase.
  /// 2. Lo hashea con SHA-256 para Google Credential Manager (`setNonce`).
  /// 3. Solicita la credencial a Google con `serverClientId` = Client ID Web.
  /// 4. Envía a Supabase el `idToken` y el `rawNonce` original (sin hashear)
  ///    para que Supabase verifique la coincidencia.
  Future<AuthResponse> signInWithGoogle() async {
    final client = _resolveClient();
    if (client == null) {
      throw StateError('Supabase no está configurado (falta SUPABASE_URL).');
    }
    if (webClientId.isEmpty) {
      throw StateError(
        'Falta GOOGLE_WEB_CLIENT_ID para el inicio de sesión con Google.',
      );
    }

    // 1. Generar raw nonce
    final rawNonce = client.auth.generateRawNonce();

    // 2. Hash SHA-256 para pasar a Google
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    // 3. Inicializar Google Sign-In con el Web Client ID y el nonce hasheado
    await _googleSignIn.initialize(
      serverClientId: webClientId,
      nonce: hashedNonce,
    );

    // 4. Autenticar con Google
    final account = await _googleSignIn.authenticate();
    if (account == null) {
      throw const AuthException('Inicio de sesión cancelado por el usuario.');
    }

    final idToken = account.idToken;
    final accessToken = account.accessToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException(
        'No se recibió el token de identidad (idToken) de Google.',
      );
    }

    // 5. Enviar a Supabase idToken + accessToken + rawNonce
    return await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
      nonce: rawNonce,
    );
  }

  /// Cierra sesión en Supabase y desconecta Google.
  Future<void> signOut() async {
    final client = _resolveClient();
    if (client != null) {
      try {
        await client.auth.signOut();
      } catch (_) {}
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}

/// Provider de Riverpod para [AuthService].
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Provider de Riverpod que expone el Stream de sesión actual.
final authStateProvider = StreamProvider<Session?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});
