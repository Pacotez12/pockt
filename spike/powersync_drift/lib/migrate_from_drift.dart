import 'dart:io';

import 'package:collection/collection.dart';
import 'package:powersync/powersync.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

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
        const MapEquality().equals(other.rowsByTable, rowsByTable) &&
        const MapEquality().equals(other.amountSumByTable, amountSumByTable);
  }

  @override
  int get hashCode => Object.hash(
        const MapEquality().hash(rowsByTable),
        const MapEquality().hash(amountSumByTable),
      );

  @override
  String toString() =>
      'MigrationReport(rowsByTable: $rowsByTable, amountSumByTable: $amountSumByTable)';
}

/// Tablas sincronizadas de la spec de Pockt (sección 4).
const synchronizedTables = [
  'categories',
  'transactions',
  'recurring_rules',
  'income_schedules',
  'salary_deductions',
  'budgets',
  'settings',
  'loans',
  'loan_installments',
  'goals',
  'goal_contributions',
  'events',
];

/// Migra una base de datos Drift existente (v16) a una instancia de [PowerSyncDatabase].
///
/// 1. Copia el archivo original a `<oldDbPath>.pre-sync.bak`.
/// 2. Lee las tablas sincronizadas de la spec e inserta sus filas dentro de una
///    transacción de PowerSync, adaptando los ids según la spec:
///    - `loan_installments`: `id = '<loanId>:<number>'`
///    - `settings`: `id = key`
/// 3. Retorna un [MigrationReport] con el conteo de filas y la suma de `amount`
///    (para tablas donde dicha columna exista).
Future<MigrationReport> migrateFromDrift(
  String oldDbPath,
  PowerSyncDatabase target,
) async {
  // 1. Copia de seguridad previa
  final originalFile = File(oldDbPath);
  if (!originalFile.existsSync()) {
    throw ArgumentError('No existe la base de datos origen en: $oldDbPath');
  }
  final backupFile = File('$oldDbPath.pre-sync.bak');
  await originalFile.copy(backupFile.path);

  // 2. Abrir la base origen en solo lectura
  final oldDb = sqlite.sqlite3.open(oldDbPath, mode: sqlite.OpenMode.readOnly);

  final rowsByTable = <String, int>{};
  final amountSumByTable = <String, int>{};

  try {
    // 3. Copiar datos dentro de una transacción de PowerSync
    await target.writeTransaction((tx) async {
      for (final table in synchronizedTables) {
        // Verificar si la tabla existe en el origen
        final tableExists = oldDb.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$table'",
        );
        if (tableExists.isEmpty) {
          rowsByTable[table] = 0;
          continue;
        }

        // Columnas de la tabla origen
        final originPragma = oldDb.select('PRAGMA table_info("$table")');
        final originColumns =
            originPragma.map((r) => r['name'] as String).toList();
        final hasAmount = originColumns.contains('amount');

        // Leer todas las filas
        final rows = oldDb.select('SELECT * FROM "$table"');
        rowsByTable[table] = rows.length;

        if (hasAmount) {
          final sumRes = oldDb.select(
            'SELECT COALESCE(SUM(amount), 0) as s FROM "$table"',
          );
          amountSumByTable[table] = sumRes.first['s'] as int;
        }

        if (rows.isEmpty) continue;

        // Columnas válidas en el destino PowerSync
        final targetColsRaw =
            await tx.getAll('PRAGMA table_info("$table")');
        final targetColumns =
            targetColsRaw.map((r) => r['name'] as String).toSet();

        for (final row in rows) {
          final Map<String, dynamic> rowData = {};
          for (final col in originColumns) {
            rowData[col] = row[col];
          }

          // Ajustes especiales de primary key de PowerSync
          if (table == 'loan_installments') {
            final loanId = rowData['loan_id'];
            final number = rowData['number'];
            rowData['id'] = '$loanId:$number';
          } else if (table == 'settings') {
            rowData['id'] = rowData['key'];
          }

          // Filtrar a las columnas aceptadas por el destino
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
    });
  } finally {
    oldDb.close();
  }

  return MigrationReport(
    rowsByTable: rowsByTable,
    amountSumByTable: amountSumByTable,
  );
}
