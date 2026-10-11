import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:pockt/features/backup/data/backup_store.dart';
import 'package:pockt/features/backup/data/drive_backup_store.dart';

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

  group('DriveBackupStore con DriveApi simulado', () {
    late _FakeDriveHttpClient fakeClient;
    late DriveBackupStore store;

    setUp(() {
      fakeClient = _FakeDriveHttpClient();
      final driveApi = drive.DriveApi(fakeClient);
      store = DriveBackupStore(driveApi: driveApi);
    });

    test('upload crea la carpeta si no existe y sube el archivo', () async {
      final sampleBytes = [1, 2, 3, 4];
      await store.upload('backup-1.pockt', sampleBytes);

      expect(fakeClient.folderCreated, isTrue);
      expect(fakeClient.files.length, equals(1));
      final uploaded = fakeClient.files.values.first;
      expect(uploaded.name, equals('backup-1.pockt'));
      expect(uploaded.bytes, equals(sampleBytes));
    });

    test('list devuelve los archivos ordenados', () async {
      final sampleBytes = [1, 2, 3];
      await store.upload('backup-1.pockt', sampleBytes);

      final list = await store.list();
      expect(list.length, equals(1));
      expect(list.first.name, equals('backup-1.pockt'));
      expect(list.first.sizeBytes, equals(3));
    });

    test('download descarga los bytes exactos', () async {
      await store.upload('backup-1.pockt', [10, 20, 30]);
      final list = await store.list();
      final id = list.first.id;

      final downloaded = await store.download(id);
      expect(downloaded, equals([10, 20, 30]));
    });

    test('delete elimina el archivo de Drive', () async {
      await store.upload('backup-1.pockt', [10]);
      var list = await store.list();
      final id = list.first.id;

      await store.delete(id);
      list = await store.list();
      expect(list, isEmpty);
    });

    test('reutiliza la carpeta si ya existe previamente', () async {
      fakeClient.folderId = 'existing-folder-id';
      fakeClient.folderCreated = false;

      await store.upload('backup-existing.pockt', [5, 6]);

      expect(fakeClient.folderCreated, isFalse);
      expect(fakeClient.files.values.first.parentId, equals('existing-folder-id'));
    });

    test('en modo no interactivo sin sesión lanza DriveAuthRequiredException', () async {
      final bgStore = DriveBackupStore(interactive: false);
      expect(
        () => bgStore.upload('test.pockt', [1, 2, 3]),
        throwsA(isA<DriveAuthRequiredException>()),
      );
    });
  });
}

class _FakeDriveHttpClient extends http.BaseClient {
  final Map<String, ({String name, String parentId, List<int> bytes, DateTime createdTime})> files = {};
  bool folderCreated = false;
  String? folderId;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;
    final path = uri.path;

    if (request.method == 'GET' && path == '/drive/v3/files') {
      final q = uri.queryParameters['q'] ?? '';
      if (q.contains("mimeType = 'application/vnd.google-apps.folder'")) {
        if (folderId != null) {
          final body = jsonEncode({
            'files': [
              {'id': folderId, 'name': 'Pockt · Backups'}
            ]
          });
          return http.StreamedResponse(
            Stream.value(utf8.encode(body)),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else {
          final body = jsonEncode({'files': <Map<String, dynamic>>[]});
          return http.StreamedResponse(
            Stream.value(utf8.encode(body)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
      } else if (q.contains('in parents')) {
        final fileEntries = files.entries.map((e) => {
          'id': e.key,
          'name': e.value.name,
          'createdTime': e.value.createdTime.toUtc().toIso8601String(),
          'size': e.value.bytes.length.toString(),
        }).toList();
        final body = jsonEncode({'files': fileEntries});
        return http.StreamedResponse(
          Stream.value(utf8.encode(body)),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
    }

    if (request.method == 'POST' && path == '/drive/v3/files') {
      folderId = 'folder-pockt-id';
      folderCreated = true;
      final body = jsonEncode({'id': folderId});
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (request.method == 'POST' && path == '/upload/drive/v3/files') {
      final id = 'drive-id-${files.length + 1}';
      final bodyBytes = await request.finalize().toBytes();

      // Encontrar metadatos y payload binario en la petición multipart
      String fileName = 'backup.pockt';
      List<int> fileData = [];

      final bodyStr = utf8.decode(bodyBytes, allowMalformed: true);
      final nameMatch = RegExp(r'"name":\s*"([^"]+)"').firstMatch(bodyStr);
      if (nameMatch != null) {
        fileName = nameMatch.group(1)!;
      }

      // Separador multipart "\r\n\r\n"
      // Parte 1: cabeceras del primer part
      // Parte 2: cuerpo json (metadatos)
      // Parte 3: cuerpo del archivo
      final boundaryMatch = RegExp(r'--([^\r\n]+)').firstMatch(bodyStr);
      if (boundaryMatch != null) {
        final boundary = boundaryMatch.group(1)!;
        final delimiter = utf8.encode('--$boundary');
        final headerEnd = utf8.encode('\r\n\r\n');

        // Buscar partes
        int index = 0;
        final parts = <List<int>>[];
        while (index < bodyBytes.length) {
          final nextDelim = _indexOf(bodyBytes, delimiter, index);
          if (nextDelim == -1) break;
          if (index > 0) {
            parts.add(bodyBytes.sublist(index, nextDelim));
          }
          index = nextDelim + delimiter.length;
        }

        if (parts.length >= 2) {
          // La segunda parte contiene el archivo binario
          final filePart = parts[1];
          final bodyStart = _indexOf(filePart, headerEnd, 0);
          if (bodyStart != -1) {
            var content = filePart.sublist(bodyStart + headerEnd.length);
            // Quitar \r\n final antes del delimitador si está presente
            if (content.length >= 2 && content[content.length - 2] == 13 && content[content.length - 1] == 10) {
              content = content.sublist(0, content.length - 2);
            }
            try {
              fileData = base64.decode(utf8.decode(content).trim());
            } catch (_) {
              fileData = content;
            }
          }
        }
      }

      files[id] = (
        name: fileName,
        parentId: folderId ?? 'root',
        bytes: fileData,
        createdTime: DateTime.now(),
      );

      final body = jsonEncode({'id': id});
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (request.method == 'GET' && path.startsWith('/drive/v3/files/')) {
      final id = path.split('/').last;
      final file = files[id];
      if (file != null) {
        return http.StreamedResponse(
          Stream.value(file.bytes),
          200,
          headers: {'content-type': 'application/octet-stream'},
        );
      } else {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"error": "not found"}')),
          404,
          headers: {'content-type': 'application/json'},
        );
      }
    }

    if (request.method == 'DELETE' && path.startsWith('/drive/v3/files/')) {
      final id = path.split('/').last;
      files.remove(id);
      return http.StreamedResponse(
        Stream.value(<int>[]),
        204,
      );
    }

    return http.StreamedResponse(Stream.value(<int>[]), 404);
  }

  int _indexOf(List<int> source, List<int> pattern, int start) {
    if (pattern.isEmpty) return start;
    for (int i = start; i <= source.length - pattern.length; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (source[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }
}
