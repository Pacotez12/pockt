import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pockt_mig_v6_');
    dbFile = File('${tempDir.path}/pockt_v5.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void createV5DatabaseWithData(File file) {
    final rawDb = sqlite.sqlite3.open(file.path);

    rawDb.execute('''
      PRAGMA user_version = 5;

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

      -- Seed data
      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('cat-comida', 'Comida', 'fork-knife', 0, 0, 'expense', 1);

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('cat-sueldo', 'Sueldo', 'money', 0, 0, 'income', 2);

      INSERT INTO transactions (id, type, amount, category_id, occurred_at, created_at, updated_at, source, merchant)
      VALUES ('tx-1', 'expense', 45000, 'cat-comida', 1728432000000, 1728432000000, 1728432000000, 'manual', 'Superseis');

      INSERT INTO income_schedules (id, mode, pay_days, pay_day_rules, monthly_amount, pay_split_percents, category_id, effective_from)
      VALUES ('sched-1', 'biweekly', '[15, -1]', '["either","previous"]', 4000000, '[30,70]', 'cat-sueldo', 1728000000000);
    ''');

    rawDb.close();
  }

  test('migración v5 a v6 crea tabla salary_deductions y conserva el esquema existente', () async {
    createV5DatabaseWithData(dbFile);

    final db = AppDatabase.forTesting(
      NativeDatabase(dbFile),
    );

    // 1. Schema version actualizado a 6
    expect(db.schemaVersion, equals(6));

    // 2. Datos existentes intactos
    final txs = await db.select(db.transactions).get();
    expect(txs.length, equals(1));
    expect(txs.first.merchant, equals('Superseis'));

    final schedules = await db.select(db.incomeSchedules).get();
    expect(schedules.length, equals(1));
    final sched = schedules.first;
    expect(sched.id, equals('sched-1'));
    expect(sched.monthlyAmount, equals(4000000));
    expect(sched.paySplitPercents, equals('[30,70]'));

    // 3. Tabla salary_deductions utilizable a través de drift
    await db.into(db.salaryDeductions).insert(
          SalaryDeductionsCompanion.insert(
            id: 'ded-1',
            scheduleId: 'sched-1',
            name: 'IPS',
            kind: 'percent',
            value: 900,
          ),
        );

    final deductions = await db.select(db.salaryDeductions).get();
    expect(deductions.length, equals(1));
    expect(deductions.first.name, equals('IPS'));
    expect(deductions.first.kind, equals('percent'));
    expect(deductions.first.value, equals(900));

    await db.close();

    // 4. Verificar PRAGMA en SQLite raw
    final rawDb = sqlite.sqlite3.open(dbFile.path);
    final userVersionResult = rawDb.select('PRAGMA user_version;');
    expect(userVersionResult.first['user_version'], equals(6));

    final tableInfo = rawDb.select('PRAGMA table_info(salary_deductions);');
    final columnNames = tableInfo.map((row) => row['name'] as String).toList();
    expect(columnNames, contains('id'));
    expect(columnNames, contains('schedule_id'));
    expect(columnNames, contains('name'));
    expect(columnNames, contains('kind'));
    expect(columnNames, contains('value'));

    rawDb.close();
  });
}
