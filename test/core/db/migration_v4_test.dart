import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pockt_mig_v4_');
    dbFile = File('${tempDir.path}/pockt_v3.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void createV3DatabaseWithData(File file) {
    final rawDb = sqlite.sqlite3.open(file.path);

    rawDb.execute('''
      PRAGMA user_version = 3;

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
        shift_to_previous_business_day INTEGER NOT NULL,
        expected_amount INTEGER,
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
        no_spend INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE settings (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL
      );

      CREATE TABLE category_keywords (
        id TEXT NOT NULL PRIMARY KEY,
        category_id TEXT NOT NULL REFERENCES categories(id),
        keyword TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'user'
      );

      CREATE TABLE merchant_memory (
        merchant_key TEXT NOT NULL,
        category_id TEXT NOT NULL REFERENCES categories(id),
        uses INTEGER NOT NULL DEFAULT 1,
        last_used_at INTEGER NOT NULL,
        PRIMARY KEY (merchant_key, category_id)
      );
    ''');

    // Datos v3 preexistentes del usuario
    rawDb.execute('''
      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('cat-comida', 'Comida', 'fork-knife', 1, 2, 'expense', 0),
             ('cat-sueldo', 'Sueldo', 'briefcase', 3, 4, 'income', 0);

      INSERT INTO transactions (id, type, amount, currency, category_id, merchant, occurred_at, created_at, updated_at, source)
      VALUES ('tx-1', 'expense', 15000, 'PYG', 'cat-comida', 'Superseis', 1728000000000, 1728000000000, 1728000000000, 'manual');

      INSERT INTO income_schedules (id, mode, pay_days, shift_to_previous_business_day, expected_amount, category_id, effective_from)
      VALUES ('sched-1', 'biweekly', '[15, -1]', 1, 3500000, 'cat-sueldo', 1727740800000),
             ('sched-2', 'monthly', '[-1]', 1, 4000000, 'cat-sueldo', 1725148800000);

      INSERT INTO budgets (id, category_id, monthly_limit)
      VALUES ('b-1', 'cat-comida', 1500000);

      INSERT INTO recurring_rules (id, name, type, amount, category_id, frequency, next_due_date, active)
      VALUES ('r-1', 'Netflix', 'expense', 85000, 'cat-comida', 'monthly', 1728345600000, 1);
    ''');

    rawDb.close();
  }

  test('migración v3 a v4 conserva datos y convierte payDayRules', () async {
    createV3DatabaseWithData(dbFile);

    final db = AppDatabase.forTesting(
      NativeDatabase(dbFile),
    );

    // 1. Schema version actualizado a 6
    expect(db.schemaVersion, equals(6));

    // 2. Datos existentes intactos
    final txs = await db.select(db.transactions).get();
    expect(txs.length, equals(1));
    expect(txs.first.merchant, equals('Superseis'));

    final budgets = await db.select(db.budgets).get();
    expect(budgets.length, equals(1));
    expect(budgets.first.monthlyLimit, equals(1500000));

    final rules = await db.select(db.recurringRules).get();
    expect(rules.length, equals(1));
    expect(rules.first.name, equals('Netflix'));

    // 3. Esquemas de cobro migrados con payDayRules (-1 -> previous, cualquier otro -> either)
    final schedules = await db.select(db.incomeSchedules).get();
    expect(schedules.length, equals(2));

    final sched1 = schedules.firstWhere((s) => s.id == 'sched-1');
    expect(sched1.payDays, equals('[15, -1]'));
    expect(sched1.payDayRules, equals('["either","previous"]'));
    expect(sched1.monthlyAmount, equals(7000000));
    expect(sched1.paySplitPercents, equals('[50,50]'));

    final sched2 = schedules.firstWhere((s) => s.id == 'sched-2');
    expect(sched2.payDays, equals('[-1]'));
    expect(sched2.payDayRules, equals('["previous"]'));
    expect(sched2.monthlyAmount, equals(4000000));
    expect(sched2.paySplitPercents, equals('[100]'));

    await db.close();

    // 4. Verificar a nivel de SQLite raw que la columna shift_to_previous_business_day no existe
    final rawDb = sqlite.sqlite3.open(dbFile.path);
    final userVersionResult = rawDb.select('PRAGMA user_version;');
    expect(userVersionResult.first['user_version'], equals(6));

    final tableInfo = rawDb.select('PRAGMA table_info(income_schedules);');
    final columnNames = tableInfo.map((row) => row['name'] as String).toList();
    expect(columnNames, contains('pay_day_rules'));
    expect(columnNames, contains('monthly_amount'));
    expect(columnNames, contains('pay_split_percents'));
    expect(columnNames, isNot(contains('shift_to_previous_business_day')));

    rawDb.close();
  });
}
