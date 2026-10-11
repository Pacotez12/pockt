import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Magic identificador del formato: ASCII "POCKT1" (6 bytes).
const List<int> pocktMagic = [0x50, 0x4F, 0x43, 0x4B, 0x54, 0x31];

/// Versión actual del formato de backup.
const int pocktVersion = 1;

/// Longitud de la sal Argon2id en bytes (16 bytes).
const int saltLength = 16;

/// Longitud del nonce AES-GCM en bytes (12 bytes).
const int nonceLength = 12;

/// Longitud del tag de autenticación MAC AES-GCM en bytes (16 bytes).
const int macLength = 16;

/// Encabezado mínimo: magic (6) + versión (1) + sal (16) + nonce (12) + tag (16) = 51 bytes.
const int minBackupLength = 6 + 1 + saltLength + nonceLength + macLength;

/// Excepción lanzada cuando la contraseña no coincide o los datos cifrados fueron alterados.
class WrongPasswordException implements Exception {
  final String message;

  const WrongPasswordException([this.message = 'Contraseña incorrecta o datos alterados']);

  @override
  String toString() => 'WrongPasswordException: $message';
}

/// Excepción lanzada cuando el archivo no tiene el formato .pockt válido (magic, versión o tamaño).
class BadBackupFormatException implements Exception {
  final String message;

  const BadBackupFormatException(this.message);

  @override
  String toString() => 'BadBackupFormatException: $message';
}

/// Genera una sal criptográfica segura de [length] bytes (16 por defecto).
List<int> generateSalt([int length = saltLength]) {
  final random = Random.secure();
  return Uint8List.fromList(List<int>.generate(length, (_) => random.nextInt(256)));
}

/// Deriva una clave AES-256 de 32 bytes a partir de [password] y [salt] usando Argon2id.
///
/// Parámetros de producción según spec: memoria 64 MiB (65536 kB), 3 iteraciones, paralelismo 1.
/// Los parámetros opcionales [memory], [iterations] y [parallelism] permiten acelerar tests unitarios.
Future<SecretKey> deriveKey(
  String password,
  List<int> salt, {
  int memory = 64 * 1024,
  int iterations = 3,
  int parallelism = 1,
}) async {
  final algorithm = Argon2id(
    parallelism: parallelism,
    memory: memory,
    iterations: iterations,
    hashLength: 32,
  );
  return algorithm.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt,
  );
}

/// Codifica una copia de la base SQLite en formato `.pockt`:
/// `magic (6B) + version (1B) + salt (16B) + nonce (12B) + ciphertext + tag (16B)`
/// del contenido comprimido con gzip.
Future<List<int>> encodeBackup(
  List<int> sqliteBytes,
  SecretKey key,
  List<int> salt,
) async {
  if (salt.length != saltLength) {
    throw ArgumentError.value(salt.length, 'salt', 'La sal debe tener $saltLength bytes');
  }

  // 1. Compresión gzip
  final compressed = gzip.encode(sqliteBytes);

  // 2. Encabezado autenticado (AAD): magic (6B) + version (1B) + salt (16B) = 23 bytes
  final aad = Uint8List.fromList([
    ...pocktMagic,
    pocktVersion,
    ...salt,
  ]);

  // 3. Cifrado AES-256-GCM con AAD
  final algorithm = AesGcm.with256bits();
  final secretBox = await algorithm.encrypt(
    compressed,
    secretKey: key,
    aad: aad,
  );

  // 4. Ensamblado del archivo .pockt
  final builder = BytesBuilder(copy: false)
    ..add(pocktMagic)
    ..addByte(pocktVersion)
    ..add(salt)
    ..add(secretBox.nonce)
    ..add(secretBox.cipherText)
    ..add(secretBox.mac.bytes);

  return builder.toBytes();
}

/// Lee la sal Argon2id (16 bytes) del encabezado de un archivo `.pockt` sin descifrarlo.
List<int> readSalt(List<int> pocktBytes) {
  _validateHeader(pocktBytes);
  return pocktBytes.sublist(7, 7 + saltLength);
}

/// Descifra un archivo `.pockt`, obteniendo la clave con [keyFor] usando la sal leída.
/// Devuelve los bytes originales de la base SQLite.
/// Lanza [WrongPasswordException] si la clave no es válida o los datos están alterados.
/// Lanza [BadBackupFormatException] si el magic, versión o estructura no corresponden.
Future<List<int>> decodeBackup(
  List<int> pocktBytes, {
  required Future<SecretKey> Function(List<int> salt) keyFor,
}) async {
  _validateHeader(pocktBytes);

  final aad = pocktBytes.sublist(0, 7 + saltLength);
  final salt = pocktBytes.sublist(7, 7 + saltLength);
  final key = await keyFor(salt);

  final nonce = pocktBytes.sublist(23, 23 + nonceLength);
  final cipherTextWithTag = pocktBytes.sublist(23 + nonceLength);

  if (cipherTextWithTag.length < macLength) {
    throw const BadBackupFormatException('El archivo no contiene el tag de autenticación');
  }

  final cipherText = cipherTextWithTag.sublist(0, cipherTextWithTag.length - macLength);
  final macBytes = cipherTextWithTag.sublist(cipherTextWithTag.length - macLength);

  final secretBox = SecretBox(
    cipherText,
    nonce: nonce,
    mac: Mac(macBytes),
  );

  final algorithm = AesGcm.with256bits();
  final List<int> compressed;
  try {
    compressed = await algorithm.decrypt(
      secretBox,
      secretKey: key,
      aad: aad,
    );
  } on SecretBoxAuthenticationError {
    throw const WrongPasswordException();
  } catch (e) {
    throw const WrongPasswordException();
  }

  try {
    return gzip.decode(compressed);
  } catch (e) {
    throw BadBackupFormatException('Error al descomprimir los datos: $e');
  }
}

void _validateHeader(List<int> pocktBytes) {
  if (pocktBytes.length < minBackupLength) {
    throw const BadBackupFormatException('Archivo incompleto o menor al tamaño mínimo');
  }
  for (var i = 0; i < pocktMagic.length; i++) {
    if (pocktBytes[i] != pocktMagic[i]) {
      throw const BadBackupFormatException('Encabezado mágico inválido: no es un archivo .pockt');
    }
  }
  if (pocktBytes[6] != pocktVersion) {
    throw BadBackupFormatException('Versión de formato no soportada (${pocktBytes[6]})');
  }
}
