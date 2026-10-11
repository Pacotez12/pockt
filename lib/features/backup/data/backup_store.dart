import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Metadatos de una copia de respaldo remota.
class RemoteBackup {
  final String id;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;

  const RemoteBackup({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteBackup &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          createdAt == other.createdAt &&
          sizeBytes == other.sizeBytes;

  @override
  int get hashCode => Object.hash(id, name, createdAt, sizeBytes);

  @override
  String toString() =>
      'RemoteBackup(id: $id, name: $name, createdAt: $createdAt, sizeBytes: $sizeBytes)';
}

/// Contrato para el almacenamiento remoto de copias de seguridad de Pockt.
abstract class BackupStore {
  /// Sube un archivo con el [name] y [bytes] especificados.
  Future<void> upload(String name, List<int> bytes);

  /// Lista los backups disponibles, ordenados por fecha de creación descendente (más reciente primero).
  Future<List<RemoteBackup>> list();

  /// Descarga los bytes del backup con el [id] especificado.
  Future<List<int>> download(String id);

  /// Borra el backup con el [id] especificado.
  Future<void> delete(String id);
}

/// Implementación en memoria de [BackupStore] para pruebas unitarias.
class MemoryBackupStore implements BackupStore {
  final Map<String, ({RemoteBackup metadata, List<int> bytes})> _files = {};
  int _counter = 0;

  DateTime Function() clock;

  MemoryBackupStore({DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  @override
  Future<void> upload(String name, List<int> bytes) async {
    final id = 'mem-${++_counter}';
    final metadata = RemoteBackup(
      id: id,
      name: name,
      createdAt: clock(),
      sizeBytes: bytes.length,
    );
    _files[id] = (metadata: metadata, bytes: List<int>.from(bytes));
  }

  @override
  Future<List<RemoteBackup>> list() async {
    final list = _files.values.map((f) => f.metadata).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<int>> download(String id) async {
    final file = _files[id];
    if (file == null) {
      throw Exception('Backup no encontrado: $id');
    }
    return List<int>.from(file.bytes);
  }

  @override
  Future<void> delete(String id) async {
    _files.remove(id);
  }
}

/// Provider para la interfaz de almacenamiento de backups. Por defecto puede
/// configurarse en DriveBackupStore o sobreescribirse con MemoryBackupStore en tests.
final backupStoreProvider = Provider<BackupStore>((ref) {
  return MemoryBackupStore();
});
