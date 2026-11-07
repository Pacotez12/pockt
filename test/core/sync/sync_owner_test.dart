import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pockt/core/sync/powersync_schema.dart';
import 'package:pockt/core/sync/sync_owner.dart';
import 'package:powersync/powersync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PowerSyncDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pockt_sync_owner_test_');
    db = PowerSyncDatabase(
      schema: pocktPowerSyncSchema,
      path: p.join(tempDir.path, 'owner_test.db'),
    );
    await db.initialize();
  });

  tearDown(() async {
    try {
      await db.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('sync_owner', () {
    test('getSyncOwner devuelve null en base nueva sin dueño', () async {
      expect(await getSyncOwner(db), isNull);
    });

    test('resolveOrMigrateSyncOwner vincula la primera cuenta si está vacía', () async {
      final owner = await resolveOrMigrateSyncOwner(db, 'user-first');
      expect(owner, equals('user-first'));
      expect(await getSyncOwner(db), equals('user-first'));
    });

    test('resolveOrMigrateSyncOwner devuelve el dueño actual si coincide', () async {
      await setSyncOwnerIfAbsent(db, 'user-existing');
      final owner = await resolveOrMigrateSyncOwner(db, 'user-existing');
      expect(owner, equals('user-existing'));
    });

    test('resolveOrMigrateSyncOwner lanza CrossAccountSyncException si la cuenta es distinta', () async {
      await setSyncOwnerIfAbsent(db, 'user-original');
      await expectLater(
        resolveOrMigrateSyncOwner(db, 'user-intruder'),
        throwsA(isA<CrossAccountSyncException>()),
      );
    });

    test('el dueño se resuelve solo con _pockt_sync_owner y no lee settings sync.userId', () async {
      // Si settings tuviera un sync.userId legacy pero _pockt_sync_owner está vacío,
      // se vincula la primera cuenta directamente (sin bloquear ni migrar desde settings).
      await db.execute(
        "INSERT INTO settings (id, key, value) VALUES ('1', 'sync.userId', 'user-legacy')",
      );
      expect(await getSyncOwner(db), isNull);

      final owner = await resolveOrMigrateSyncOwner(db, 'user-new');
      expect(owner, equals('user-new'));
      expect(await getSyncOwner(db), equals('user-new'));
    });
  });
}
