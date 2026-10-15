import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/backup/data/local_backup_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pockt/backup_files');
  final files = <String, ({String name, Uint8List bytes, int modified})>{};
  var counter = 0;

  setUp(() {
    files.clear();
    counter = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, Object?>();
      switch (call.method) {
        case 'save':
          final id = 'content://pockt/${++counter}';
          files[id] = (name: args!['name'] as String, bytes: args['bytes'] as Uint8List, modified: counter * 1000);
          return id;
        case 'list':
          return [
            for (final e in files.entries)
              {'id': e.key, 'name': e.value.name, 'size': e.value.bytes.length, 'modified': e.value.modified},
          ];
        case 'read':
          return files[args!['id']]!.bytes;
        case 'delete':
          files.remove(args!['id']);
          return null;
        case 'pickFile':
          return {'name': 'externo.pockt', 'bytes': Uint8List.fromList([9, 9])};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('guarda, lista de la más nueva a la más vieja, lee y borra', () async {
    final store = LocalBackupStore();
    await store.upload('a.pockt', [1, 2, 3]);
    await store.upload('b.pockt', [4, 5]);

    final list = await store.list();
    expect(list.map((b) => b.name), ['b.pockt', 'a.pockt']);
    expect(list.first.sizeBytes, 2);

    expect(await store.download(list.last.id), [1, 2, 3]);
    await store.delete(list.first.id);
    expect((await store.list()).map((b) => b.name), ['a.pockt']);
  });

  test('elegir archivo devuelve nombre y bytes', () async {
    final picked = await LocalBackupStore().pickFile();
    expect(picked!.name, 'externo.pockt');
    expect(picked.bytes, [9, 9]);
  });
}
