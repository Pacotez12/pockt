import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/backup/domain/backup_format.dart';

void main() {
  // Parámetros rápidos para tests unitarios
  const fastMemory = 1024;
  const fastIterations = 1;

  final sampleSqliteData = utf8.encode(
    'SQLite format 3\x00${'x' * 500}Transacciones de prueba Pockt 2026',
  );
  final sampleSalt = List<int>.generate(16, (i) => i + 1);

  group('Formato .pockt (cifrado y descifrado)', () {
    test('ida y vuelta devuelve los mismos bytes originales', () async {
      const password = 'mi-contraseña-segura';
      final key = await deriveKey(
        password,
        sampleSalt,
        memory: fastMemory,
        iterations: fastIterations,
      );

      final pocktBytes = await encodeBackup(sampleSqliteData, key, sampleSalt);

      expect(pocktBytes.length, greaterThan(sampleSalt.length + 35));

      final extractedSalt = readSalt(pocktBytes);
      expect(extractedSalt, equals(sampleSalt));

      final decoded = await decodeBackup(
        pocktBytes,
        keyFor: (salt) => deriveKey(
          password,
          salt,
          memory: fastMemory,
          iterations: fastIterations,
        ),
      );

      expect(decoded, equals(sampleSqliteData));
    });

    test('contraseña incorrecta lanza WrongPasswordException', () async {
      final key = await deriveKey(
        'clave-correcta',
        sampleSalt,
        memory: fastMemory,
        iterations: fastIterations,
      );

      final pocktBytes = await encodeBackup(sampleSqliteData, key, sampleSalt);

      expect(
        () => decodeBackup(
          pocktBytes,
          keyFor: (salt) => deriveKey(
            'clave-incorrecta',
            salt,
            memory: fastMemory,
            iterations: fastIterations,
          ),
        ),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('un byte alterado en ciphertext o tag lanza WrongPasswordException', () async {
      final key = await deriveKey(
        'clave-test',
        sampleSalt,
        memory: fastMemory,
        iterations: fastIterations,
      );

      final pocktBytes = await encodeBackup(sampleSqliteData, key, sampleSalt);

      // Alterar el último byte (parte del tag GCM)
      final corruptedTag = List<int>.from(pocktBytes);
      corruptedTag[corruptedTag.length - 1] ^= 0x55;

      expect(
        () => decodeBackup(
          corruptedTag,
          keyFor: (salt) => deriveKey(
            'clave-test',
            salt,
            memory: fastMemory,
            iterations: fastIterations,
          ),
        ),
        throwsA(isA<WrongPasswordException>()),
      );

      // Alterar un byte en el medio (ciphertext)
      final corruptedPayload = List<int>.from(pocktBytes);
      corruptedPayload[40] ^= 0xAA;

      expect(
        () => decodeBackup(
          corruptedPayload,
          keyFor: (salt) => deriveKey(
            'clave-test',
            salt,
            memory: fastMemory,
            iterations: fastIterations,
          ),
        ),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('un byte alterado en la sal (autenticada vía AAD) lanza WrongPasswordException', () async {
      final key = await deriveKey(
        'clave-test',
        sampleSalt,
        memory: fastMemory,
        iterations: fastIterations,
      );

      final pocktBytes = await encodeBackup(sampleSqliteData, key, sampleSalt);

      // Alterar un byte de la sal (offset 7 a 22)
      final corruptedSalt = List<int>.from(pocktBytes);
      corruptedSalt[7] ^= 0x55;

      expect(
        () => decodeBackup(
          corruptedSalt,
          keyFor: (salt) => deriveKey(
            'clave-test',
            salt,
            memory: fastMemory,
            iterations: fastIterations,
          ),
        ),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('magic inválido lanza BadBackupFormatException', () async {
      final key = await deriveKey(
        'clave-test',
        sampleSalt,
        memory: fastMemory,
        iterations: fastIterations,
      );

      final pocktBytes = await encodeBackup(sampleSqliteData, key, sampleSalt);

      final corruptedMagic = List<int>.from(pocktBytes);
      corruptedMagic[0] = 0x00; // 'P' -> 0x00

      expect(
        () => decodeBackup(
          corruptedMagic,
          keyFor: (salt) => deriveKey(
            'clave-test',
            salt,
            memory: fastMemory,
            iterations: fastIterations,
          ),
        ),
        throwsA(isA<BadBackupFormatException>()),
      );

      expect(() => readSalt(corruptedMagic), throwsA(isA<BadBackupFormatException>()));
    });

    test('versión de formato no soportada lanza BadBackupFormatException', () async {
      final key = await deriveKey(
        'clave-test',
        sampleSalt,
        memory: fastMemory,
        iterations: fastIterations,
      );

      final pocktBytes = await encodeBackup(sampleSqliteData, key, sampleSalt);

      final corruptedVersion = List<int>.from(pocktBytes);
      corruptedVersion[6] = 0x99; // Versión 153 en vez de 1

      expect(
        () => decodeBackup(
          corruptedVersion,
          keyFor: (salt) => deriveKey(
            'clave-test',
            salt,
            memory: fastMemory,
            iterations: fastIterations,
          ),
        ),
        throwsA(isA<BadBackupFormatException>()),
      );

      expect(() => readSalt(corruptedVersion), throwsA(isA<BadBackupFormatException>()));
    });

    test('archivo incompleto o menor a 51 bytes lanza BadBackupFormatException', () async {
      expect(
        () => decodeBackup(
          [1, 2, 3],
          keyFor: (salt) async => throw UnimplementedError(),
        ),
        throwsA(isA<BadBackupFormatException>()),
      );

      expect(() => readSalt([1, 2, 3]), throwsA(isA<BadBackupFormatException>()));
    });

    test('dos backups con la misma clave tienen nonces distintos', () async {
      final key = await deriveKey(
        'clave-test',
        sampleSalt,
        memory: fastMemory,
        iterations: fastIterations,
      );

      final backup1 = await encodeBackup(sampleSqliteData, key, sampleSalt);
      final backup2 = await encodeBackup(sampleSqliteData, key, sampleSalt);

      // Offset nonce = 23 a 35 (12 bytes)
      final nonce1 = backup1.sublist(23, 35);
      final nonce2 = backup2.sublist(23, 35);

      expect(nonce1, isNot(equals(nonce2)));
      expect(backup1, isNot(equals(backup2)));
    });

    test('deriveKey con parámetros por defecto (Argon2id 64 MiB, 3 iteraciones)', () async {
      final key = await deriveKey('test-default', sampleSalt);
      final keyBytes = await key.extractBytes();
      expect(keyBytes.length, equals(32));
    });
  });
}
