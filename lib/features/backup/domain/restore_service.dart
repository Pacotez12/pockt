import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/features/backup/data/backup_store.dart';
import 'package:pockt/features/backup/domain/backup_format.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Resumen de metadatos de una copia de seguridad para vista previa (Plan 4, Task 5).
class RestorePreview {
  final DateTime createdAt;
  final int transactionCount;
  final int schemaVersion;

  const RestorePreview({
    required this.createdAt,
    required this.transactionCount,
    required this.schemaVersion,
  });
}

/// Orquesta la vista previa y la restauración de copias .pockt,
/// asegurando una copia previa de seguridad local y vuelta atrás ante fallos.
class RestoreService {
  final BackupStore store;
  final Future<File> Function() dbFileResolver;
  final Future<void> Function()? closeDatabase;
  final Future<void> Function()? reopenDatabase;
  final int argonMemoryInKiB;
  final int argonIterations;

  RestoreService({
    required this.store,
    required this.dbFileResolver,
    this.closeDatabase,
    this.reopenDatabase,
    this.argonMemoryInKiB = 64 * 1024,
    this.argonIterations = 3,
  });

  /// Descarga el backup remoto, descifra en un archivo temporal con la contraseña dada,
  /// lee la cabecera y tablas con sqlite3 de solo lectura y devuelve un [RestorePreview].
  Future<RestorePreview> preview(String backupId, String password) async {
    final remoteList = await store.list();
    final remote = remoteList.firstWhere(
      (b) => b.id == backupId,
      orElse: () => throw Exception('Copia de seguridad no encontrada'),
    );

    final backupBytes = await store.download(backupId);
    final sqliteBytes = await decodeBackup(
      backupBytes,
      keyFor: (salt) => deriveKey(
        password,
        salt,
        memory: argonMemoryInKiB,
        iterations: argonIterations,
      ),
    );

    final tempDir = await Directory.systemTemp.createTemp('pockt_preview_');
    final tempFile = File('${tempDir.path}/preview.sqlite');
    try {
      await tempFile.writeAsBytes(sqliteBytes);
      final rawDb = sqlite.sqlite3.open(tempFile.path, mode: sqlite.OpenMode.readOnly);
      try {
        final versionResult = rawDb.select('PRAGMA user_version;');
        final schemaVersion = versionResult.first.values.first as int;

        final txCountResult = rawDb.select('SELECT COUNT(*) FROM transactions;');
        final txCount = txCountResult.first.values.first as int;

        return RestorePreview(
          createdAt: remote.createdAt,
          transactionCount: txCount,
          schemaVersion: schemaVersion,
        );
      } finally {
        rawDb.close();
      }
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  /// Restaura la base de datos a partir de una copia de seguridad:
  /// 1. Descarga y descifra (lanza WrongPasswordException si la clave no coincide, sin tocar archivos).
  /// 2. Cierra la conexión de base de datos actual (si se especificó).
  /// 3. Crea una copia local de respaldo de seguridad previa de la base actual.
  /// 4. Reemplaza el archivo por la versión restaurada.
  /// 5. Abre y valida la base restaurada (ejecutando migraciones si el schemaVersion es anterior).
  /// 6. Si cualquier paso falla, revierte inmediatamente a la copia previa y relanza la excepción.
  Future<void> restore(String backupId, String password) async {
    // 1. Descargar y descifrar primero.
    final backupBytes = await store.download(backupId);
    final sqliteBytes = await decodeBackup(
      backupBytes,
      keyFor: (salt) => deriveKey(
        password,
        salt,
        memory: argonMemoryInKiB,
        iterations: argonIterations,
      ),
    );

    final targetFile = await dbFileResolver();
    final backupCopy = File('${targetFile.path}.restore_safety_backup');
    final walFile = File('${targetFile.path}-wal');
    final shmFile = File('${targetFile.path}-shm');
    final walBackupCopy = File('${targetFile.path}.restore_safety_backup-wal');
    final shmBackupCopy = File('${targetFile.path}.restore_safety_backup-shm');

    // 2. Cerrar la base actual antes de tocar archivos
    if (closeDatabase != null) {
      await closeDatabase!();
    }

    // 3. Crear copia de seguridad previa de la base actual
    bool hasOriginal = false;
    if (await targetFile.exists()) {
      await targetFile.copy(backupCopy.path);
      hasOriginal = true;
      if (await walFile.exists()) {
        await walFile.copy(walBackupCopy.path);
      }
      if (await shmFile.exists()) {
        await shmBackupCopy.exists();
        await shmFile.copy(shmBackupCopy.path);
      }
    }

    try {
      // 4. Escribir los bytes restaurados y reemplazar
      final tempFile = File('${targetFile.path}.restoring');
      await tempFile.writeAsBytes(sqliteBytes);
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();
      await tempFile.copy(targetFile.path);
      if (await tempFile.exists()) await tempFile.delete();

      // 5. Validar y reabrir la base restaurada
      final testDb = AppDatabase.forTesting(NativeDatabase(targetFile));
      try {
        await testDb.customSelect('SELECT count(*) FROM categories').get();
      } finally {
        await testDb.close();
      }

      if (reopenDatabase != null) {
        await reopenDatabase!();
      }

      // Éxito: limpiar copias temporales
      if (await backupCopy.exists()) await backupCopy.delete();
      if (await walBackupCopy.exists()) await walBackupCopy.delete();
      if (await shmBackupCopy.exists()) await shmBackupCopy.delete();
    } catch (e) {
      // 6. Vuelta atrás (rollback)
      if (hasOriginal && await backupCopy.exists()) {
        await backupCopy.copy(targetFile.path);
        if (await walBackupCopy.exists()) {
          await walBackupCopy.copy(walFile.path);
        }
        if (await shmBackupCopy.exists()) {
          await shmBackupCopy.copy(shmFile.path);
        }
      }
      if (await backupCopy.exists()) await backupCopy.delete();
      if (await walBackupCopy.exists()) await walBackupCopy.delete();
      if (await shmBackupCopy.exists()) await shmBackupCopy.delete();

      if (reopenDatabase != null) {
        try {
          await reopenDatabase!();
        } catch (_) {}
      }

      rethrow;
    }
  }
}

/// Provider de Riverpod para [RestoreService].
final restoreServiceProvider = Provider<RestoreService>((ref) {
  final store = ref.watch(backupStoreProvider);
  return RestoreService(
    store: store,
    dbFileResolver: () async {
      final docDir = await getApplicationDocumentsDirectory();
      return File('${docDir.path}/pockt.sqlite');
    },
    closeDatabase: () async {
      final db = ref.read(databaseProvider);
      await db.close();
    },
    reopenDatabase: () async {
      ref.invalidate(databaseProvider);
    },
  );
});
