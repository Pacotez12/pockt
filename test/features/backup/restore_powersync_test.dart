import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/sync/migrate_legacy_db.dart';
import 'package:pockt/core/sync/powersync_schema.dart';
import 'package:pockt/features/backup/data/backup_store.dart';
import 'package:pockt/features/backup/data/snapshot.dart';
import 'package:pockt/features/backup/domain/backup_format.dart';
import 'package:pockt/features/backup/domain/restore_service.dart';
import 'package:powersync/powersync.dart' as ps;
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MemoryBackupStore store;

  setUp(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tempDir = Directory.systemTemp.createTempSync('pockt_restore_ps_test_');
    store = MemoryBackupStore();
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<ps.PowerSyncDatabase> createTargetPowerSyncDb(String name) async {
    final dbPath = p.join(tempDir.path, '$name.db');
    final target = ps.PowerSyncDatabase(
      schema: pocktPowerSyncSchema,
      path: dbPath,
    );
    await target.initialize();
    return target;
  }

  Future<List<int>> createEncryptedBackupFromBytes(
    List<int> sqliteBytes,
    String password,
  ) async {
    final salt = generateSalt();
    final key = await deriveKey(password, salt, memory: 1024, iterations: 1);
    return encodeBackup(sqliteBytes, key, salt);
  }

  test(
    'restaurar una copia v16 sobre base PowerSync con otros datos deja conteos y sumas iguales; tablas _pockt intactas',
    () async {
      final fixtureFile = File('test/fixtures/pockt_v16_demo.db');
      expect(fixtureFile.existsSync(), isTrue);

      // Cifrar la copia v16
      final backupBytes = await createEncryptedBackupFromBytes(
        fixtureFile.readAsBytesSync(),
        'restore-pass-v16',
      );

      // Crear base destino PowerSync con otros datos y con tablas _pockt
      final targetPs = await createTargetPowerSyncDb('ps_v16_target');
      addTearDown(targetPs.close);

      // Crear tablas _pockt_sync_owner y _pockt_migration con valores previos
      await targetPs.execute(
        'CREATE TABLE IF NOT EXISTS _pockt_sync_owner (id TEXT PRIMARY KEY, user_id TEXT, bound_at INTEGER);',
      );
      await targetPs.execute(
        "INSERT INTO _pockt_sync_owner (id, user_id, bound_at) VALUES ('owner', 'user-owner-v16', 123456789);",
      );
      await targetPs.execute(
        'CREATE TABLE IF NOT EXISTS _pockt_migration (key TEXT PRIMARY KEY, value TEXT);',
      );
      await targetPs.execute(
        "INSERT INTO _pockt_migration (key, value) VALUES ('legacy_drift_migrated', '1');",
      );

      // Insertar datos diferentes en destino para verificar que se reemplacen
      final driftAppDb = AppDatabase.powerSync(targetPs);
      addTearDown(driftAppDb.close);
      await driftAppDb.into(driftAppDb.categories).insert(
            CategoriesCompanion.insert(
              id: 'cat-temp',
              name: 'Categoria Temporal',
              icon: 'temp',
              colorDark: 1,
              colorLight: 2,
              kind: CategoryKind.expense,
              sortOrder: 99,
            ),
          );
      await driftAppDb.into(driftAppDb.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-temp',
              type: TxType.expense,
              amount: 999999,
              categoryId: 'cat-temp',
              occurredAt: DateTime(2026, 1, 1),
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
              source: TxSource.manual,
            ),
          );

      // Medir valores esperados de la copia v16 tras migrar una copia a v17
      final v16Temp = File(p.join(tempDir.path, 'v16_temp_measure.db'));
      fixtureFile.copySync(v16Temp.path);
      await ensureLegacyDbMigrated(v16Temp.path);
      final originSqlite = sqlite.sqlite3.open(v16Temp.path);
      final expectedCounts = <String, int>{};
      final expectedSums = <String, int>{};
      for (final table in allPocktTables) {
        final countRes = originSqlite.select('SELECT count(*) as c FROM "$table"');
        expectedCounts[table] = countRes.first['c'] as int;
        final cols = originSqlite.select('PRAGMA table_info("$table")');
        final hasAmount = cols.any((col) => col['name'] == 'amount');
        if (hasAmount) {
          final sumRes = originSqlite.select(
            'SELECT COALESCE(SUM(amount), 0) as s FROM "$table"',
          );
          expectedSums[table] = sumRes.first['s'] as int;
        }
      }
      originSqlite.close();

      // Restaurar
      final service = RestoreService(
        store: store,
        powerSyncDatabase: targetPs,
        argonIterations: 1,
        argonMemoryInKiB: 1024,
      );

      await service.restoreBytes(backupBytes, 'restore-pass-v16');

      // Verificar conteos y sumas en PowerSync
      for (final table in allPocktTables) {
        final countRes = await targetPs.get('SELECT count(*) as c FROM "$table"');
        expect(
          countRes['c'],
          equals(expectedCounts[table]),
          reason: 'Conteo de tabla $table no coincide con la copia',
        );
        if (expectedSums.containsKey(table)) {
          final sumRes = await targetPs.get(
            'SELECT COALESCE(SUM(amount), 0) as s FROM "$table"',
          );
          expect(
            sumRes['s'],
            equals(expectedSums[table]),
            reason: 'Suma de amount en tabla $table no coincide con la copia',
          );
        }
      }

      // Verificar que _pockt_sync_owner y _pockt_migration quedaron exactamente intactas
      final ownerRow = await targetPs.getOptional(
        "SELECT user_id FROM _pockt_sync_owner WHERE id = 'owner'",
      );
      expect(ownerRow?['user_id'], equals('user-owner-v16'));

      final migrationRow = await targetPs.getOptional(
        "SELECT value FROM _pockt_migration WHERE key = 'legacy_drift_migrated'",
      );
      expect(migrationRow?['value'], equals('1'));
    },
  );

  test('contraseña incorrecta no cambia nada en PowerSync', () async {
    final fixtureFile = File('test/fixtures/pockt_v16_demo.db');
    final backupBytes = await createEncryptedBackupFromBytes(
      fixtureFile.readAsBytesSync(),
      'correct-password',
    );

    final targetPs = await createTargetPowerSyncDb('ps_wrong_pass_target');
    addTearDown(targetPs.close);

    final driftAppDb = AppDatabase.powerSync(targetPs);
    addTearDown(driftAppDb.close);
    await driftAppDb.into(driftAppDb.categories).insert(
          CategoriesCompanion.insert(
            id: 'cat-intact',
            name: 'Categoria Intacta',
            icon: 'intact',
            colorDark: 1,
            colorLight: 2,
            kind: CategoryKind.expense,
            sortOrder: 1,
          ),
        );

    final initialCatCount = (await targetPs.get('SELECT count(*) as c FROM categories'))['c'] as int;

    final service = RestoreService(
      store: store,
      powerSyncDatabase: targetPs,
      argonIterations: 1,
      argonMemoryInKiB: 1024,
    );

    await expectLater(
      service.restoreBytes(backupBytes, 'wrong-password'),
      throwsA(isA<WrongPasswordException>()),
    );

    final catsCountAfter = (await targetPs.get('SELECT count(*) as c FROM categories'))['c'] as int;
    expect(catsCountAfter, equals(initialCatCount));
    final catIntact = await targetPs.getOptional("SELECT * FROM categories WHERE id = 'cat-intact'");
    expect(catIntact, isNotNull);
  });

  test('falla simulada a mitad no cambia nada (rollback total en PowerSync)', () async {
    final fixtureFile = File('test/fixtures/pockt_v16_demo.db');
    final backupBytes = await createEncryptedBackupFromBytes(
      fixtureFile.readAsBytesSync(),
      'pass-rollback',
    );

    final targetPs = await createTargetPowerSyncDb('ps_rollback_target');
    addTearDown(targetPs.close);

    final driftAppDb = AppDatabase.powerSync(targetPs);
    addTearDown(driftAppDb.close);
    await driftAppDb.into(driftAppDb.categories).insert(
          CategoriesCompanion.insert(
            id: 'cat-keep-me',
            name: 'Keep Me',
            icon: 'safe',
            colorDark: 1,
            colorLight: 2,
            kind: CategoryKind.expense,
            sortOrder: 1,
          ),
        );

    final initialCatCount = (await targetPs.get('SELECT count(*) as c FROM categories'))['c'] as int;

    final service = RestoreService(
      store: store,
      powerSyncDatabase: targetPs,
      argonIterations: 1,
      argonMemoryInKiB: 1024,
    );

    await expectLater(
      service.restoreBytes(
        backupBytes,
        'pass-rollback',
        simulateFailureAtTable: 'transactions',
      ),
      throwsA(anything),
    );

    // Debe conservar el estado original
    final catsCountAfter = (await targetPs.get('SELECT count(*) as c FROM categories'))['c'] as int;
    expect(catsCountAfter, equals(initialCatCount));
    final catKeepMe = await targetPs.getOptional("SELECT * FROM categories WHERE id = 'cat-keep-me'");
    expect(catKeepMe, isNotNull);
  });

  test(
    'restaurar copia formato PowerSync (snapshotDatabase) sobre otra base PowerSync deja conteos y sumas iguales',
    () async {
      // 1. Crear una base PowerSync origen con datos
      final sourcePs = await createTargetPowerSyncDb('ps_source_b');
      addTearDown(sourcePs.close);
      final sourceDrift = AppDatabase.powerSync(sourcePs);
      addTearDown(sourceDrift.close);

      await sourceDrift.into(sourceDrift.categories).insert(
            CategoriesCompanion.insert(
              id: 'cat-food',
              name: 'Comida',
              icon: 'food',
              colorDark: 10,
              colorLight: 20,
              kind: CategoryKind.expense,
              sortOrder: 1,
            ),
          );
      await sourceDrift.into(sourceDrift.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-1',
              type: TxType.expense,
              amount: 50000,
              categoryId: 'cat-food',
              occurredAt: DateTime(2026, 10, 1),
              createdAt: DateTime(2026, 10, 1),
              updatedAt: DateTime(2026, 10, 1),
              source: TxSource.manual,
            ),
          );
      await sourceDrift.into(sourceDrift.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-2',
              type: TxType.expense,
              amount: 75000,
              categoryId: 'cat-food',
              occurredAt: DateTime(2026, 10, 2),
              createdAt: DateTime(2026, 10, 2),
              updatedAt: DateTime(2026, 10, 2),
              source: TxSource.manual,
            ),
          );
      // Agregar en una tabla local también
      await sourceDrift.into(sourceDrift.dayMarks).insert(
            DayMarksCompanion.insert(
              id: '2026-10-01',
              date: '2026-10-01',
              noSpend: true,
            ),
          );

      // 2. Hacer snapshotDatabase y cifrar
      final snapshotBytes = await snapshotDatabase(sourceDrift);
      final backupBytes = await createEncryptedBackupFromBytes(
        snapshotBytes,
        'pass-format-b',
      );

      // 3. Crear otra base PowerSync destino con datos diferentes
      final targetPs = await createTargetPowerSyncDb('ps_target_b');
      addTearDown(targetPs.close);
      final targetDrift = AppDatabase.powerSync(targetPs);
      addTearDown(targetDrift.close);

      await targetDrift.into(targetDrift.categories).insert(
            CategoriesCompanion.insert(
              id: 'cat-other',
              name: 'Otra',
              icon: 'other',
              colorDark: 1,
              colorLight: 2,
              kind: CategoryKind.income,
              sortOrder: 5,
            ),
          );

      // 4. Restaurar sobre la base destino
      final expectedCatCount = (await sourcePs.get('SELECT count(*) as c FROM categories'))['c'] as int;
      final service = RestoreService(
        store: store,
        powerSyncDatabase: targetPs,
        argonIterations: 1,
        argonMemoryInKiB: 1024,
      );

      await service.restoreBytes(backupBytes, 'pass-format-b');

      // 5. Conteos y sumas deben coincidir con la base origen
      final catCount = await targetPs.get('SELECT count(*) as c FROM categories');
      expect(catCount['c'], equals(expectedCatCount));
      final txCount = await targetPs.get('SELECT count(*) as c FROM transactions');
      expect(txCount['c'], equals(2));
      final txSum = await targetPs.get('SELECT SUM(amount) as s FROM transactions');
      expect(txSum['s'], equals(125000));
      final dmCount = await targetPs.get('SELECT count(*) as c FROM day_marks');
      expect(dmCount['c'], equals(1));
    },
  );

  test('RestorePreview funciona con copias legacy (v16) y copias PowerSync', () async {
    final fixtureFile = File('test/fixtures/pockt_v16_demo.db');
    final v16Bytes = await createEncryptedBackupFromBytes(
      fixtureFile.readAsBytesSync(),
      'preview-pass',
    );

    final service = RestoreService(
      store: store,
      argonIterations: 1,
      argonMemoryInKiB: 1024,
    );

    // Preview de v16
    final previewV16 = await service.previewBytes(
      v16Bytes,
      'preview-pass',
      createdAt: DateTime(2026, 10, 1),
    );
    expect(previewV16.transactionCount, greaterThan(0));
    expect(previewV16.schemaVersion, equals(16));

    // Preview de PowerSync
    final psDb = await createTargetPowerSyncDb('ps_preview');
    addTearDown(psDb.close);
    final driftDb = AppDatabase.powerSync(psDb);
    addTearDown(driftDb.close);
    await driftDb.into(driftDb.categories).insert(
          CategoriesCompanion.insert(
            id: 'c1',
            name: 'C1',
            icon: 'icon',
            colorDark: 1,
            colorLight: 2,
            kind: CategoryKind.expense,
            sortOrder: 1,
          ),
        );
    await driftDb.into(driftDb.transactions).insert(
          TransactionsCompanion.insert(
            id: 't1',
            type: TxType.expense,
            amount: 5000,
            categoryId: 'c1',
            occurredAt: DateTime(2026, 1, 1),
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
            source: TxSource.manual,
          ),
        );
    final psSnapshot = await snapshotDatabase(driftDb);
    final psBackupBytes = await createEncryptedBackupFromBytes(
      psSnapshot,
      'preview-pass',
    );

    final previewPs = await service.previewBytes(
      psBackupBytes,
      'preview-pass',
      createdAt: DateTime(2026, 10, 2),
    );
    expect(previewPs.transactionCount, equals(1));
    expect(previewPs.schemaVersion, equals(17));
  });

  test('restoreServiceProvider de producción no bloquea con RestoreSafetyException', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(restoreServiceProvider);
    expect(service.beforeRestore, isNull);
  });
}
