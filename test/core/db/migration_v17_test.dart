import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tempDir = await Directory.systemTemp.createTemp('pockt_mig_v17_');
    dbFile = File('${tempDir.path}/pockt_v16.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void prepareV16DemoDatabase(File file) {
    final fixture = File('test/fixtures/pockt_v16_demo.db');
    if (!fixture.existsSync()) {
      // Si corre desde otra ruta de trabajo
      final fallback = File('spike/powersync_drift/test/fixtures/pockt_v16_demo.db');
      fallback.copySync(file.path);
    } else {
      fixture.copySync(file.path);
    }

    // Insertar registros en day_marks y settings para asegurar que todas las 4 tablas
    // tengan filas antes de la migración.
    final rawDb = sqlite.sqlite3.open(file.path);
    rawDb.execute('''
      INSERT INTO day_marks (date, no_spend) VALUES ('2026-10-28', 1), ('2026-10-29', 0);
      INSERT OR REPLACE INTO settings (key, value) VALUES ('appearance', 'dark');
    ''');
    rawDb.close();
  }

  AppDatabase openDb() => AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase(dbFile), closeStreamsSynchronously: true),
      );

  test('migración v16 -> v17 agrega columna id (PK) a LoanInstallments, Settings, DayMarks y MerchantMemory con valores derivados y conserva conteos',
      () async {
    prepareV16DemoDatabase(dbFile);

    // Contar filas antes de la migración usando SQLite3 directo
    final preDb = sqlite.sqlite3.open(dbFile.path);
    expect(preDb.userVersion, 16);

    final preCountInstallments = preDb.select('SELECT count(*) as c FROM loan_installments').first['c'] as int;
    final preCountSettings = preDb.select('SELECT count(*) as c FROM settings').first['c'] as int;
    final preCountDayMarks = preDb.select('SELECT count(*) as c FROM day_marks').first['c'] as int;
    final preCountMerchantMem = preDb.select('SELECT count(*) as c FROM merchant_memory').first['c'] as int;
    final preCountTransactions = preDb.select('SELECT count(*) as c FROM transactions').first['c'] as int;

    expect(preCountInstallments, greaterThan(0));
    expect(preCountSettings, greaterThan(0));
    expect(preCountDayMarks, greaterThan(0));
    expect(preCountMerchantMem, greaterThan(0));
    preDb.close();

    // Abrir AppDatabase -> ejecuta onUpgrade si schemaVersion es 17
    final db = openDb();
    addTearDown(db.close);

    expect(db.schemaVersion, 17);

    // 1. Validar conteos iguales antes y después
    final postInstallments = await db.customSelect('SELECT * FROM loan_installments;').get();
    expect(postInstallments.length, preCountInstallments);

    final postSettings = await db.customSelect('SELECT * FROM settings;').get();
    expect(postSettings.length, preCountSettings);

    final postDayMarks = await db.customSelect('SELECT * FROM day_marks;').get();
    expect(postDayMarks.length, preCountDayMarks);

    final postMerchantMem = await db.customSelect('SELECT * FROM merchant_memory;').get();
    expect(postMerchantMem.length, preCountMerchantMem);

    final postTransactions = await db.customSelect('SELECT count(*) as c FROM transactions;').get();
    expect(postTransactions.first.read<int>('c'), preCountTransactions);

    // 2. Validar estructura de columnas y que id exista en las 4 tablas
    for (final table in ['loan_installments', 'settings', 'day_marks', 'merchant_memory']) {
      final pragma = await db.customSelect("PRAGMA table_info('$table');").get();
      final idCol = pragma.firstWhere(
        (c) => c.read<String>('name') == 'id',
        orElse: () => throw StateError('Tabla $table no tiene columna id'),
      );
      // id debe ser clave primaria (pk > 0)
      expect(idCol.read<int>('pk'), greaterThan(0), reason: '$table.id debe ser clave primaria');
    }

    // 3. Validar valores derivados del id
    // LoanInstallments: id = '<loanId>:<number>'
    for (final row in postInstallments) {
      final id = row.read<String>('id');
      final loanId = row.read<String>('loan_id');
      final number = row.read<int>('number');
      expect(id, '$loanId:$number');
    }

    // Settings: id = key
    for (final row in postSettings) {
      final id = row.read<String>('id');
      final key = row.read<String>('key');
      expect(id, key);
    }

    // DayMarks: id = date
    for (final row in postDayMarks) {
      final id = row.read<String>('id');
      final date = row.read<String>('date');
      expect(id, date);
    }

    // MerchantMemory: id = '<merchantKey>|<categoryId>'
    for (final row in postMerchantMem) {
      final id = row.read<String>('id');
      final merchantKey = row.read<String>('merchant_key');
      final categoryId = row.read<String>('category_id');
      expect(id, '$merchantKey|$categoryId');
    }
  });
}
