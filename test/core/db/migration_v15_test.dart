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
    tempDir = await Directory.systemTemp.createTemp('pockt_mig_v15_');
    dbFile = File('${tempDir.path}/pockt_v14.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void createV14Database(File file) {
    final rawDb = sqlite.sqlite3.open(file.path);
    rawDb.execute('''
      PRAGMA user_version = 14;

      CREATE TABLE categories (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color_dark INTEGER NOT NULL,
        color_light INTEGER NOT NULL,
        kind TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE loans (
        id TEXT NOT NULL PRIMARY KEY,
        direction TEXT NOT NULL,
        kind TEXT NOT NULL,
        name TEXT NOT NULL,
        counterparty TEXT,
        total_amount INTEGER NOT NULL,
        installment_amount INTEGER,
        installments_total INTEGER,
        due_day INTEGER,
        start_date INTEGER NOT NULL,
        closed_at INTEGER,
        reminder_days INTEGER NOT NULL DEFAULT 2,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE counterparty_rules (
        id TEXT NOT NULL PRIMARY KEY,
        name_key TEXT NOT NULL,
        direction TEXT NOT NULL,
        action TEXT NOT NULL,
        category_id TEXT REFERENCES categories(id),
        loan_id TEXT REFERENCES loans(id),
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      INSERT INTO loans (
        id, direction, kind, name, total_amount, installment_amount,
        installments_total, due_day, start_date, reminder_days, created_at, updated_at
      ) VALUES (
        'loan-1', 'owe', 'installments', 'Préstamo Auto', 12000000, 1000000,
        12, 10, 1700000000000, 2, 1700000000000, 1700000000000
      );
    ''');
    rawDb.close();
  }

  AppDatabase openDb() => AppDatabase.forTesting(
    DatabaseConnection(NativeDatabase(dbFile), closeStreamsSynchronously: true),
  );

  test('migración v14 -> v15 crea tabla loan_installments', () async {
    createV14Database(dbFile);
    final db = openDb();
    addTearDown(db.close);

    expect(db.schemaVersion, 15);

    // 1. Tabla loan_installments creada
    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='loan_installments';",
    ).get();
    expect(tables, isNotEmpty);

    // 2. Columnas existen
    final cols = await db.customSelect("PRAGMA table_info('loan_installments');").get();
    final colNames = cols.map((c) => c.read<String>('name')).toSet();
    expect(colNames, containsAll({'loan_id', 'number', 'due_date', 'amount'}));

    // 3. Préstamos previos siguen intactos
    final prevLoan = await (db.select(db.loans)..where((l) => l.id.equals('loan-1'))).getSingle();
    expect(prevLoan.name, 'Préstamo Auto');
  });
}
