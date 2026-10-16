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
    tempDir = await Directory.systemTemp.createTemp('pockt_mig_v12_');
    dbFile = File('${tempDir.path}/pockt_v11.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Base v11 con datos reales antes de migrar a v12.
  void createV11Database(File file) {
    final rawDb = sqlite.sqlite3.open(file.path);
    rawDb.execute('''
      PRAGMA user_version = 11;

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
        PRIMARY KEY (merchant_key, category_id)
      );

      CREATE TABLE settings (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL
      );

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order, archived)
      VALUES ('cat-1', 'Comida', 'fork-knife', 14983271, 10114309, 'expense', 0, 0);

      INSERT INTO merchant_memory (merchant_key, category_id, uses, last_used_at)
      VALUES ('pizza hut', 'cat-1', 4, 1700000000000);

      INSERT INTO transactions (id, type, amount, category_id, merchant, occurred_at, created_at, updated_at, source)
      VALUES ('tx-1', 'expense', 34500, 'cat-1', 'Pizza Hut', 1700000000000, 1700000000000, 1700000000000, 'manual');

      INSERT INTO suggested_transactions (id, type, amount, category_id, merchant, occurred_at, source, status, created_at)
      VALUES ('sug-1', 'expense', 50000, 'cat-1', 'ANDE', 1700000000000, 'recurring', 'pending', 1700000000000);
    ''');
    rawDb.close();
  }

  AppDatabase openDb() => AppDatabase.forTesting(
    DatabaseConnection(NativeDatabase(dbFile), closeStreamsSynchronously: true),
  );

  test('migración v11 -> v12 agrega auto_confirm en merchant_memory, índice único en fingerprint y soporta TxType.transfer sin perder datos', () async {
    createV11Database(dbFile);
    final db = openDb();
    addTearDown(db.close);

    expect(db.schemaVersion, greaterThanOrEqualTo(12));

    // 1. Datos existentes intactos y autoConfirm en false por defecto
    final mem = await db.select(db.merchantMemory).getSingle();
    expect(mem.merchantKey, 'pizza hut');
    expect(mem.uses, 4);
    expect(mem.autoConfirm, isFalse);

    final tx = await db.select(db.transactions).getSingle();
    expect(tx.id, 'tx-1');
    expect(tx.amount, 34500);

    // 2. Actualizar autoConfirm a true
    await (db.update(db.merchantMemory)
          ..where((m) => m.merchantKey.equals('pizza hut')))
        .write(const MerchantMemoryCompanion(autoConfirm: Value(true)));
    final updatedMem = await db.select(db.merchantMemory).getSingle();
    expect(updatedMem.autoConfirm, isTrue);

    // 3. Índice único en suggested_transactions.fingerprint rechaza duplicados
    final now = DateTime(2026, 10, 15, 12, 0);
    await db
        .into(db.suggestedTransactions)
        .insert(
          SuggestedTransactionsCompanion.insert(
            id: 'sug-cap-1',
            type: TxType.expense,
            amount: 34500,
            occurredAt: now,
            source: TxSource.capture,
            status: 'pending',
            fingerprint: const Value('sms:2026-10-15T12:00:00.000:34500'),
            createdAt: now,
          ),
        );

    await expectLater(
      db
          .into(db.suggestedTransactions)
          .insert(
            SuggestedTransactionsCompanion.insert(
              id: 'sug-cap-2',
              type: TxType.expense,
              amount: 34500,
              occurredAt: now.add(const Duration(seconds: 1)),
              source: TxSource.capture,
              status: 'pending',
              fingerprint: const Value('sms:2026-10-15T12:00:00.000:34500'),
              createdAt: now,
            ),
          ),
      throwsA(anything),
    );

    // 4. TxType.transfer se puede insertar en transactions
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: 'tx-transfer',
            type: TxType.transfer,
            amount: 1500000,
            categoryId: 'cat-1',
            merchant: const Value('Bancop Pago de tarjeta con cedula'),
            occurredAt: now,
            createdAt: now,
            updatedAt: now,
            source: TxSource.capture,
          ),
        );

    final transferTx = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals('tx-transfer'))).getSingle();
    expect(transferTx.type, TxType.transfer);
    expect(transferTx.amount, 1500000);
  });
}
