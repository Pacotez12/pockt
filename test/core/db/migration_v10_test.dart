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
    tempDir = await Directory.systemTemp.createTemp('pockt_mig_v10_');
    dbFile = File('${tempDir.path}/pockt_v9.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Base v9 mínima: esquema existente antes de la migración v10.
  void createV9Database(File file) {
    final rawDb = sqlite.sqlite3.open(file.path);
    rawDb.execute('''
      PRAGMA user_version = 9;

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

      INSERT INTO settings (key, value)
      VALUES ('user_pin', '1234');
    ''');
    rawDb.close();
  }

  AppDatabase openDb() => AppDatabase.forTesting(
    DatabaseConnection(NativeDatabase(dbFile), closeStreamsSynchronously: true),
  );

  test('migración v9 -> v10 crea tablas goals y goal_contributions y preserva datos existentes', () async {
    createV9Database(dbFile);
    final db = openDb();
    addTearDown(db.close);

    expect(db.schemaVersion, equals(10));

    // Verificar datos existentes preservados
    final cat = await db.select(db.categories).getSingle();
    expect(cat.name, equals('Comida'));

    final loan = await db.select(db.loans).getSingle();
    expect(loan.name, equals('Auto'));

    final tx = await db.select(db.transactions).getSingle();
    expect(tx.id, equals('tx-1'));
    expect(tx.isExtra, isFalse);

    // Verificar que las nuevas tablas existen y funcionan
    await db
        .into(db.goals)
        .insert(
          GoalsCompanion.insert(
            id: 'goal-vacaciones',
            name: 'Vacaciones',
            icon: 'airplane-tilt',
            targetAmount: 5000000,
            createdAt: DateTime(2026, 10, 15),
          ),
        );

    await db
        .into(db.goalContributions)
        .insert(
          GoalContributionsCompanion.insert(
            id: 'contrib-1',
            goalId: 'goal-vacaciones',
            amount: 500000,
            date: DateTime(2026, 10, 15),
            createdAt: DateTime(2026, 10, 15),
          ),
        );

    final goals = await db.select(db.goals).get();
    expect(goals.length, equals(1));
    expect(goals.first.name, equals('Vacaciones'));

    final contribs = await db.select(db.goalContributions).get();
    expect(contribs.length, equals(1));
    expect(contribs.first.amount, equals(500000));
  });
}
