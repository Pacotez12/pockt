import 'dart:io';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tempDir = await Directory.systemTemp.createTemp('pockt_mig_v8_');
    dbFile = File('${tempDir.path}/pockt_v7.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void createV7DatabaseWithData(File file) {
    final rawDb = sqlite.sqlite3.open(file.path);

    rawDb.execute('''
      PRAGMA user_version = 7;

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
        deleted_at INTEGER
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

      CREATE UNIQUE INDEX idx_suggested_transactions_source_source_ref_occurred_at
      ON suggested_transactions (source, source_ref, occurred_at);

      CREATE TABLE recurring_rules (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category_id TEXT NOT NULL REFERENCES categories(id),
        frequency TEXT NOT NULL,
        day_of_month INTEGER,
        day_of_week INTEGER,
        month_of_year INTEGER,
        next_due_date INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      );

      CREATE TABLE income_schedules (
        id TEXT NOT NULL PRIMARY KEY,
        mode TEXT NOT NULL,
        pay_days TEXT NOT NULL,
        pay_day_rules TEXT NOT NULL,
        monthly_amount INTEGER,
        pay_split_percents TEXT NOT NULL,
        category_id TEXT NOT NULL REFERENCES categories(id),
        effective_from INTEGER NOT NULL
      );

      CREATE TABLE budgets (
        id TEXT NOT NULL PRIMARY KEY,
        category_id TEXT NOT NULL REFERENCES categories(id),
        monthly_limit INTEGER NOT NULL,
        alert_80_sent_for TEXT,
        alert_100_sent_for TEXT
      );

      CREATE TABLE day_marks (
        date TEXT NOT NULL PRIMARY KEY,
        no_spend INTEGER NOT NULL
      );

      CREATE TABLE settings (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL
      );

      CREATE TABLE category_keywords (
        id TEXT NOT NULL PRIMARY KEY,
        category_id TEXT NOT NULL REFERENCES categories(id),
        keyword TEXT NOT NULL,
        source TEXT NOT NULL,
        UNIQUE (category_id, keyword)
      );

      CREATE TABLE merchant_memory (
        raw_merchant TEXT NOT NULL PRIMARY KEY,
        clean_merchant TEXT NOT NULL,
        category_id TEXT NOT NULL REFERENCES categories(id),
        usage_count INTEGER NOT NULL DEFAULT 1,
        last_used_at INTEGER NOT NULL
      );

      CREATE TABLE salary_deductions (
        id TEXT NOT NULL PRIMARY KEY,
        schedule_id TEXT NOT NULL REFERENCES income_schedules(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        value INTEGER NOT NULL
      );
    ''');

    // Insert existing category and transaction
    rawDb.execute('''
      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order, archived)
      VALUES ('cat-1', 'Comida', 'fork-knife', 14983271, 10114309, 'expense', 0, 0);

      INSERT INTO transactions (id, type, amount, currency, category_id, occurred_at, created_at, updated_at, source)
      VALUES ('tx-1', 'expense', 50000, 'PYG', 'cat-1', 1700000000000, 1700000000000, 1700000000000, 'manual');
    ''');

    rawDb.close();
  }

  test('migración v7 -> v8 crea tabla loans, columna loan_id en transactions y categoría Préstamos', () async {
    createV7DatabaseWithData(dbFile);

    final db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase(dbFile), closeStreamsSynchronously: true),
    );

    expect(db.schemaVersion, equals(8));

    // Verify existing transaction and category are preserved
    final txs = await db.select(db.transactions).get();
    expect(txs.length, equals(1));
    expect(txs.first.id, equals('tx-1'));
    expect(txs.first.amount, equals(50000));
    expect(txs.first.loanId, isNull);

    // Verify table loans exists and is queryable
    final loans = await db.select(db.loans).get();
    expect(loans, isEmpty);

    // Verify category "Préstamos" exists
    final prestamosCat = await (db.select(db.categories)..where((c) => c.name.equals('Préstamos'))).getSingleOrNull();
    expect(prestamosCat, isNotNull);
    expect(prestamosCat!.name, equals('Préstamos'));
    expect(prestamosCat.kind, equals(CategoryKind.expense));

    await db.close();
  });
}
