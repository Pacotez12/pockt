import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/backup/data/backup_store.dart';
import 'package:pockt/features/backup/data/drive_backup_store.dart';
import 'package:pockt/features/backup/data/key_storage.dart';
import 'package:pockt/features/backup/data/snapshot.dart';
import 'package:pockt/features/backup/domain/backup_format.dart';

/// Resultados tipados de la operación de respaldo (Plan 4, Task 4).
enum BackupResult {
  success,
  noPassword,
  notSignedIn,
  network,
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
    } on DriveAuthRequiredException {
      await settings.set(
        SettingsKeys.backupLastError,
        BackupResult.notSignedIn.name,
      );
      return BackupResult.notSignedIn;
    } on SocketException {
      await settings.set(
        SettingsKeys.backupLastError,
        BackupResult.network.name,
      );
      return BackupResult.network;
    } on TimeoutException {
      await settings.set(
        SettingsKeys.backupLastError,
        BackupResult.network.name,
      );
      return BackupResult.network;
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('socket') ||
          err.contains('network') ||
          err.contains('clientexception') ||
          err.contains('failed host lookup') ||
          err.contains('connection')) {
        await settings.set(
          SettingsKeys.backupLastError,
          BackupResult.network.name,
        );
        return BackupResult.network;
      }
      if (err.contains('auth') ||
          err.contains('sign_in') ||
          err.contains('unauthorized') ||
          err.contains('401')) {
        await settings.set(
          SettingsKeys.backupLastError,
          BackupResult.notSignedIn.name,
        );
        return BackupResult.notSignedIn;
      }

      await settings.set(
        SettingsKeys.backupLastError,
        BackupResult.unknown.name,
      );
      return BackupResult.unknown;
    }
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

    final isOverdue = lastSuccess != null &&
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
