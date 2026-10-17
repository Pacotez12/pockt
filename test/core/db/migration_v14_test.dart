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
    tempDir = await Directory.systemTemp.createTemp('pockt_mig_v14_');
    dbFile = File('${tempDir.path}/pockt_v13.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void createV13Database(File file) {
    final rawDb = sqlite.sqlite3.open(file.path);
    rawDb.execute('''
      PRAGMA user_version = 13;

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

      CREATE TABLE events (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        start_date INTEGER NOT NULL,
        end_date INTEGER,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      );

      CREATE TABLE transactions (
        id TEXT NOT NULL PRIMARY KEY,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        currency TEXT NOT NULL DEFAULT 'PYG',
        category_id TEXT NOT NULL REFERENCES categories(id),
        merchant TEXT,
        note TEXT,
        occurred_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        source TEXT NOT NULL,
        recurring_rule_id TEXT,
        suggestion_id TEXT,
        deleted_at INTEGER,
        loan_id TEXT REFERENCES loans(id),
        is_extra INTEGER NOT NULL DEFAULT 0,
        event_id TEXT REFERENCES events(id)
      );

      CREATE TABLE suggested_transactions (
        id TEXT NOT NULL PRIMARY KEY,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        currency TEXT NOT NULL DEFAULT 'PYG',
        category_id TEXT REFERENCES categories(id),
        merchant TEXT,
        occurred_at INTEGER NOT NULL,
        source TEXT NOT NULL,
        source_ref TEXT,
        status TEXT NOT NULL,
        transaction_id TEXT REFERENCES transactions(id),
        raw_text TEXT,
        fingerprint TEXT,
        created_at INTEGER NOT NULL
      );

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order, archived)
      VALUES ('cat-1', 'Comida', 'fork-knife', 14983271, 10114309, 'expense', 0, 0);

      INSERT INTO suggested_transactions (id, type, amount, category_id, merchant, occurred_at, source, status, created_at)
      VALUES ('sug-1', 'expense', 50000, 'cat-1', 'Supermercado', 1700000000000, 'capture', 'pending', 1700000000000);
    ''');
    rawDb.close();
  }

  AppDatabase openDb() => AppDatabase.forTesting(
    DatabaseConnection(NativeDatabase(dbFile), closeStreamsSynchronously: true),
  );

  test('migración v13 -> v14 crea counterparty_rules y agrega suggested_transactions.capture_meta', () async {
    createV13Database(dbFile);
    final db = openDb();
    addTearDown(db.close);

    expect(db.schemaVersion, greaterThanOrEqualTo(14));

    // 1. Tabla counterparty_rules creada y funcional
    final rules = await db.customSelect("SELECT name FROM sqlite_master WHERE type='table' AND name='counterparty_rules';").get();
    expect(rules, isNotEmpty);

    // 2. Columna capture_meta existe en suggested_transactions
    final cols = await db.customSelect("SELECT name FROM pragma_table_info('suggested_transactions') WHERE name = 'capture_meta';").get();
    expect(cols, isNotEmpty);

    // 3. Datos previos siguen intactos
    final prevSug = await (db.select(db.suggestedTransactions)..where((t) => t.id.equals('sug-1'))).getSingle();
    expect(prevSug.amount, 50000);
    expect(prevSug.captureMeta, isNull);
  });
}
