import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pockt/features/backup/data/backup_store.dart';
import 'package:pockt/features/backup/domain/backup_format.dart';
import 'package:pockt/features/backup/domain/restore_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MemoryBackupStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pockt_restore_block_test_');
    store = MemoryBackupStore();
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<List<int>> createValidBackupBytes() async {
    final salt = generateSalt();
    final key = await deriveKey('test-pass', salt, memory: 1024, iterations: 1);
    final dummySqlite = [1, 2, 3, 4, 5];
    return encodeBackup(dummySqlite, key, salt);
  }

  test(
    'RestoreService con beforeRestore bloquea preventivamente antes de cerrar base o resolver/modificar archivos',
    () async {
      final targetFile = File(p.join(tempDir.path, 'pockt_precious.sqlite'));
      await targetFile.writeAsString('datos-intactos-vitales');

      var closeDatabaseCalled = false;
      var dbFileResolverCalled = false;
      var beforeRestoreCalled = false;

      final service = RestoreService(
        store: store,
        dbFileResolver: () async {
          dbFileResolverCalled = true;
          return targetFile;
        },
        closeDatabase: () async {
          closeDatabaseCalled = true;
        },
        beforeRestore: () async {
          beforeRestoreCalled = true;
          throw const RestoreSafetyException(
            'La restauración está suspendida preventivamente.',
          );
        },
        argonIterations: 1,
        argonMemoryInKiB: 1024,
      );

      final backupBytes = await createValidBackupBytes();

      // Debe lanzar RestoreSafetyException
      await expectLater(
        service.restoreBytes(backupBytes, 'test-pass'),
        throwsA(isA<RestoreSafetyException>()),
      );

      // Verificaciones estrictas de no-interferencia:
      expect(beforeRestoreCalled, isTrue, reason: 'beforeRestore debe invocarse en la primera línea');
      expect(closeDatabaseCalled, isFalse, reason: 'closeDatabase NO debe llamarse si se bloquea preventivamente');
      expect(dbFileResolverCalled, isFalse, reason: 'dbFileResolver NO debe llamarse');

      // El archivo target debe permanecer exactamente intacto
      expect(await targetFile.readAsString(), equals('datos-intactos-vitales'));
      expect(await File('${targetFile.path}.restore_safety_backup').exists(), isFalse);
      expect(await File('${targetFile.path}.restoring').exists(), isFalse);
    },
  );

  test(
    'restoreServiceProvider de producción bloquea restoreBytes con RestoreSafetyException sin tocar base de datos',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(restoreServiceProvider);
      final backupBytes = await createValidBackupBytes();

      await expectLater(
        service.restoreBytes(backupBytes, 'test-pass'),
        throwsA(isA<RestoreSafetyException>()),
      );
    },
  );
}
