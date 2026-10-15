
import 'package:flutter/services.dart';
import 'package:pockt/features/backup/data/backup_store.dart';

/// Copias `.pockt` en Documentos/Pockt del teléfono, vía el canal nativo
/// `pockt/backup_files` (MainActivity → BackupFiles.kt). La carpeta es
/// visible y sobrevive a desinstalar la app.
class LocalBackupStore implements BackupStore {
  final MethodChannel _channel;

  LocalBackupStore({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('pockt/backup_files');

  @override
  Future<void> upload(String name, List<int> bytes) async {
    await _channel.invokeMethod<String>(
      'save',
      {'name': name, 'bytes': Uint8List.fromList(bytes)},
    );
  }

  @override
  Future<List<RemoteBackup>> list() async {
    final raw = await _channel.invokeListMethod<Map>('list') ?? const [];
    final items = [
      for (final m in raw)
        RemoteBackup(
          id: m['id'] as String,
          name: m['name'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch((m['modified'] as num).toInt()),
          sizeBytes: (m['size'] as num).toInt(),
        ),
    ];
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<List<int>> download(String id) async {
    final bytes = await _channel.invokeMethod<Uint8List>('read', {'id': id});
    if (bytes == null) throw Exception('No se pudo leer la copia');
    return bytes;
  }

  @override
  Future<void> delete(String id) =>
      _channel.invokeMethod<void>('delete', {'id': id});

  /// Abre el selector de archivos de Android; `null` si se canceló.
  Future<({String name, List<int> bytes})?> pickFile() async {
    final m = await _channel.invokeMapMethod<String, Object?>('pickFile');
    if (m == null) return null;
    return (name: m['name'] as String, bytes: m['bytes'] as Uint8List);
  }
}
