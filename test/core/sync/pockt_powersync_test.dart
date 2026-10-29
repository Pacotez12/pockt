import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/sync/migrate_legacy_db.dart';
import 'package:pockt/core/sync/pockt_powersync.dart';
import 'package:pockt/core/sync/powersync_schema.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/capture/data/capture_service.dart';
import 'package:pockt/features/capture/data/counterparty_rules_repository.dart';
import 'package:pockt/features/capture/data/email_capture_service.dart';
import 'package:pockt/features/capture/data/email_source.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:powersync/powersync.dart' as ps;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:timezone/data/latest.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    tz.initializeTimeZones();
    await initLocalZone();
  });

  late Directory tempDir;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tempDir = Directory.systemTemp.createTempSync('pockt_powersync_test_');
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Tarea 2.3: PowerSync y Migración Legacy', () {
    test(
      '(a) migración de la base v17 de demo: reportes iguales, .pre-sync.bak existe, marca guardada y segunda corrida no hace nada',
      () async {
        final fixtureFile = File('test/fixtures/pockt_v16_demo.db');
        expect(
          fixtureFile.existsSync(),
          isTrue,
          reason: 'Fixture v16 demo debe existir',
        );

        final oldDbPath = p.join(tempDir.path, 'pockt_legacy.db');
        fixtureFile.copySync(oldDbPath);

        // 1. Migrar la base vieja de v16 a v17 con Drift
        await ensureLegacyDbMigrated(oldDbPath);

        // 2. Medir valores esperados de origen directamente con sqlite3
        final originSqlite = sqlite.sqlite3.open(oldDbPath);
        final expectedRows = <String, int>{};
        final expectedAmountSums = <String, int>{};

        for (final table in allPocktTables) {
          final countRes =
              originSqlite.select('SELECT count(*) as c FROM "$table"');
          expectedRows[table] = countRes.first['c'] as int;

          final cols = originSqlite.select('PRAGMA table_info("$table")');
          final hasAmount = cols.any((col) => col['name'] == 'amount');
          if (hasAmount) {
            final sumRes = originSqlite.select(
              'SELECT COALESCE(SUM(amount), 0) as s FROM "$table"',
            );
            expectedAmountSums[table] = sumRes.first['s'] as int;
          }
        }
        originSqlite.close();

        final expectedReport = MigrationReport(
          rowsByTable: expectedRows,
          amountSumByTable: expectedAmountSums,
        );

        // 3. Crear base de datos PowerSync destino
        final targetDbPath = p.join(tempDir.path, 'powersync_target.db');
        final target = ps.PowerSyncDatabase(
          schema: pocktPowerSyncSchema,
          path: targetDbPath,
        );
        await target.initialize();
        addTearDown(target.close);

        // 4. Ejecutar migración inicial
        final resultReport = await migrateLegacyDriftDb(
          oldDbPath: oldDbPath,
          target: target,
        );

        // a) Reportes iguales tabla por tabla
        expect(resultReport, equals(expectedReport));

        // b) .pre-sync.bak existe
        final backupFile = File('$oldDbPath.pre-sync.bak');
        expect(backupFile.existsSync(), isTrue);

        // c) Marca de migración guardada
        expect(await isMigrationMarkSaved(target), isTrue);

        // d) Segunda corrida no hace nada
        final secondReport = await migrateLegacyDriftDb(
          oldDbPath: oldDbPath,
          target: target,
        );
        expect(secondReport, isNull);

        // e) Verificación en destino: filas y sumas coinciden
        for (final table in allPocktTables) {
          final targetCountRow =
              await target.get('SELECT count(*) as c FROM "$table"');
          expect(
            targetCountRow['c'],
            equals(expectedRows[table]),
            reason: 'Conteo no coincide en $table',
          );
          if (expectedAmountSums.containsKey(table)) {
            final targetSumRow = await target.get(
              'SELECT COALESCE(SUM(amount), 0) as s FROM "$table"',
            );
            expect(
              targetSumRow['s'],
              equals(expectedAmountSums[table]),
              reason: 'Suma de amount no coincide en $table',
            );
          }
        }

        // f) IDs especiales derivados
        final installment = await target.get(
          'SELECT id, loan_id, number FROM loan_installments LIMIT 1',
        );
        expect(
          installment['id'],
          equals('${installment['loan_id']}:${installment['number']}'),
        );

        final setting = await target.get('SELECT id, key FROM settings LIMIT 1');
        expect(setting['id'], equals(setting['key']));
      },
    );

    test(
      '(b) migración cortada a mitad: la próxima apertura reintenta y no duplica',
      () async {
        final fixtureFile = File('test/fixtures/pockt_v16_demo.db');
        final oldDbPath = p.join(tempDir.path, 'pockt_legacy_cut.db');
        fixtureFile.copySync(oldDbPath);

        await ensureLegacyDbMigrated(oldDbPath);

        final originSqlite = sqlite.sqlite3.open(oldDbPath);
        final expectedTxCount = (originSqlite.select(
          'SELECT count(*) as c FROM transactions',
        ).first['c'] as int);
        originSqlite.close();

        final targetDbPath = p.join(tempDir.path, 'powersync_cut.db');
        final target = ps.PowerSyncDatabase(
          schema: pocktPowerSyncSchema,
          path: targetDbPath,
        );
        await target.initialize();
        addTearDown(target.close);

        // 1. Simular corte a mitad de migración lanzando excepción a mitad de camino
        expect(
          () => migrateLegacyDriftDb(
            oldDbPath: oldDbPath,
            target: target,
            simulateFailureAtTable: 'transactions',
          ),
          throwsA(isA<Exception>()),
        );

        // Marca de migración NO debe estar guardada
        expect(await isMigrationMarkSaved(target), isFalse);

        // 2. La siguiente corrida reintenta y completa exitosamente
        final result = await migrateLegacyDriftDb(
          oldDbPath: oldDbPath,
          target: target,
        );
        expect(result, isNotNull);
        expect(await isMigrationMarkSaved(target), isTrue);

        // Verificar que no se duplicaron transacciones
        final targetTx =
            await target.get('SELECT count(*) as c FROM transactions');
        expect(targetTx['c'], equals(expectedTxCount));
      },
    );

    test(
      '(c) un stream watch() de Drift sobre transactions emite tras un cambio escrito por otra conexión',
      () async {
        final targetDbPath = p.join(tempDir.path, 'powersync_watch.db');
        final psDb = ps.PowerSyncDatabase(
          schema: pocktPowerSyncSchema,
          path: targetDbPath,
        );
        await psDb.initialize();
        addTearDown(psDb.close);

        final db = AppDatabase.powerSync(psDb);
        addTearDown(db.close);

        // Insertar categoría previa para foreign key
        await psDb.execute(
          'INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order, archived) '
          "VALUES ('cat-watch', 'General', 'tag', 0, 0, 'expense', 1, 0)",
        );

        final emissions = <List<Transaction>>[];
        final completer = Completer<void>();

        final sub = db.select(db.transactions).watch().listen((list) {
          emissions.add(list);
          if (list.any((tx) => tx.id == 'tx-watch-1')) {
            if (!completer.isCompleted) completer.complete();
          }
        });
        addTearDown(sub.cancel);

        // Esperar la primera emisión inicial
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Escribir cambio directamente en PowerSync (simulando sync u otra conexión)
        await psDb.execute(
          'INSERT INTO transactions (id, type, amount, currency, category_id, occurred_at, created_at, updated_at, source, is_extra) '
          "VALUES ('tx-watch-1', 'expense', 25000, 'PYG', 'cat-watch', 1729000000, 1729000000, 1729000000, 'manual', 0)",
        );

        await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('watch() no emitió el cambio'),
        );

        expect(emissions.last.any((tx) => tx.id == 'tx-watch-1'), isTrue);
      },
    );

    test(
      '(d) dos conexiones (simulando Workmanager) escriben sin perder filas',
      () async {
        final targetDbPath = p.join(tempDir.path, 'powersync_concurrency.db');

        final psDb1 = ps.PowerSyncDatabase(
          schema: pocktPowerSyncSchema,
          path: targetDbPath,
        );
        await psDb1.initialize();
        addTearDown(psDb1.close);

        final psDb2 = ps.PowerSyncDatabase(
          schema: pocktPowerSyncSchema,
          path: targetDbPath,
        );
        await psDb2.initialize();
        addTearDown(psDb2.close);

        final db1 = AppDatabase.powerSync(psDb1);
        addTearDown(db1.close);

        final db2 = AppDatabase.powerSync(psDb2);
        addTearDown(db2.close);

        // Insertar categoría previa
        await psDb1.execute(
          'INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order, archived) '
          "VALUES ('cat-conc', 'General', 'tag', 0, 0, 'expense', 1, 0)",
        );

        const countPerConnection = 10;

        // Escritura concurrente desde db1 y db2
        final writes1 = Future.wait(
          List.generate(countPerConnection, (i) {
            return db1.into(db1.transactions).insert(
                  TransactionsCompanion.insert(
                    id: 'tx-conn1-$i',
                    type: TxType.expense,
                    amount: 1000 * (i + 1),
                    currency: const Value('PYG'),
                    categoryId: 'cat-conc',
                    occurredAt: DateTime.now(),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    source: TxSource.manual,
                    isExtra: const Value(false),
                  ),
                );
          }),
        );

        final writes2 = Future.wait(
          List.generate(countPerConnection, (i) {
            return db2.into(db2.transactions).insert(
                  TransactionsCompanion.insert(
                    id: 'tx-conn2-$i',
                    type: TxType.expense,
                    amount: 2000 * (i + 1),
                    currency: const Value('PYG'),
                    categoryId: 'cat-conc',
                    occurredAt: DateTime.now(),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    source: TxSource.manual,
                    isExtra: const Value(false),
                  ),
                );
          }),
        );

        await Future.wait([writes1, writes2]);

        // Validar conteo total exacto
        final allTxs = await db1.select(db1.transactions).get();
        expect(allTxs.length, equals(countPerConnection * 2));
      },
    );

    test(
      '(e) openPocktPowerSync abre e inicializa correctamente con la ruta especificada',
      () async {
        final targetDbPath = p.join(tempDir.path, 'powersync_open.db');
        final psDb = await openPocktPowerSync(path: targetDbPath);
        addTearDown(psDb.close);

        expect(psDb.closed, isFalse);
        final check = await psDb.get('SELECT 1 as val');
        expect(check['val'], equals(1));
      },
    );

    test(
      '(f) instalación nueva sin legacy siembra categorías y keywords; con legacy no los duplica',
      () async {
        // 1. Base PowerSync limpia (instalación nueva)
        final freshDbPath = p.join(tempDir.path, 'powersync_fresh.db');
        final psFresh = ps.PowerSyncDatabase(
          schema: pocktPowerSyncSchema,
          path: freshDbPath,
        );
        await psFresh.initialize();
        addTearDown(psFresh.close);

        final dbFresh = AppDatabase.powerSync(psFresh);
        addTearDown(dbFresh.close);

        final freshCats = await dbFresh.select(dbFresh.categories).get();
        expect(
          freshCats,
          isNotEmpty,
          reason: 'Debe sembrar categorías de fábrica en instalación nueva',
        );
        expect(freshCats.length, equals(15));

        final freshKeywords =
            await dbFresh.select(dbFresh.categoryKeywords).get();
        expect(
          freshKeywords,
          isNotEmpty,
          reason: 'Debe sembrar palabras clave de fábrica',
        );

        // 2. Base PowerSync con legacy migrado
        final fixtureFile = File('test/fixtures/pockt_v16_demo.db');
        final legacyDbPath = p.join(tempDir.path, 'pockt_legacy_for_seed.db');
        fixtureFile.copySync(legacyDbPath);
        await ensureLegacyDbMigrated(legacyDbPath);

        final targetDbPath = p.join(tempDir.path, 'powersync_with_legacy.db');
        final psTarget = ps.PowerSyncDatabase(
          schema: pocktPowerSyncSchema,
          path: targetDbPath,
        );
        await psTarget.initialize();
        addTearDown(psTarget.close);

        await migrateLegacyDriftDb(oldDbPath: legacyDbPath, target: psTarget);

        final catsBefore =
            await psTarget.get('SELECT count(*) as c FROM categories');
        final kwBefore =
            await psTarget.get('SELECT count(*) as c FROM category_keywords');

        final dbTarget = AppDatabase.powerSync(psTarget);
        addTearDown(dbTarget.close);

        final catsAfter = await dbTarget.select(dbTarget.categories).get();
        final kwAfter = await dbTarget.select(dbTarget.categoryKeywords).get();

        expect(
          catsAfter.length,
          equals(catsBefore['c']),
          reason: 'No debe duplicar categorías migradas',
        );
        expect(
          kwAfter.length,
          equals(kwBefore['c']),
          reason: 'No debe duplicar palabras clave migradas',
        );
      },
    );

    test(
      '(g) deduplicación en PowerSync: sugerencia recurrente, SMS y correo duplicados no crean filas extra',
      () async {
        final psPath = p.join(tempDir.path, 'powersync_dedupe.db');
        final psDb = ps.PowerSyncDatabase(
          schema: pocktPowerSyncSchema,
          path: psPath,
        );
        await psDb.initialize();
        addTearDown(psDb.close);

        final db = AppDatabase.powerSync(psDb);
        addTearDown(db.close);

        // Asegurar que la categoría para pruebas existe
        await psDb.execute(
          'INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order, archived) '
          "VALUES ('cat-dedupe', 'Comida', 'tag', 0, 0, 'expense', 1, 0)",
        );

        final suggestionsRepo = SuggestionsRepository(db);
        final txRepo = TransactionsRepository(db);
        final settingsRepo = SettingsRepository(db);
        final loansRepo = LoansRepository(db);
        final rulesRepo = CounterpartyRulesRepository(db);
        final notifier = FakeNotifier();

        // 1. Sugerencia recurrente: doble llamada con mismo (source, sourceRef, occurredAt)
        final recurringDate = DateTime.utc(2026, 10, 20, 10, 0);
        final firstCreated = await suggestionsRepo.createIfAbsent(
          type: TxType.expense,
          amount: 50000,
          categoryId: 'cat-dedupe',
          merchant: 'Alquiler',
          occurredAt: recurringDate,
          source: TxSource.recurring,
          sourceRef: 'rule-test-1',
        );
        final secondCreated = await suggestionsRepo.createIfAbsent(
          type: TxType.expense,
          amount: 50000,
          categoryId: 'cat-dedupe',
          merchant: 'Alquiler',
          occurredAt: recurringDate,
          source: TxSource.recurring,
          sourceRef: 'rule-test-1',
        );
        expect(firstCreated, isTrue);
        expect(secondCreated, isFalse);

        final recurringSugs = await (db.select(db.suggestedTransactions)
              ..where((s) => s.sourceRef.equals('rule-test-1')))
            .get();
        expect(recurringSugs.length, equals(1));

        // 2. Captura SMS: procesar el mismo SMS dos veces
        final smsSource = FakeSmsSource();
        final smsService = CaptureService(
          db: db,
          notifier: notifier,
          smsSource: smsSource,
          suggestionsRepository: suggestionsRepo,
          settingsRepository: settingsRepo,
        );

        const smsBody =
            'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****35.000 por PIZZA HUT-MULTIPLAZA al 15/10/2026 12:15:51';
        final rawSms = RawSms(
          sender: '4828',
          body: smsBody,
          receivedAt: DateTime.utc(2026, 10, 15, 12, 16),
        );

        final smsCount1 = await smsService.ingest([rawSms]);
        final smsCount2 = await smsService.ingest([rawSms]);

        expect(smsCount1, equals(1));
        expect(smsCount2, equals(0));

        final smsSugs = await (db.select(db.suggestedTransactions)
              ..where((s) => s.amount.equals(35000)))
            .get();
        expect(smsSugs.length, equals(1));

        // 3. Captura Email: procesar el mismo correo dos veces
        final emailSource = FakeEmailSource();
        final emailService = EmailCaptureService(
          db: db,
          notifier: notifier,
          source: emailSource,
          suggestionsRepository: suggestionsRepo,
          transactionsRepository: txRepo,
          loansRepository: loansRepo,
          counterpartyRulesRepository: rulesRepo,
          settingsRepository: settingsRepo,
        );

        final rawEmail = RawEmail(
          id: 'email-dedupe-1',
          receivedAt: DateTime.utc(2026, 10, 16, 10, 0),
          subject: 'Aviso de transferencia recibida',
          bodyText: '''
Nro. de operación: | 000000000099999 |
Fecha y hora de operación: | 16/10/2026 10:00:00 |
Cliente Pagador: | JUAN PEREZ |
Moneda y Monto: | PYG 120,000 |
''',
        );

        final emailCount1 = await emailService.ingest([rawEmail]);
        final emailCount2 = await emailService.ingest([rawEmail]);

        expect(emailCount1, equals(1));
        expect(emailCount2, equals(0));

        final emailSugs = await (db.select(db.suggestedTransactions)
              ..where(
                (s) => s.fingerprint.equals(
                  'email:email-dedupe-1',
                ),
              ))
            .get();
        expect(emailSugs.length, equals(1));

        // 4. CounterpartyRules: upsert duplicado
        await rulesRepo.upsert(
          nameKey: 'JUAN PEREZ',
          direction: TransferDirection.incoming,
          action: CounterpartyAction.income,
          categoryId: 'cat-dedupe',
        );
        await rulesRepo.upsert(
          nameKey: 'JUAN PEREZ',
          direction: TransferDirection.incoming,
          action: CounterpartyAction.income,
          categoryId: 'cat-dedupe',
        );
        final rules = await (db.select(db.counterpartyRules)
              ..where((r) => r.nameKey.equals('JUAN PEREZ')))
            .get();
        expect(rules.length, equals(1));
      },
    );

    test(
      '(h) migraciones futuras en PowerSync: user_version viejo no falla con ALTER TABLE y sube versión',
      () async {
        final psPath = p.join(tempDir.path, 'powersync_upgrade.db');
        final psDb = ps.PowerSyncDatabase(
          schema: pocktPowerSyncSchema,
          path: psPath,
        );
        await psDb.initialize();
        addTearDown(psDb.close);

        // Simular que la base PowerSync fue creada en una versión previa (ej: 13)
        await psDb.execute('PRAGMA user_version = 13;');
        final vBefore = await psDb.get('PRAGMA user_version;');
        expect(vBefore['user_version'], equals(13));

        final db = AppDatabase.powerSync(psDb);
        addTearDown(db.close);

        // Al ejecutar una consulta, Drift dispara onUpgrade(16, 17)
        final result = await db.customSelect('SELECT 1 as val').getSingle();
        expect(result.read<int>('val'), equals(1));

        final vAfter = await psDb.get('PRAGMA user_version;');
        expect(vAfter['user_version'], equals(17));
      },
    );

    test(
      '(g) llamadas concurrentes a openPocktPowerSync sin path devuelven la misma instancia sin carrera',
      () async {
        resetSharedPowerSyncDatabase();
        final targetDbPath = p.join(tempDir.path, 'powersync_concurrent.db');
        debugOverridePowerSyncPath = targetDbPath;
        debugOverrideLegacyDriftPath = p.join(tempDir.path, 'non_existent_legacy.db');

        final results = await Future.wait([
          openPocktPowerSync(),
          openPocktPowerSync(),
        ]);
        addTearDown(() async {
          resetSharedPowerSyncDatabase();
          try {
            await results[0].close();
          } catch (_) {}
          try {
            await results[1].close();
          } catch (_) {}
        });

        expect(
          identical(results[0], results[1]),
          isTrue,
          reason: 'Dos llamadas concurrentes deben retornar exactamente la misma instancia de PowerSyncDatabase',
        );
      },
    );

    test(
      '(h) si openPocktPowerSync falla, limpia el future compartido permitiendo reintentar',
      () async {
        resetSharedPowerSyncDatabase();
        // Simular falla con path inválido
        debugOverridePowerSyncPath = '/dev/null/impossible/path/powersync.db';
        debugOverrideLegacyDriftPath = p.join(tempDir.path, 'non_existent_legacy.db');

        try {
          await openPocktPowerSync();
          fail('Debe haber fallado al abrir ruta inválida');
        } catch (_) {}

        // Al cambiar a una ruta válida, debe poder reintentar exitosamente
        final validPath = p.join(tempDir.path, 'powersync_retry.db');
        debugOverridePowerSyncPath = validPath;
        final db = await openPocktPowerSync();
        addTearDown(() async {
          resetSharedPowerSyncDatabase();
          await db.close();
        });

        expect(db.closed, isFalse);
      },
    );
  });
}
