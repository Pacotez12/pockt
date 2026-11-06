import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:powersync/powersync.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:sqlite_async/sqlite_async.dart';

class MigrationReport {
  final Map<String, int> rowsByTable;
  final Map<String, int> amountSumByTable;

  const MigrationReport({
    required this.rowsByTable,
    required this.amountSumByTable,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MigrationReport &&
        mapEquals(other.rowsByTable, rowsByTable) &&
        mapEquals(other.amountSumByTable, amountSumByTable);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(rowsByTable.entries.map((e) => Object.hash(e.key, e.value))),
        Object.hashAll(amountSumByTable.entries.map((e) => Object.hash(e.key, e.value))),
      );

  @override
  String toString() =>
      'MigrationReport(rowsByTable: $rowsByTable, amountSumByTable: $amountSumByTable)';
}

const kMigrationMarkKey = 'legacy_drift_migrated';

/// Todas las tablas de Pockt (12 sincronizadas + 6 locales).
const allPocktTables = [
  // 12 tablas sincronizadas:
  'categories',
  'transactions',
  'loans',
  'loan_installments',
  'goals',
  'goal_contributions',
  'budgets',
  'recurring_rules',
  'income_schedules',
  'salary_deductions',
  'events',
  'settings',
  // 6 tablas locales:
  'suggested_transactions',
  'merchant_memory',
  'category_keywords',
  'counterparty_rules',
  'entry_shortcuts',
  'day_marks',
];

/// Asegura que la base vieja de Drift corra sus migraciones pendientes hasta v17
/// antes de copiar los datos a PowerSync.
Future<void> ensureLegacyDbMigrated(String legacyDbPath) async {
  final file = File(legacyDbPath);
  if (!file.existsSync()) return;

  final legacyDb = AppDatabase.forTesting(
    DatabaseConnection(
      NativeDatabase(
        file,
        setup: (rawDb) {
          rawDb.execute('PRAGMA busy_timeout = 30000;');
        },
      ),
      closeStreamsSynchronously: true,
    ),
  );
  try {
    // Forzar apertura y migraciones onCreate/onUpgrade de Drift
    await legacyDb.customSelect('SELECT 1').get();
  } finally {
    await legacyDb.close();
  }
}

/// Comprueba si la marca de migración ya fue guardada en la base destino.
Future<bool> isMigrationMarkSaved(SqliteReadContext target) async {
  try {
    final row = await target.getOptional(
      "SELECT value FROM _pockt_migration WHERE key = '$kMigrationMarkKey' LIMIT 1",
    );
    return row?['value'] == '1';
  } catch (_) {
    return false;
  }
}

/// Migra los datos de una base de datos Drift existente a una instancia de [PowerSyncDatabase].
///
/// 1. Comprueba si ya fue migrada. Si ya lo fue, retorna null sin hacer nada.
/// 2. Entra en una transacción exclusiva de escritura en la base PowerSync.
/// 3. Vuelve a comprobar la marca adentro de la transacción; si ya está, no hace nada.
/// 4. Copia el archivo original, sin tocar, a `<oldDbPath>.pre-sync.bak`.
/// 5. Asegura que la base vieja esté migrada (v17) bajo ese lock.
/// 6. Copia todas las tablas (12 sincronizadas + 6 locales) dentro de la transacción (sin DELETEs).
/// 7. Deriva la columna `id` si faltara para compatibilidad con esquemas anteriores.
/// 8. Registra la marca de migración en `_pockt_migration` dentro de la transacción.
Future<MigrationReport?> migrateLegacyDriftDb({
  required String oldDbPath,
  required PowerSyncDatabase target,
  String? simulateFailureAtTable,
}) async {
  final originalFile = File(oldDbPath);
  if (!originalFile.existsSync()) {
    return null;
  }

  // Comprobación rápida previa fuera del lock
  if (await isMigrationMarkSaved(target)) {
    return null;
  }

  MigrationReport? report;

  // Decisión final y migración dentro de la misma transacción de escritura
  await target.writeTransaction((tx) async {
    await tx.execute(
      'CREATE TABLE IF NOT EXISTS _pockt_migration (key TEXT PRIMARY KEY, value TEXT);',
    );

    if (await isMigrationMarkSaved(tx)) {
      return;
    }

    // Copia de seguridad del archivo original, antes de tocarlo
    final backupFile = File('$oldDbPath.pre-sync.bak');
    if (!backupFile.existsSync() || backupFile.lengthSync() == 0) {
      final tempBackup = File('$oldDbPath.pre-sync.bak.tmp');
      if (tempBackup.existsSync()) {
        await tempBackup.delete();
      }
      await originalFile.copy(tempBackup.path);
      await tempBackup.rename(backupFile.path);
    }

    // Asegurar que la base vieja de Drift esté migrada a v17 bajo el lock
    await ensureLegacyDbMigrated(oldDbPath);

    final oldDb = sqlite.sqlite3.open(oldDbPath, mode: sqlite.OpenMode.readOnly);
    final rowsByTable = <String, int>{};
    final amountSumByTable = <String, int>{};

    try {
      // Medir métricas de origen
      for (final table in allPocktTables) {
        final tableExists = oldDb.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$table'",
        );
        if (tableExists.isEmpty) {
          rowsByTable[table] = 0;
          continue;
        }

        final originPragma = oldDb.select('PRAGMA table_info("$table")');
        final originColumns =
            originPragma.map((r) => r['name'] as String).toList();
        final hasAmount = originColumns.contains('amount');

        final countRes =
            oldDb.select('SELECT count(*) as c FROM "$table"');
        rowsByTable[table] = countRes.first['c'] as int;

        if (hasAmount) {
          final sumRes = oldDb.select(
            'SELECT COALESCE(SUM(amount), 0) as s FROM "$table"',
          );
          amountSumByTable[table] = sumRes.first['s'] as int;
        }
      }

      for (final table in allPocktTables) {
        if (simulateFailureAtTable == table) {
          throw Exception('Simulated cut midway at table $table');
        }

        final tableExists = oldDb.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$table'",
        );
        if (tableExists.isEmpty) continue;

        final originPragma = oldDb.select('PRAGMA table_info("$table")');
        final originColumns =
            originPragma.map((r) => r['name'] as String).toList();
        final rows = oldDb.select('SELECT * FROM "$table"');

        if (rows.isEmpty) continue;

        final targetColsRaw = await tx.getAll('PRAGMA table_info("$table")');
        final targetColumns =
            targetColsRaw.map((r) => r['name'] as String).toSet();

        for (final row in rows) {
          final Map<String, dynamic> rowData = {};
          for (final col in originColumns) {
            rowData[col] = row[col];
          }

          // Derivar id si no estuviera presente (p. ej. esquemas anteriores a v17)
          if (table == 'loan_installments') {
            rowData['id'] ??= '${rowData['loan_id']}:${rowData['number']}';
          } else if (table == 'settings') {
            rowData['id'] ??= rowData['key'];
          } else if (table == 'day_marks') {
            rowData['id'] ??= rowData['date'];
          } else if (table == 'merchant_memory') {
            rowData['id'] ??=
                '${rowData['merchant_key']}|${rowData['category_id']}';
          }

          final insertKeys =
              rowData.keys.where((k) => targetColumns.contains(k)).toList();
          final colList = insertKeys.map((k) => '"$k"').join(', ');
          final placeholders = List.filled(insertKeys.length, '?').join(', ');
          final values = insertKeys.map((k) => rowData[k]).toList();

          await tx.execute(
            'INSERT INTO "$table" ($colList) VALUES ($placeholders)',
            values,
          );
        }
      }

      // Guardar la marca de migración dentro de la misma transacción
      await tx.execute(
        "INSERT OR REPLACE INTO _pockt_migration (key, value) VALUES ('$kMigrationMarkKey', '1');",
      );

      report = MigrationReport(
        rowsByTable: rowsByTable,
        amountSumByTable: amountSumByTable,
      );
    } finally {
      oldDb.close();
    }
  });

  return report;
}
