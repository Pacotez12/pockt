import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/backup/data/backup_store.dart';
import 'package:pockt/features/backup/data/key_storage.dart';
import 'package:pockt/features/backup/data/snapshot.dart';
import 'package:pockt/features/backup/domain/backup_format.dart';

/// Resultados tipados de la operación de respaldo (Plan 4, Task 4).
enum BackupResult {
  success,
  noPassword,
  storage,
  unknown;

  bool get isSuccess => this == BackupResult.success;
}

/// Estado del sistema de respaldo para observación reactiva.
class BackupStatus {
  final DateTime? lastSuccessAt;
  final BackupResult? lastError;
  final bool isOverdue;

  const BackupStatus({
    this.lastSuccessAt,
    this.lastError,
    required this.isOverdue,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupStatus &&
          runtimeType == other.runtimeType &&
          lastSuccessAt == other.lastSuccessAt &&
          lastError == other.lastError &&
          isOverdue == other.isOverdue;

  @override
  int get hashCode => Object.hash(lastSuccessAt, lastError, isOverdue);

  @override
  String toString() =>
      'BackupStatus(lastSuccessAt: $lastSuccessAt, lastError: $lastError, isOverdue: $isOverdue)';
}

/// Orquestador del sistema de copias de seguridad de Pockt.
class BackupService {
  final AppDatabase db;
  final BackupStore store;
  final KeyStorage keys;
  final SettingsRepository settings;
  final DateTime Function() _clock;
  final int argonIterations;
  final int argonMemoryInKiB;

  BackupService({
    required this.db,
    required this.store,
    required this.keys,
    required this.settings,
    DateTime Function()? clock,
    this.argonIterations = 3,
    this.argonMemoryInKiB = 64 * 1024,
  }) : _clock = clock ?? DateTime.now;

  /// Genera una sal criptográfica, deriva la clave de respaldo con Argon2id
  /// y la guarda de forma segura en [KeyStorage].
  Future<void> setPassword(String password) async {
    final salt = generateSalt();
    final secretKey = await deriveKey(
      password,
      salt,
      iterations: argonIterations,
      memory: argonMemoryInKiB,
    );
    final keyBytes = await secretKey.extractBytes();
    await keys.saveKey(keyBytes, salt);
  }

  /// Ejecuta un respaldo inmediato:
  /// instantánea -> formato .pockt -> subida -> poda a 7 -> guarda metadatos.
  Future<BackupResult> backupNow() async {
    final keyData = await keys.load();
    if (keyData == null) {
      await settings.set(
        SettingsKeys.backupLastError,
        BackupResult.noPassword.name,
      );
      return BackupResult.noPassword;
    }

    try {
      final dbBytes = await snapshotDatabase(db);
      final pocktBytes = await encodeBackup(
        dbBytes,
        SecretKey(keyData.key),
        keyData.salt,
      );

      final now = _clock();
      final fileName = _buildFileName(now);

      await store.upload(fileName, pocktBytes);

      // Podar para conservar las últimas 7 copias
      final remoteList = await store.list();
      if (remoteList.length > 7) {
        final toDelete = remoteList.sublist(7);
        for (final backup in toDelete) {
          try {
            await store.delete(backup.id);
          } catch (_) {
            // No interrumpir si falla el borrado de una copia vieja
          }
        }
      }

      await settings.set(
        SettingsKeys.backupLastSuccessAt,
        now.toIso8601String(),
      );
      await settings.set(SettingsKeys.backupLastError, '');
      return BackupResult.success;
    } on Exception catch (_) {
      // Escritura en Documentos/Pockt fallida (espacio, permisos, archivo).
      await settings.set(
        SettingsKeys.backupLastError,
        BackupResult.storage.name,
      );
      return BackupResult.storage;
    } catch (_) {
      await settings.set(
        SettingsKeys.backupLastError,
        BackupResult.unknown.name,
      );
      return BackupResult.unknown;
    }
  }

  /// Genera un `.pockt` cifrado con la contraseña actual sin guardarlo, para
  /// compartirlo. `null` si no hay contraseña configurada.
  Future<({String name, List<int> bytes})?> buildExport() async {
    final keyData = await keys.load();
    if (keyData == null) return null;
    final bytes = await encodeBackup(
      await snapshotDatabase(db),
      SecretKey(keyData.key),
      keyData.salt,
    );
    return (name: _buildFileName(_clock()), bytes: bytes);
  }

  /// Backup automático: corre si hay contraseña y pasaron 48 h desde el
  /// último éxito (o nunca hubo). Devuelve `null` si no tocaba.
  Future<BackupResult?> backupIfDue() async {
    if (await keys.load() == null) return null;
    final last = DateTime.tryParse(
      await settings.get(SettingsKeys.backupLastSuccessAt) ?? '',
    );
    if (last != null && _clock().difference(last) < const Duration(hours: 48)) {
      return null;
    }
    return backupNow();
  }

  /// Observa el estado reactivo del backup.
  Stream<BackupStatus> watchStatus() {
    return settings
        .watch(SettingsKeys.backupLastSuccessAt)
        .asyncMap((successStr) async {
      final errorStr = await settings.get(SettingsKeys.backupLastError);
      return _buildStatus(successStr, errorStr);
    });
  }

  /// Consulta el estado puntual.
  Future<BackupStatus> getStatus() async {
    final successStr = await settings.get(SettingsKeys.backupLastSuccessAt);
    final errorStr = await settings.get(SettingsKeys.backupLastError);
    return _buildStatus(successStr, errorStr);
  }

  BackupStatus _buildStatus(String? successStr, String? errorStr) {
    DateTime? lastSuccess;
    if (successStr != null && successStr.isNotEmpty) {
      lastSuccess = DateTime.tryParse(successStr);
    }

    BackupResult? lastError;
    if (errorStr != null && errorStr.isNotEmpty) {
      for (final r in BackupResult.values) {
        if (r.name == errorStr) {
          lastError = r;
          break;
        }
      }
    }

    // Nunca haber hecho un backup también es estar atrasado.
    final isOverdue = lastSuccess == null ||
        _clock().difference(lastSuccess).inDays >= 5;

    return BackupStatus(
      lastSuccessAt: lastSuccess,
      lastError: lastError,
      isOverdue: isOverdue,
    );
  }

  String _buildFileName(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return 'pockt-$y$m$d-$hh$mm$ss.pockt';
  }
}

/// Proveedor principal de [BackupService].
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    db: ref.watch(databaseProvider),
    store: ref.watch(backupStoreProvider),
    keys: ref.watch(keyStorageProvider),
    settings: ref.watch(settingsRepositoryProvider),
  );
});
