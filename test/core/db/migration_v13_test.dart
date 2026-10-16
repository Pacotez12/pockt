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
    tempDir = await Directory.systemTemp.createTemp('pockt_mig_v13_');
    dbFile = File('${tempDir.path}/pockt_v12.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Base v12 con datos reales antes de migrar a v13:
  /// - Sin categoría "Tarjetas"
  /// - Movimiento con type = 'transfer'
  /// - Sugerencia con type = 'transfer'
  void createV12Database(File file) {
    final rawDb = sqlite.sqlite3.open(file.path);
    rawDb.execute('''
      PRAGMA user_version = 12;

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

      CREATE TABLE category_keywords (
        id TEXT NOT NULL PRIMARY KEY,
        category_id TEXT NOT NULL REFERENCES categories(id),
        keyword TEXT NOT NULL,
        source TEXT NOT NULL,
        created_at INTEGER
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

      CREATE TABLE entry_shortcuts (
        id TEXT NOT NULL PRIMARY KEY,
        merchant TEXT,
        note TEXT,
        amount INTEGER NOT NULL,
        category_id TEXT NOT NULL REFERENCES categories(id),
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_dismissed INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
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

      CREATE TABLE merchant_memory (
        merchant_key TEXT NOT NULL,
        category_id TEXT NOT NULL REFERENCES categories(id),
        uses INTEGER NOT NULL,
        last_used_at INTEGER NOT NULL,
        auto_confirm INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (merchant_key, category_id)
      );

      CREATE TABLE settings (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL
      );

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order, archived)
      VALUES ('cat-1', 'Comida', 'fork-knife', 14983271, 10114309, 'expense', 0, 0);

      INSERT INTO transactions (id, type, amount, category_id, merchant, occurred_at, created_at, updated_at, source)
      VALUES ('tx-transfer', 'transfer', 1500000, 'cat-1', 'Bancop Pago de tarjeta', 1700000000000, 1700000000000, 1700000000000, 'capture');

      INSERT INTO transactions (id, type, amount, category_id, merchant, occurred_at, created_at, updated_at, source)
      VALUES ('tx-expense', 'expense', 50000, 'cat-1', 'Superseis', 1700000000000, 1700000000000, 1700000000000, 'manual');

      INSERT INTO suggested_transactions (id, type, amount, category_id, merchant, occurred_at, source, status, created_at)
      VALUES ('sug-transfer', 'transfer', 850000, 'cat-1', 'FINANCIERA FIC Pago de tarjeta con', 1700000000000, 'capture', 'pending', 1700000000000);
    ''');
    rawDb.close();
  }

  AppDatabase openDb() => AppDatabase.forTesting(
    DatabaseConnection(NativeDatabase(dbFile), closeStreamsSynchronously: true),
  );

  test('migración v12 -> v13 crea categoría Tarjetas con keywords y convierte transferencias a gastos en Tarjetas', () async {
    createV12Database(dbFile);
    final db = openDb();
    addTearDown(db.close);

    expect(db.schemaVersion, greaterThanOrEqualTo(13));

    // 1. Categoría Tarjetas creada
    final tarjetas = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Tarjetas'))).getSingle();
    expect(tarjetas.kind, CategoryKind.expense);
    expect(tarjetas.icon, 'credit-card');

    // 2. Keywords sembradas para Tarjetas
    final keywords = await (db.select(
      db.categoryKeywords,
    )..where((k) => k.categoryId.equals(tarjetas.id))).get();
    expect(keywords, isNotEmpty);
    final kwList = keywords.map((k) => k.keyword).toList();
    expect(kwList, contains('tarjeta'));
    expect(kwList, contains('pago de tarjeta'));

    // 3. El movimiento que era transfer pasó a expense con categoryId = Tarjetas
    final txTransfer = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals('tx-transfer'))).getSingle();
    expect(txTransfer.type, TxType.expense);
    expect(txTransfer.categoryId, tarjetas.id);
    expect(txTransfer.amount, 1500000);

    // 4. El movimiento normal de expense quedó intacto
    final txExpense = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals('tx-expense'))).getSingle();
    expect(txExpense.type, TxType.expense);
    expect(txExpense.categoryId, 'cat-1');
    expect(txExpense.amount, 50000);

    // 5. La sugerencia que era transfer pasó a expense con categoryId = Tarjetas
    final sugTransfer = await (db.select(
      db.suggestedTransactions,
    )..where((s) => s.id.equals('sug-transfer'))).getSingle();
    expect(sugTransfer.type, TxType.expense);
    expect(sugTransfer.categoryId, tarjetas.id);
    expect(sugTransfer.amount, 850000);
  });

  test('una base nueva nace con la categoría de fábrica Tarjetas y sus palabras clave', () async {
    final db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);

    final cat = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Tarjetas'))).getSingle();
    expect(cat.kind, CategoryKind.expense);
    expect(cat.icon, 'credit-card');
    expect(cat.sortOrder, 11);

    final kw = await (db.select(
      db.categoryKeywords,
    )..where((k) => k.categoryId.equals(cat.id))).get();
    expect(kw, isNotEmpty);
    final kwList = kw.map((k) => k.keyword).toList();
    expect(kwList, contains('tarjeta'));
    expect(kwList, contains('pago de tarjeta'));
  });

  test('wipeAllData restaura la categoría de fábrica Tarjetas y sus palabras clave', () async {
    final db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);

    await db.wipeAllData();

    final cat = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Tarjetas'))).getSingle();
    expect(cat.kind, CategoryKind.expense);
    expect(cat.icon, 'credit-card');

    final kw = await (db.select(
      db.categoryKeywords,
    )..where((k) => k.categoryId.equals(cat.id))).get();
    expect(kw, isNotEmpty);
  });
}
