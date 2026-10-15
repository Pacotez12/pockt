import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/backup/data/backup_store.dart';

void main() {
  group('BackupStore (contrato MemoryBackupStore)', () {
    late MemoryBackupStore store;
    var currentTime = DateTime(2026, 10, 10, 10, 0);

    setUp(() {
      currentTime = DateTime(2026, 10, 10, 10, 0);
      store = MemoryBackupStore(clock: () => currentTime);
    });

    test('inicialmente la lista está vacía', () async {
      final list = await store.list();
      expect(list, isEmpty);
    });

    test('subir un backup lo almacena y se lista correctamente', () async {
      final sampleBytes = [1, 2, 3, 4, 5];
      await store.upload('pockt-20261010-100000.pockt', sampleBytes);

      final list = await store.list();
      expect(list.length, equals(1));

      final item = list.first;
      expect(item.name, equals('pockt-20261010-100000.pockt'));
      expect(item.sizeBytes, equals(5));
      expect(item.createdAt, equals(currentTime));
      expect(item.id, isNotEmpty);
    });

    test('list ordena los backups por fecha descendente', () async {
      // Subir archivo 1 a las 10:00
      currentTime = DateTime(2026, 10, 10, 10, 0);
      await store.upload('backup-1.pockt', [10]);

      // Subir archivo 2 a las 12:00
      currentTime = DateTime(2026, 10, 10, 12, 0);
      await store.upload('backup-2.pockt', [20, 20]);

      // Subir archivo 3 a las 11:00
      currentTime = DateTime(2026, 10, 10, 11, 0);
      await store.upload('backup-3.pockt', [30, 30, 30]);

      final list = await store.list();
      expect(list.length, equals(3));
      // Debe estar ordenado de más reciente a más antiguo: 12:00, 11:00, 10:00
      expect(list[0].name, equals('backup-2.pockt'));
      expect(list[1].name, equals('backup-3.pockt'));
      expect(list[2].name, equals('backup-1.pockt'));
    });

    test('download devuelve los bytes exactos subidos', () async {
      final sampleBytes = [0x50, 0x4F, 0x43, 0x4B, 0x54, 0x31];
      await store.upload('pockt-test.pockt', sampleBytes);

      final list = await store.list();
      final id = list.first.id;

      final downloaded = await store.download(id);
      expect(downloaded, equals(sampleBytes));
    });

    test('download de un id inexistente lanza excepción', () async {
      expect(
        () => store.download('id-inexistente'),
        throwsException,
      );
    });

    test('delete elimina el archivo de la lista y download falla', () async {
      await store.upload('b1.pockt', [1]);
      await store.upload('b2.pockt', [2]);

      var list = await store.list();
      expect(list.length, equals(2));

      final idToDelete = list.first.id;
      await store.delete(idToDelete);

      list = await store.list();
      expect(list.length, equals(1));
      expect(list.any((f) => f.id == idToDelete), isFalse);

      expect(() => store.download(idToDelete), throwsException);
    });

    test('RemoteBackup soporta comparación por igualdad', () {
      final b1 = RemoteBackup(
        id: '1',
        name: 'test.pockt',
        createdAt: DateTime(2026, 10, 10),
        sizeBytes: 100,
      );
      final b2 = RemoteBackup(
        id: '1',
        name: 'test.pockt',
        createdAt: DateTime(2026, 10, 10),
        sizeBytes: 100,
      );
      final b3 = RemoteBackup(
        id: '2',
        name: 'test.pockt',
        createdAt: DateTime(2026, 10, 10),
        sizeBytes: 100,
      );

      expect(b1, equals(b2));
      expect(b1.hashCode, equals(b2.hashCode));
      expect(b1, isNot(equals(b3)));
    });
  });


}
