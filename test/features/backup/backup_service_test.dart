import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/backup/data/backup_store.dart';
import 'package:pockt/features/backup/data/key_storage.dart';
import 'package:pockt/features/backup/domain/backup_format.dart';
import 'package:pockt/features/backup/domain/backup_service.dart';
import 'package:pockt/features/transactions/data/categories_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase db;
  late MemoryBackupStore store;
  late KeyStorage keys;
  late SettingsRepository settings;
  late BackupService service;
  var currentTime = DateTime(2026, 10, 10, 10, 0);

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    currentTime = DateTime(2026, 10, 10, 10, 0);
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    store = MemoryBackupStore(clock: () => currentTime);
    keys = KeyStorage.inMemory();
    settings = SettingsRepository(db);

    service = BackupService(
      db: db,
      store: store,
      keys: keys,
      settings: settings,
      clock: () => currentTime,
      // Parámetros Argon2 ultrarrápidos para test unitario
      argonIterations: 1,
      argonMemoryInKiB: 1024,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('BackupService', () {
    test('sin contraseña -> noPassword sin subir nada', () async {
      final result = await service.backupNow();
      expect(result, equals(BackupResult.noPassword));

      final uploaded = await store.list();
      expect(uploaded, isEmpty);

      final status = await service.watchStatus().first;
      expect(status.lastError, equals(BackupResult.noPassword));
      expect(status.lastSuccessAt, isNull);
    });

    test('backupNow sube un .pockt que se descifra a la misma base', () async {
      // 1. Configurar contraseña
      await service.setPassword('super-secret-123');

      // 2. Agregar un movimiento a la base
      final catRepo = CategoriesRepository(db);
      final txRepo = TransactionsRepository(db);
      final cat = (await catRepo.watchActive(CategoryKind.expense).first).first;

      await txRepo.add(
        type: TxType.expense,
        amount: 85000,
        categoryId: cat.id,
        occurredAt: DateTime(2026, 10, 10, 8, 30),
        note: 'Supermercado',
      );

      // 3. Ejecutar backupNow
      final result = await service.backupNow();
      expect(result, equals(BackupResult.success));

      final list = await store.list();
      expect(list.length, equals(1));
      expect(list.first.name, startsWith('pockt-'));
      expect(list.first.name, endsWith('.pockt'));

      // 4. Descargar bytes y verificar que descifran la base intacta
      final pocktBytes = await store.download(list.first.id);
      final keyData = (await keys.load())!;
      final decryptedDbBytes = await decodeBackup(
        pocktBytes,
        keyFor: (salt) async => SecretKey(keyData.key),
      );

      // Abrir base descifrada en memoria y verificar movimiento
      final tempDir = await Directory.systemTemp.createTemp('pockt_backup_verify_');
      final tempDbFile = File('${tempDir.path}/restored.db');
      await tempDbFile.writeAsBytes(decryptedDbBytes);

      final restoredDb = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase(tempDbFile), closeStreamsSynchronously: true),
      );
      final restoredTx = await (restoredDb.select(restoredDb.transactions)).get();
      expect(restoredTx.length, equals(1));
      expect(restoredTx.first.amount, equals(85000));
      expect(restoredTx.first.note, equals('Supermercado'));

      await restoredDb.close();
      await tempDir.delete(recursive: true);

      // 5. Verificar estado
      final status = await service.watchStatus().first;
      expect(status.lastError, isNull);
      expect(status.lastSuccessAt, equals(currentTime));
      expect(status.isOverdue, isFalse);
    });

    test('con 8 backups previos quedan 7 (se borra el más viejo)', () async {
      await service.setPassword('password-123');

      // Crear 8 backups simulados espaciados en el tiempo
      for (int i = 0; i < 8; i++) {
        currentTime = currentTime.add(const Duration(hours: 12));
        final result = await service.backupNow();
        expect(result, equals(BackupResult.success));
      }

      final list = await store.list();
      expect(list.length, equals(7));

      // El más reciente debe coincidir con currentTime
      expect(list.first.createdAt, equals(currentTime));
    });

    test('isOverdue a los 5 días', () async {
      await service.setPassword('password-123');

      // Backup inicial
      await service.backupNow();

      var status = await service.watchStatus().first;
      expect(status.isOverdue, isFalse);

      // Avanzar 4 días y 23 horas -> no está vencido aún
      currentTime = currentTime.add(const Duration(days: 4, hours: 23));
      status = await service.watchStatus().first;
      expect(status.isOverdue, isFalse);

      // Avanzar a 5 días exactos -> isOverdue = true
      currentTime = currentTime.add(const Duration(hours: 1));
      status = await service.watchStatus().first;
      expect(status.isOverdue, isTrue);
    });

    test('una falla al guardar se registra como storage', () async {
      await service.setPassword('pwd-123');
      final failService = BackupService(
        db: db,
        store: _ErrorBackupStore(const FileSystemException('Sin espacio')),
        keys: keys,
        settings: settings,
        clock: () => currentTime,
      );

      expect(await failService.backupNow(), BackupResult.storage);
      final status = await failService.watchStatus().first;
      expect(status.lastError, BackupResult.storage);
    });

    test('backupIfDue: nada sin contraseña; corre si nunca hubo o pasaron 48 h', () async {
      expect(await service.backupIfDue(), isNull);

      await service.setPassword('pwd-123');
      expect(await service.backupIfDue(), BackupResult.success);

      currentTime = currentTime.add(const Duration(hours: 47));
      expect(await service.backupIfDue(), isNull);

      currentTime = currentTime.add(const Duration(hours: 2));
      expect(await service.backupIfDue(), BackupResult.success);
      expect(await store.list(), hasLength(2));
    });

    test('sin ningún backup el estado figura atrasado', () async {
      final status = await service.watchStatus().first;
      expect(status.isOverdue, isTrue);
    });

    test('buildExport devuelve un .pockt sin guardarlo', () async {
      expect(await service.buildExport(), isNull);
      await service.setPassword('pwd-123');
      final export = await service.buildExport();
      expect(export!.name, endsWith('.pockt'));
      expect(export.bytes, isNotEmpty);
      expect(await store.list(), isEmpty);
    });
  });
}

class _ErrorBackupStore implements BackupStore {
  final Object error;
  _ErrorBackupStore(this.error);

  @override
  Future<void> upload(String name, List<int> bytes) async => throw error;

  @override
  Future<List<RemoteBackup>> list() async => [];

  @override
  Future<List<int>> download(String id) async => throw error;

  @override
  Future<void> delete(String id) async => throw error;
}
