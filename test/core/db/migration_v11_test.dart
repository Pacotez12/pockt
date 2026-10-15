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
    tempDir = await Directory.systemTemp.createTemp('pockt_mig_v11_');
    dbFile = File('${tempDir.path}/pockt_v10.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Base v10 mínima: esquema existente antes de la migración v11.
  void createV10Database(File file) {
    final rawDb = sqlite.sqlite3.open(file.path);
    rawDb.execute('''
      PRAGMA user_version = 10;

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
        is_extra INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE goals (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        target_amount INTEGER NOT NULL,
        target_date INTEGER,
        created_at INTEGER NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE goal_contributions (
        id TEXT NOT NULL PRIMARY KEY,
        goal_id TEXT NOT NULL REFERENCES goals(id),
        amount INTEGER NOT NULL,
        date INTEGER NOT NULL,
        note TEXT,
        created_at INTEGER NOT NULL
      );

      CREATE TABLE settings (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL
      );

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order, archived)
      VALUES ('cat-1', 'Comida', 'fork-knife', 14983271, 10114309, 'expense', 0, 0);

      INSERT INTO loans (id, direction, kind, name, total_amount, start_date, created_at, updated_at)
      VALUES ('loan-1', 'owe', 'installments', 'Auto', 1200000, 1700000000000, 1700000000000, 1700000000000);

      INSERT INTO transactions (id, type, amount, category_id, note, occurred_at, created_at, updated_at, source, loan_id, is_extra)
      VALUES ('tx-1', 'expense', 100000, 'cat-1', 'cuota', 1700000000000, 1700000000000, 1700000000000, 'manual', 'loan-1', 0);

      INSERT INTO goals (id, name, icon, target_amount, created_at, archived)
      VALUES ('goal-1', 'Ahorro', 'piggy-bank', 10000000, 1700000000000, 0);

      INSERT INTO goal_contributions (id, goal_id, amount, date, created_at)
      VALUES ('gc-1', 'goal-1', 500000, 1700000000000, 1700000000000);

      INSERT INTO settings (key, value)
      VALUES ('home.headline', 'safeToSpend');
    ''');
    rawDb.close();
  }

  AppDatabase openDb() => AppDatabase.forTesting(
    DatabaseConnection(NativeDatabase(dbFile), closeStreamsSynchronously: true),
  );

  test('migración v10 -> v11 crea entry_shortcuts, events y columna event_id en transactions sin perder datos', () async {
    createV10Database(dbFile);
    final db = openDb();
    addTearDown(db.close);

    expect(db.schemaVersion, equals(11));

    // 1. Datos existentes intactos
    final cat = await db.select(db.categories).getSingle();
    expect(cat.name, equals('Comida'));

    final loan = await db.select(db.loans).getSingle();
    expect(loan.name, equals('Auto'));

    final tx = await db.select(db.transactions).getSingle();
    expect(tx.id, equals('tx-1'));
    expect(tx.eventId, isNull);

    final goal = await db.select(db.goals).getSingle();
    expect(goal.name, equals('Ahorro'));

    final contrib = await db.select(db.goalContributions).getSingle();
    expect(contrib.amount, equals(500000));

    // 2. Probar inserción en entry_shortcuts
    await db
        .into(db.entryShortcuts)
        .insert(
          EntryShortcutsCompanion.insert(
            id: 'sc-1',
            merchant: const Value('Biggie'),
            amount: 25000,
            categoryId: 'cat-1',
            isPinned: const Value(true),
            createdAt: DateTime(2026, 10, 15),
          ),
        );

    final shortcuts = await db.select(db.entryShortcuts).get();
    expect(shortcuts.length, equals(1));
    expect(shortcuts.first.merchant, equals('Biggie'));
    expect(shortcuts.first.isPinned, isTrue);

    // 3. Probar inserción en events
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: 'ev-1',
            name: 'Asado cumple',
            icon: 'beer-bottle',
            startDate: DateTime(2026, 10, 15),
            isActive: const Value(true),
            createdAt: DateTime(2026, 10, 15),
          ),
        );

    final events = await db.select(db.events).get();
    expect(events.length, equals(1));
    expect(events.first.name, equals('Asado cumple'));
    expect(events.first.isActive, isTrue);

    // 4. Probar nuevo movimiento vinculado al evento
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: 'tx-2',
            type: TxType.expense,
            amount: 150000,
            categoryId: 'cat-1',
            occurredAt: DateTime(2026, 10, 15),
            createdAt: DateTime(2026, 10, 15),
            updatedAt: DateTime(2026, 10, 15),
            source: TxSource.manual,
            eventId: const Value('ev-1'),
          ),
        );

    final txWithEvent = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals('tx-2'))).getSingle();
    expect(txWithEvent.eventId, equals('ev-1'));
  });
}
