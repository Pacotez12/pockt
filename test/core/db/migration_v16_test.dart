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
    tempDir = await Directory.systemTemp.createTemp('pockt_mig_v16_');
    dbFile = File('${tempDir.path}/pockt_v15.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void createV15Database(File file) {
    final rawDb = sqlite.sqlite3.open(file.path);
    rawDb.execute('''
      PRAGMA user_version = 15;

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

      CREATE TABLE loan_installments (
        loan_id TEXT NOT NULL REFERENCES loans(id),
        number INTEGER NOT NULL,
        due_date INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        PRIMARY KEY (loan_id, number)
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

  test('migración v15 -> v16 agrega columna paid_before_count a loans con default 0', () async {
    createV15Database(dbFile);
    final db = openDb();
    addTearDown(db.close);

    expect(db.schemaVersion, greaterThanOrEqualTo(16));

    // 1. Columna paid_before_count existe en loans
    final cols = await db.customSelect("PRAGMA table_info('loans');").get();
    final colNames = cols.map((c) => c.read<String>('name')).toSet();
    expect(colNames, contains('paid_before_count'));

    // 2. Préstamos previos tienen paid_before_count = 0
    final prevLoan = await (db.select(db.loans)..where((l) => l.id.equals('loan-1'))).getSingle();
    expect(prevLoan.paidBeforeCount, 0);
  });
}
