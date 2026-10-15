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
    tempDir = await Directory.systemTemp.createTemp('pockt_mig_v9_');
    dbFile = File('${tempDir.path}/pockt_v8.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Base v8 mínima: solo las tablas que toca la migración v9.
  void createV8Database(
    File file, {
    required int prestamosDark,
    required int prestamosLight,
  }) {
    final rawDb = sqlite.sqlite3.open(file.path);
    rawDb.execute('''
      PRAGMA user_version = 8;

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
        loan_id TEXT REFERENCES loans(id)
      );

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order, archived)
      VALUES ('cat-1', 'Comida', 'fork-knife', 14983271, 10114309, 'expense', 0, 0);

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order, archived)
      VALUES ('018f0000-0000-7000-8000-000000000014', 'Préstamos', 'coins',
              $prestamosDark, $prestamosLight, 'expense', 10, 0);

      INSERT INTO loans (id, direction, kind, name, total_amount, start_date, created_at, updated_at)
      VALUES ('loan-1', 'owe', 'installments', 'Auto', 1200000, 1700000000000, 1700000000000, 1700000000000);

      -- Cuota normal sin nota
      INSERT INTO transactions (id, type, amount, category_id, note, occurred_at, created_at, updated_at, source, loan_id)
      VALUES ('tx-regular', 'expense', 100000, 'cat-1', NULL, 1700000000000, 1700000000000, 1700000000000, 'manual', 'loan-1');

      -- Pago extra viejo: lo marcaba la nota
      INSERT INTO transactions (id, type, amount, category_id, note, occurred_at, created_at, updated_at, source, loan_id)
      VALUES ('tx-extra', 'expense', 200000, 'cat-1', 'Pago extra', 1700000000000, 1700000000000, 1700000000000, 'manual', 'loan-1');

      -- Adelanto con mayúsculas
      INSERT INTO transactions (id, type, amount, category_id, note, occurred_at, created_at, updated_at, source, loan_id)
      VALUES ('tx-adelanto', 'expense', 150000, 'cat-1', 'ADELANTO de cuotas', 1700000000000, 1700000000000, 1700000000000, 'manual', 'loan-1');

      -- Gasto común (sin préstamo) cuya nota dice extra: NO es pago extra
      INSERT INTO transactions (id, type, amount, category_id, note, occurred_at, created_at, updated_at, source, loan_id)
      VALUES ('tx-comun', 'expense', 50000, 'cat-1', 'compra extra', 1700000000000, 1700000000000, 1700000000000, 'manual', NULL);
    ''');
    rawDb.close();
  }

  AppDatabase openDb() => AppDatabase.forTesting(
    DatabaseConnection(NativeDatabase(dbFile), closeStreamsSynchronously: true),
  );

  test(
    'migración v8 -> v9 agrega is_extra y marca los pagos extra por la nota',
    () async {
      createV8Database(
        dbFile,
        prestamosDark: 0xFF8BA4B5,
        prestamosLight: 0xFF3D6176,
      );
      final db = openDb();
      addTearDown(db.close);

      expect(db.schemaVersion, equals(10));

      final txs = {
        for (final t in await db.select(db.transactions).get()) t.id: t,
      };
      expect(txs.length, equals(4));
      expect(txs['tx-regular']!.isExtra, isFalse);
      expect(txs['tx-extra']!.isExtra, isTrue);
      expect(txs['tx-adelanto']!.isExtra, isTrue);
      expect(txs['tx-comun']!.isExtra, isFalse);
    },
  );

  test(
    'migración v8 -> v9 cambia el color de Préstamos si conserva el de fábrica',
    () async {
      createV8Database(
        dbFile,
        prestamosDark: 0xFF8BA4B5,
        prestamosLight: 0xFF3D6176,
      );
      final db = openDb();
      addTearDown(db.close);

      final cat = await (db.select(
        db.categories,
      )..where((c) => c.name.equals('Préstamos'))).getSingle();
      expect(cat.colorDark, equals(0xFF5FC8A6));
      expect(cat.colorLight, equals(0xFF007E5E));
    },
  );

  test(
    'migración v8 -> v9 respeta el color de Préstamos si el usuario lo cambió',
    () async {
      createV8Database(
        dbFile,
        prestamosDark: 0xFF123456,
        prestamosLight: 0xFF654321,
      );
      final db = openDb();
      addTearDown(db.close);

      final cat = await (db.select(
        db.categories,
      )..where((c) => c.name.equals('Préstamos'))).getSingle();
      expect(cat.colorDark, equals(0xFF123456));
      expect(cat.colorLight, equals(0xFF654321));
    },
  );

  test('una base nueva nace con el color propio de Préstamos', () async {
    final db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);

    final cat = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Préstamos'))).getSingle();
    expect(cat.colorDark, equals(0xFF5FC8A6));
    expect(cat.colorLight, equals(0xFF007E5E));
  });
}
