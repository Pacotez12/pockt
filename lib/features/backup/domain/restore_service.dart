import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/sync/migrate_legacy_db.dart';
import 'package:pockt/core/sync/pockt_powersync.dart';
import 'package:pockt/features/backup/data/backup_store.dart';
import 'package:pockt/features/backup/domain/backup_format.dart';
import 'package:powersync/powersync.dart';
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

/// Excepción lanzada cuando no es seguro restaurar (por ejemplo con PowerSync activo).
class RestoreSafetyException implements Exception {
  final String message;

  const RestoreSafetyException(this.message);

  @override
  String toString() => 'RestoreSafetyException: $message';
}

/// Orquesta la vista previa y la restauración de copias .pockt
/// sobre la base de datos activa PowerSync.
class RestoreService {
  final BackupStore store;
  final Future<PowerSyncDatabase> Function()? powerSyncResolver;
  final PowerSyncDatabase? powerSyncDatabase;
  final Future<File> Function()? dbFileResolver;
  final Future<void> Function()? closeDatabase;
  final Future<void> Function()? reopenDatabase;
  final Future<void> Function()? beforeRestore;
  final String? simulateFailureAtTable;
  final int argonMemoryInKiB;
  final int argonIterations;

  RestoreService({
    required this.store,
    this.powerSyncResolver,
    this.powerSyncDatabase,
    this.dbFileResolver,
    this.closeDatabase,
    this.reopenDatabase,
    this.beforeRestore,
    this.simulateFailureAtTable,
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
    return previewBytes(
      await store.download(backupId),
      password,
      createdAt: remote.createdAt,
    );
  }

  /// Vista previa de un `.pockt` ya en memoria (por ejemplo elegido con el
  /// selector de archivos). Acepta formato legacy Drift y formato PowerSync.
  Future<RestorePreview> previewBytes(
    List<int> backupBytes,
    String password, {
    required DateTime createdAt,
  }) async {
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
        final isPowerSync = rawDb.select(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'ps_data__transactions'",
        ).isNotEmpty;

        final versionResult = rawDb.select('PRAGMA user_version;');
        var schemaVersion = versionResult.first.values.first as int;

        final int txCount;
        if (isPowerSync) {
          if (schemaVersion == 0) schemaVersion = 17;
          final txCountResult =
              rawDb.select('SELECT COUNT(*) FROM ps_data__transactions;');
          txCount = txCountResult.first.values.first as int;
        } else {
          final txCountResult =
              rawDb.select('SELECT COUNT(*) FROM transactions;');
          txCount = txCountResult.first.values.first as int;
        }

        return RestorePreview(
          createdAt: createdAt,
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
  /// 2. Lee los datos en solo lectura (subiendo a v17 si es una base legacy v1..v16).
  /// 3. En UNA transacción de escritura sobre PowerSync, reemplaza las 18 tablas (12 sync + 6 local).
  Future<void> restore(String backupId, String password) async {
    await restoreBytes(
      await store.download(backupId),
      password,
    );
  }

  /// Restaura desde un `.pockt` ya en memoria sobre la base PowerSync.
  Future<void> restoreBytes(
    List<int> backupBytes,
    String password, {
    String? simulateFailureAtTable,
  }) async {
    // 0. Bloqueo de seguridad preventivo opcional
    if (beforeRestore != null) {
      await beforeRestore!();
    }

    final failureTable = simulateFailureAtTable ?? this.simulateFailureAtTable;

    // 1. Descifrar primero: con contraseña incorrecta falla aquí sin tocar la base.
    final sqliteBytes = await decodeBackup(
      backupBytes,
      keyFor: (salt) => deriveKey(
        password,
        salt,
        memory: argonMemoryInKiB,
        iterations: argonIterations,
      ),
    );

    final target = powerSyncDatabase ??
        (powerSyncResolver != null
            ? await powerSyncResolver!()
            : await openPocktPowerSync());

    // 2. Extraer datos en archivo temporal
    final tempDir = await Directory.systemTemp.createTemp('pockt_restore_');
    final tempFile = File('${tempDir.path}/restore.sqlite');

    try {
      await tempFile.writeAsBytes(sqliteBytes);

      // Detectar formato
      final testDb = sqlite.sqlite3.open(tempFile.path, mode: sqlite.OpenMode.readOnly);
      final isPowerSync = testDb.select(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'ps_data__transactions'",
      ).isNotEmpty;
      testDb.close();

      final extractedRowsByTable = <String, List<Map<String, dynamic>>>{};

      if (isPowerSync) {
        // Formato (b): Copia PowerSync. Leer ps_data__* y ps_data_local__*
        final psSqlite = sqlite.sqlite3.open(tempFile.path, mode: sqlite.OpenMode.readOnly);
        try {
          for (final table in allPocktTables) {
            final checkTable = psSqlite.select(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('ps_data__$table', 'ps_data_local__$table')",
            );
            if (checkTable.isEmpty) continue;
            final storageTable = checkTable.first['name'] as String;
            final rows = psSqlite.select('SELECT id, data FROM "$storageTable"');
            final mappedList = <Map<String, dynamic>>[];
            for (final row in rows) {
              final id = row['id'] as String;
              final dataStr = row['data'] as String?;
              final Map<String, dynamic> dataMap =
                  (dataStr != null && dataStr.isNotEmpty)
                      ? (jsonDecode(dataStr) as Map<String, dynamic>)
                      : <String, dynamic>{};
              dataMap['id'] = id;
              mappedList.add(dataMap);
            }
            extractedRowsByTable[table] = mappedList;
          }
        } finally {
          psSqlite.close();
        }
      } else {
        // Formato (a): Copia Drift v1..v17. Subir a v17 en archivo temporal si es anterior.
        await ensureLegacyDbMigrated(tempFile.path);

        final legacySqlite = sqlite.sqlite3.open(tempFile.path, mode: sqlite.OpenMode.readOnly);
        try {
          for (final table in allPocktTables) {
            final checkTable = legacySqlite.select(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = '$table'",
            );
            if (checkTable.isEmpty) continue;

            final originPragma = legacySqlite.select('PRAGMA table_info("$table")');
            final originColumns = originPragma.map((r) => r['name'] as String).toList();
            final rows = legacySqlite.select('SELECT * FROM "$table"');
            final mappedList = rows.map((r) {
              final map = <String, dynamic>{};
              for (final col in originColumns) {
                map[col] = r[col];
              }
              return map;
            }).toList();
            extractedRowsByTable[table] = mappedList;
          }
        } finally {
          legacySqlite.close();
        }
      }

      // 3. En UNA transacción de escritura en PowerSync:
      //    Reemplazar el contenido de las 18 tablas (12 sync + 6 local).
      //    Si algo falla a mitad, SQLite hace rollback y nada cambia.
      //    No tocar _pockt_sync_owner ni _pockt_migration.
      await target.writeTransaction((tx) async {
        // Borrar datos actuales de las 18 tablas en orden inverso
        for (final table in allPocktTables.reversed) {
          await tx.execute('DELETE FROM "$table"');
        }

        // Insertar contenido de la copia
        for (final table in allPocktTables) {
          if (failureTable == table) {
            throw Exception('Simulated cut midway at table $table');
          }

          final rows = extractedRowsByTable[table];
          if (rows != null && rows.isNotEmpty) {
            await copyRowsToPowerSyncTable(
              tx: tx,
              table: table,
              rows: rows,
            );
          }
        }
      });
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  }
}

/// Provider de Riverpod para [RestoreService].
final restoreServiceProvider = Provider<RestoreService>((ref) {
  final store = ref.watch(backupStoreProvider);
  return RestoreService(
    store: store,
    powerSyncResolver: openPocktPowerSync,
  );
});
