import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento seguro de la clave derivada de respaldo y su sal en Android Keystore
/// (`flutter_secure_storage`). En tests se usa [KeyStorage.inMemory].
class KeyStorage {
  static const _keyName = 'pockt_backup_derived_key';
  static const _saltName = 'pockt_backup_salt';

  final FlutterSecureStorage? _storage;
  final Map<String, String>? _memory;

  /// Constructor para producción, usando `flutter_secure_storage`.
  KeyStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(resetOnError: true),
            ),
        _memory = null;

  /// Constructor para tests unitarios o entornos en memoria sin canales de plataforma.
  KeyStorage.inMemory()
      : _storage = null,
        _memory = <String, String>{};

  /// Guarda los bytes de la clave y de la sal codificados en Base64.
  Future<void> saveKey(List<int> keyBytes, List<int> salt) async {
    final keyB64 = base64Encode(keyBytes);
    final saltB64 = base64Encode(salt);

    final memory = _memory;
    if (memory != null) {
      memory[_keyName] = keyB64;
      memory[_saltName] = saltB64;
    } else {
      final storage = _storage!;
      await storage.write(key: _keyName, value: keyB64);
      await storage.write(key: _saltName, value: saltB64);
    }
  }

  /// Carga la clave derivada y la sal guardadas, o devuelve `null` si no hay ninguna.
  Future<({List<int> key, List<int> salt})?> load() async {
    final String? keyB64;
    final String? saltB64;

    final memory = _memory;
    if (memory != null) {
      keyB64 = memory[_keyName];
      saltB64 = memory[_saltName];
    } else {
      final storage = _storage!;
      keyB64 = await storage.read(key: _keyName);
      saltB64 = await storage.read(key: _saltName);
    }

    if (keyB64 == null || saltB64 == null) {
      return null;
    }

    try {
      return (
        key: base64Decode(keyB64),
        salt: base64Decode(saltB64),
      );
    } catch (_) {
      return null;
    }
  }

  /// Borra la clave y la sal del almacenamiento seguro.
  Future<void> clear() async {
    final memory = _memory;
    if (memory != null) {
      memory.remove(_keyName);
      memory.remove(_saltName);
    } else {
      final storage = _storage!;
      await storage.delete(key: _keyName);
      await storage.delete(key: _saltName);
    }
  }
}

final keyStorageProvider = Provider<KeyStorage>((ref) {
  return KeyStorage();
});
