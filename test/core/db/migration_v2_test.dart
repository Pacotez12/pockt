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
    tempDir = await Directory.systemTemp.createTemp('pockt_mig_v2_');
    dbFile = File('${tempDir.path}/pockt_v1.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void createV1DatabaseWithData(File file) {
    final rawDb = sqlite.sqlite3.open(file.path);

    rawDb.execute('''
      PRAGMA user_version = 1;

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
    ''');

    // Insertar categorías iniciales de v1
    rawDb.execute('''
      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order) VALUES
      ('018f0000-0000-7000-8000-000000000001', 'Comida', 'fork-knife', 4294942531, 4292441882, 'expense', 0),
      ('018f0000-0000-7000-8000-000000000002', 'Transporte', 'car-profile', 4283736319, 4280249809, 'expense', 1),
      ('018f0000-0000-7000-8000-000000000003', 'Hogar', 'house-line', 4280144289, 4279146099, 'expense', 2),
      ('018f0000-0000-7000-8000-000000000004', 'Salud', 'heartbeat', 4294937451, 4292232517, 'expense', 3);
    ''');

    // Insertar movimientos reales en v1 (dos en Superseis con fechas distintas, uno en Bolt)
    // Drift almacena DateTime como timestamp unix en segundos
    const t1 = 1728000000; // más antiguo
    const t2 = 1728100000; // más reciente
    const t3 = 1728050000;

    rawDb.execute('''
      INSERT INTO transactions (id, type, amount, category_id, merchant, note, occurred_at, created_at, updated_at, source) VALUES
      ('tx-1', 'expense', 380000, '018f0000-0000-7000-8000-000000000003', 'Superseis', 'compras mes', $t1, $t1, $t1, 'manual'),
      ('tx-2', 'expense', 120000, '018f0000-0000-7000-8000-000000000003', 'Superseis', 'almacén', $t2, $t2, $t2, 'manual'),
      ('tx-3', 'expense', 28500, '018f0000-0000-7000-8000-000000000002', 'Bolt', NULL, $t3, $t3, $t3, 'manual');
    ''');

    rawDb.close();
  }

  test('migración v1 -> v2 preserva movimientos y pre-carga CategoryKeywords y MerchantMemory', () async {
    createV1DatabaseWithData(dbFile);

    // Abrir con AppDatabase (schemaVersion 2)
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));

    try {
      // 1. Verificar que los movimientos existentes siguen intactos
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(3));
      final tx1 = txs.firstWhere((t) => t.id == 'tx-1');
      expect(tx1.amount, 380000);
      expect(tx1.merchant, 'Superseis');
      expect(tx1.note, 'compras mes');
      expect(tx1.categoryId, '018f0000-0000-7000-8000-000000000003');

      final tx3 = txs.firstWhere((t) => t.id == 'tx-3');
      expect(tx3.amount, 28500);
      expect(tx3.merchant, 'Bolt');
      expect(tx3.categoryId, '018f0000-0000-7000-8000-000000000002');

      // 2. Verificar que CategoryKeywords tiene las palabras del seed vinculadas por id
      final keywords = await db.select(db.categoryKeywords).get();
      expect(keywords, isNotEmpty);

      // 'pizza' debe apuntar al id de Comida
      final pizza = keywords.firstWhere((k) => k.keyword == 'pizza');
      expect(pizza.categoryId, '018f0000-0000-7000-8000-000000000001');
      expect(pizza.source, KeywordSource.seed);

      // 'bolt' debe apuntar al id de Transporte
      final bolt = keywords.firstWhere((k) => k.keyword == 'bolt');
      expect(bolt.categoryId, '018f0000-0000-7000-8000-000000000002');

      // 'superseis' debe apuntar al id de Hogar
      final superseis = keywords.firstWhere((k) => k.keyword == 'superseis');
      expect(superseis.categoryId, '018f0000-0000-7000-8000-000000000003');

      // 3. Verificar que MerchantMemory fue pre-cargado con los comercios existentes
      final memories = await db.select(db.merchantMemory).get();
      expect(memories, hasLength(2)); // 'superseis' y 'bolt'

      // 'superseis' con 2 usos en Hogar y lastUsedAt = t2 (el más reciente)
      final superseisMem = memories.firstWhere((m) => m.merchantKey == 'superseis');
      expect(superseisMem.categoryId, '018f0000-0000-7000-8000-000000000003');
      expect(superseisMem.uses, 2);
      expect(superseisMem.lastUsedAt.millisecondsSinceEpoch ~/ 1000, 1728100000);

      // 'bolt' con 1 uso en Transporte
      final boltMem = memories.firstWhere((m) => m.merchantKey == 'bolt');
      expect(boltMem.categoryId, '018f0000-0000-7000-8000-000000000002');
      expect(boltMem.uses, 1);
    } finally {
      await db.close();
    }
  });
}
