import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pockt_mig_v3_');
    dbFile = File('${tempDir.path}/pockt_v2.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void createV2DatabaseWithData(File file) {
    final rawDb = sqlite.sqlite3.open(file.path);

    rawDb.execute('''
      PRAGMA user_version = 2;

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
        alert80_sent_for TEXT,
        alert100_sent_for TEXT
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
        merchant_key TEXT NOT NULL,
        category_id TEXT NOT NULL REFERENCES categories(id),
        uses INTEGER NOT NULL,
        last_used_at INTEGER NOT NULL,
        PRIMARY KEY (merchant_key, category_id)
      );
    ''');

    // Categorías en v2
    rawDb.execute('''
      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order) VALUES
      ('018f0000-0000-7000-8000-000000000001', 'Comida', 'fork-knife', 4294942531, 4292441882, 'expense', 0),
      ('018f0000-0000-7000-8000-000000000002', 'Transporte', 'car-profile', 4283736319, 4280249809, 'expense', 1),
      ('018f0000-0000-7000-8000-000000000003', 'Hogar', 'house-line', 4280144289, 4279146099, 'expense', 2);
    ''');

    // Movimientos reales en v2
    const t1 = 1728000000;
    const t2 = 1728100000;
    rawDb.execute('''
      INSERT INTO transactions (id, type, amount, category_id, merchant, note, occurred_at, created_at, updated_at, source) VALUES
      ('tx-1', 'expense', 380000, '018f0000-0000-7000-8000-000000000003', 'Superseis', 'compras mes', $t1, $t1, $t1, 'manual'),
      ('tx-2', 'expense', 28500, '018f0000-0000-7000-8000-000000000002', 'Bolt', NULL, $t2, $t2, $t2, 'manual');
    ''');

    // Palabras clave y memoria de comercios en v2
    rawDb.execute('''
      INSERT INTO category_keywords (id, category_id, keyword, source) VALUES
      ('kw-1', '018f0000-0000-7000-8000-000000000001', 'pizza', 'seed'),
      ('kw-2', '018f0000-0000-7000-8000-000000000002', 'uber', 'user');

      INSERT INTO merchant_memory (merchant_key, category_id, uses, last_used_at) VALUES
      ('superseis', '018f0000-0000-7000-8000-000000000003', 5, $t1),
      ('bolt', '018f0000-0000-7000-8000-000000000002', 2, $t2);
    ''');

    // Sugerencia existente en v2
    rawDb.execute('''
      INSERT INTO suggested_transactions (id, type, amount, category_id, occurred_at, source, source_ref, status, created_at) VALUES
      ('sug-1', 'expense', 50000, '018f0000-0000-7000-8000-000000000001', $t1, 'recurring', 'rec-1', 'pending', $t1);
    ''');

    rawDb.close();
  }

  test('migración v2 -> v3 preserva datos y crea índice único en suggested_transactions(source, sourceRef, occurredAt)', () async {
    createV2DatabaseWithData(dbFile);

    // Abrir con AppDatabase actualizada (schemaVersion 3)
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));

    try {
      expect(db.schemaVersion, 3);

      // 1. Movimientos intactos
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(2));
      expect(txs.any((t) => t.id == 'tx-1' && t.amount == 380000 && t.merchant == 'Superseis'), isTrue);
      expect(txs.any((t) => t.id == 'tx-2' && t.amount == 28500 && t.merchant == 'Bolt'), isTrue);

      // 2. Palabras clave intactas
      final keywords = await db.select(db.categoryKeywords).get();
      expect(keywords, hasLength(2));
      expect(keywords.any((k) => k.keyword == 'pizza' && k.source == KeywordSource.seed), isTrue);
      expect(keywords.any((k) => k.keyword == 'uber' && k.source == KeywordSource.user), isTrue);

      // 3. Memoria de comercios intacta
      final memories = await db.select(db.merchantMemory).get();
      expect(memories, hasLength(2));
      expect(memories.any((m) => m.merchantKey == 'superseis' && m.uses == 5), isTrue);

      // 4. Sugerencia previa intacta
      final sugs = await db.select(db.suggestedTransactions).get();
      expect(sugs, hasLength(1));
      expect(sugs.first.id, 'sug-1');

      // 5. El índice único rechaza duplicados con el mismo (source, sourceRef, occurredAt)
      expect(
        () async {
          final rawDb = sqlite.sqlite3.open(dbFile.path);
          try {
            rawDb.execute('''
              INSERT INTO suggested_transactions (id, type, amount, category_id, occurred_at, source, source_ref, status, created_at) VALUES
              ('sug-2', 'expense', 75000, '018f0000-0000-7000-8000-000000000001', 1728000000, 'recurring', 'rec-1', 'pending', 1728000000);
            ''');
          } finally {
            rawDb.close();
          }
        },
        throwsA(isA<sqlite.SqliteException>()),
      );
    } finally {
      await db.close();
    }
  });
}
