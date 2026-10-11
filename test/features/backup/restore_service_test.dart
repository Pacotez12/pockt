import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/backup/data/backup_store.dart';
import 'package:pockt/features/backup/data/snapshot.dart';
import 'package:pockt/features/backup/domain/backup_format.dart';
import 'package:pockt/features/backup/domain/restore_service.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory tempDir;
  late File currentDbFile;
  late MemoryBackupStore store;
  late RestoreService restoreService;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pockt_restore_test_');
    currentDbFile = File('${tempDir.path}/pockt.sqlite');
    store = MemoryBackupStore();

    restoreService = RestoreService(
      store: store,
      dbFileResolver: () async => currentDbFile,
      argonIterations: 1,
      argonMemoryInKiB: 1024,
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> createBackupFromDatabase({
    required AppDatabase sourceDb,
    required String password,
    String fileName = 'pockt-20261010-120000.pockt',
  }) async {
    final salt = generateSalt();
    final key = await deriveKey(password, salt, memory: 1024, iterations: 1);
    final snapshotBytes = await snapshotDatabase(sourceDb);
    final pocktBytes = await encodeBackup(snapshotBytes, key, salt);
    await store.upload(fileName, pocktBytes);
    final list = await store.list();
    return list.firstWhere((b) => b.name == fileName).id;
  }

  void createV4RawDatabase(File file, {required int txCount}) {
    final rawDb = sqlite.sqlite3.open(file.path);
    rawDb.execute('''
      PRAGMA user_version = 4;

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
        expected_amount INTEGER,
        category_id TEXT NOT NULL REFERENCES categories(id),
        effective_from INTEGER NOT NULL
      );

      CREATE TABLE budgets (
        id TEXT NOT NULL PRIMARY KEY,
        category_id TEXT NOT NULL REFERENCES categories(id),
        monthly_limit INTEGER NOT NULL
      );

      CREATE TABLE day_marks (
        date TEXT NOT NULL PRIMARY KEY,
        marked_at INTEGER NOT NULL
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

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('cat-comida', 'Comida', 'fork-knife', 1, 2, 'expense', 0);
    ''');

    for (var i = 1; i <= txCount; i++) {
      rawDb.execute('''
        INSERT INTO transactions (id, type, amount, currency, category_id, merchant, occurred_at, created_at, updated_at, source)
        VALUES ('tx-$i', 'expense', ${i * 1000}, 'PYG', 'cat-comida', 'Comercio $i', 1728000000000, 1728000000000, 1728000000000, 'manual');
      ''');
    }

    rawDb.close();
  }

  group('RestoreService', () {
    test('preview obtiene resumen con fecha, cantidad de transacciones y schemaVersion', () async {
      final db = AppDatabase.forTesting(NativeDatabase(currentDbFile));
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-1',
              type: TxType.expense,
              amount: 50000,
              categoryId: '018f0000-0000-7000-8000-000000000001',
              occurredAt: DateTime(2026, 10, 10),
              createdAt: DateTime(2026, 10, 10),
              updatedAt: DateTime(2026, 10, 10),
              source: TxSource.manual,
            ),
          );
      final backupId = await createBackupFromDatabase(
        sourceDb: db,
        password: 'secret-password',
      );
      await db.close();

      final preview = await restoreService.preview(backupId, 'secret-password');
      expect(preview.transactionCount, equals(1));
      expect(preview.schemaVersion, equals(6));
      expect(preview.createdAt, isNotNull);
    });

    test('preview con contraseña incorrecta lanza WrongPasswordException', () async {
      final db = AppDatabase.forTesting(NativeDatabase(currentDbFile));
      final backupId = await createBackupFromDatabase(
        sourceDb: db,
        password: 'correct-password',
      );
      await db.close();

      expect(
        () => restoreService.preview(backupId, 'wrong-password'),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('restaurar reemplaza los movimientos por los del backup', () async {
      // 1. Base actual con 1 movimiento ("Tx Actual")
      final dbActual = AppDatabase.forTesting(NativeDatabase(currentDbFile));
      await dbActual.into(dbActual.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-actual',
              type: TxType.expense,
              amount: 10000,
              categoryId: '018f0000-0000-7000-8000-000000000001',
              occurredAt: DateTime(2026, 10, 9),
              createdAt: DateTime(2026, 10, 9),
              updatedAt: DateTime(2026, 10, 9),
              source: TxSource.manual,
              merchant: const Value('Tx Actual'),
            ),
          );
      await dbActual.close();

      // 2. Base auxiliar para armar el backup con 2 movimientos
      final backupDbFile = File('${tempDir.path}/source_for_backup.sqlite');
      final dbBackup = AppDatabase.forTesting(NativeDatabase(backupDbFile));
      await dbBackup.into(dbBackup.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-b1',
              type: TxType.expense,
              amount: 25000,
              categoryId: '018f0000-0000-7000-8000-000000000001',
              occurredAt: DateTime(2026, 10, 8),
              createdAt: DateTime(2026, 10, 8),
              updatedAt: DateTime(2026, 10, 8),
              source: TxSource.manual,
              merchant: const Value('Tx Backup 1'),
            ),
          );
      await dbBackup.into(dbBackup.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-b2',
              type: TxType.expense,
              amount: 30000,
              categoryId: '018f0000-0000-7000-8000-000000000001',
              occurredAt: DateTime(2026, 10, 8),
              createdAt: DateTime(2026, 10, 8),
              updatedAt: DateTime(2026, 10, 8),
              source: TxSource.manual,
              merchant: const Value('Tx Backup 2'),
            ),
          );

      final backupId = await createBackupFromDatabase(
        sourceDb: dbBackup,
        password: 'mypassword',
      );
      await dbBackup.close();

      // 3. Restaurar sobre currentDbFile
      await restoreService.restore(backupId, 'mypassword');

      // 4. Verificar que currentDbFile ahora tiene los 2 movimientos del backup y no tx-actual
      final verifiedDb = AppDatabase.forTesting(NativeDatabase(currentDbFile));
      final txs = await verifiedDb.select(verifiedDb.transactions).get();
      expect(txs.length, equals(2));
      final merchants = txs.map((t) => t.merchant).toList();
      expect(merchants, containsAll(['Tx Backup 1', 'Tx Backup 2']));
      expect(merchants, isNot(contains('Tx Actual')));
      await verifiedDb.close();
    });

    test('contraseña incorrecta no toca nada', () async {
      // Base actual con 1 movimiento
      final dbActual = AppDatabase.forTesting(NativeDatabase(currentDbFile));
      await dbActual.into(dbActual.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-actual',
              type: TxType.expense,
              amount: 10000,
              categoryId: '018f0000-0000-7000-8000-000000000001',
              occurredAt: DateTime(2026, 10, 9),
              createdAt: DateTime(2026, 10, 9),
              updatedAt: DateTime(2026, 10, 9),
              source: TxSource.manual,
              merchant: const Value('Tx Actual Intacta'),
            ),
          );
      final backupId = await createBackupFromDatabase(
        sourceDb: dbActual,
        password: 'correct-password',
      );
      await dbActual.close();

      // Intento de restaurar con password erróneo
      await expectLater(
        () => restoreService.restore(backupId, 'bad-password'),
        throwsA(isA<WrongPasswordException>()),
      );

      // La base original sigue intacta
      final verifiedDb = AppDatabase.forTesting(NativeDatabase(currentDbFile));
      final txs = await verifiedDb.select(verifiedDb.transactions).get();
      expect(txs.length, equals(1));
      expect(txs.first.merchant, equals('Tx Actual Intacta'));
      await verifiedDb.close();
    });

    test('un backup con esquema v4 se migra al reabrir', () async {
      // 1. Crear base SQLite v4 con 3 movimientos
      final v4File = File('${tempDir.path}/v4_source.sqlite');
      createV4RawDatabase(v4File, txCount: 3);

      final salt = generateSalt();
      final key = await deriveKey('v4pass', salt, memory: 1024, iterations: 1);
      final rawBytes = await v4File.readAsBytes();
      final pocktBytes = await encodeBackup(rawBytes, key, salt);
      await store.upload('v4_backup.pockt', pocktBytes);
      final list = await store.list();
      final backupId = list.firstWhere((b) => b.name == 'v4_backup.pockt').id;

      // 2. Base actual con v5
      final dbActual = AppDatabase.forTesting(NativeDatabase(currentDbFile));
      await dbActual.select(dbActual.categories).get();
      await dbActual.close();

      // 3. Restaurar backup v4
      await restoreService.restore(backupId, 'v4pass');

      // 4. Abrir la base restaurada: debe migrar a v5 sin fallar y tener los 3 movimientos
      final migratedDb = AppDatabase.forTesting(NativeDatabase(currentDbFile));
      expect(migratedDb.schemaVersion, equals(6));
      final txs = await migratedDb.select(migratedDb.transactions).get();
      expect(txs.length, equals(3));
      await migratedDb.close();
    });

    test('si el reemplazo falla a mitad, la base original queda intacta', () async {
      // 1. Base actual con movimiento
      final dbActual = AppDatabase.forTesting(NativeDatabase(currentDbFile));
      await dbActual.into(dbActual.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-original',
              type: TxType.expense,
              amount: 77000,
              categoryId: '018f0000-0000-7000-8000-000000000001',
              occurredAt: DateTime(2026, 10, 9),
              createdAt: DateTime(2026, 10, 9),
              updatedAt: DateTime(2026, 10, 9),
              source: TxSource.manual,
              merchant: const Value('Original Intacto'),
            ),
          );
      await dbActual.close();

      // 2. Subir un backup que contiene bytes corruptos (no es una base SQLite válida)
      final salt = generateSalt();
      final key = await deriveKey('mypass', salt, memory: 1024, iterations: 1);
      final corruptBytes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      final pocktBytes = await encodeBackup(corruptBytes, key, salt);
      await store.upload('corrupt.pockt', pocktBytes);
      final backupId = (await store.list()).first.id;

      // 3. Restaurar debe fallar al reabrir/validar la base
      await expectLater(
        () => restoreService.restore(backupId, 'mypass'),
        throwsA(anything),
      );

      // 4. La base original sigue intacta gracias al rollback
      final verifiedDb = AppDatabase.forTesting(NativeDatabase(currentDbFile));
      final txs = await verifiedDb.select(verifiedDb.transactions).get();
      expect(txs.length, equals(1));
      expect(txs.first.merchant, equals('Original Intacto'));
      await verifiedDb.close();
    });
  });
}
