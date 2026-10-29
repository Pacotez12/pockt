import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:powersync/powersync.dart' as ps;
import 'package:powersync_drift/migrate_from_drift.dart';
import 'package:powersync_drift/schema.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const testSynchronizedTables = [
  'transactions',
  'categories',
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
];

void main() {
  test(
      'migrateFromDrift migra base Drift v16 a PowerSync con reportes iguales, backup y loan_installments compuesto',
      () async {
    final tempDir = Directory.systemTemp.createTempSync('drift_migrate_test_');
    addTearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    // 1. Cargar fixture v16 generada a partir de seedDemoData de Pockt
    final fixtureTemplate = File('test/fixtures/pockt_v16_demo.db');
    expect(fixtureTemplate.existsSync(), isTrue,
        reason:
            'Fixture v16 demo debe existir en test/fixtures/pockt_v16_demo.db');

    final oldDbPath = p.join(tempDir.path, 'pockt_v16.db');
    fixtureTemplate.copySync(oldDbPath);

    // 2. Calcular métricas esperadas directamente desde la base origen (SQLite3)
    final originSqlite = sqlite.sqlite3.open(oldDbPath);
    final expectedRows = <String, int>{};
    final expectedAmountSums = <String, int>{};

    for (final table in testSynchronizedTables) {
      final countRes =
          originSqlite.select('SELECT count(*) as c FROM "$table"');
      final count = countRes.first['c'] as int;
      expectedRows[table] = count;

      final cols = originSqlite.select('PRAGMA table_info("$table")');
      final hasAmount = cols.any((col) => col['name'] == 'amount');
      if (hasAmount) {
        final sumRes = originSqlite.select(
          'SELECT COALESCE(SUM(amount), 0) as s FROM "$table"',
        );
        expectedAmountSums[table] = sumRes.first['s'] as int;
      }
    }
    originSqlite.close();

    // Comprobar que la fixture tiene datos inventados en las tablas clave
    expect(expectedRows['transactions'], greaterThan(0));
    expect(expectedRows['categories'], greaterThan(0));
    expect(expectedRows['loans'], greaterThan(0));
    expect(expectedRows['loan_installments'], greaterThan(0));
    expect(expectedRows['goals'], greaterThan(0));
    expect(expectedRows['budgets'], greaterThan(0));
    expect(expectedRows['recurring_rules'], greaterThan(0));
    expect(expectedRows['income_schedules'], greaterThan(0));
    expect(expectedRows['salary_deductions'], greaterThan(0));
    expect(expectedRows['events'], greaterThan(0));
    expect(expectedRows['settings'], greaterThan(0));
    expect(expectedAmountSums['transactions'], greaterThan(0));
    expect(expectedAmountSums['loan_installments'], greaterThan(0));

    final expectedReport = MigrationReport(
      rowsByTable: expectedRows,
      amountSumByTable: expectedAmountSums,
    );

    // 3. Destino PowerSync
    final targetDbPath = p.join(tempDir.path, 'powersync_target.db');
    final target = ps.PowerSyncDatabase(schema: schema, path: targetDbPath);
    await target.initialize();

    // 4. Ejecutar migración
    final resultReport = await migrateFromDrift(oldDbPath, target);

    // 5. Validaciones:
    // a) Existe copia de seguridad previa
    final backupFile = File('$oldDbPath.pre-sync.bak');
    expect(backupFile.existsSync(), isTrue);

    // b) El reporte retornado coincide con el origen
    expect(resultReport, equals(expectedReport));

    // c) En el destino PowerSync los conteos y sumas coinciden
    for (final table in testSynchronizedTables) {
      final targetCountRow =
          await target.get('SELECT count(*) as c FROM "$table"');
      expect(
        targetCountRow['c'],
        equals(expectedRows[table]),
        reason: 'Conteo de filas no coincide para tabla $table',
      );

      if (expectedAmountSums.containsKey(table)) {
        final targetSumRow = await target.get(
          'SELECT COALESCE(SUM(amount), 0) as s FROM "$table"',
        );
        expect(
          targetSumRow['s'],
          equals(expectedAmountSums[table]),
          reason: 'Suma de amount no coincide para tabla $table',
        );
      }
    }

    // d) loan_installments queda con id compuesto '<loanId>:<number>'
    final installments = await target.getAll(
      'SELECT id, loan_id, number FROM loan_installments',
    );
    expect(installments, isNotEmpty);
    for (final row in installments) {
      expect(row['id'], equals('${row['loan_id']}:${row['number']}'));
    }

    // e) settings queda con id = key
    final settingsRows = await target.getAll('SELECT id, key FROM settings');
    expect(settingsRows, isNotEmpty);
    for (final row in settingsRows) {
      expect(row['id'], equals(row['key']));
    }

    await target.close();
  });
}
