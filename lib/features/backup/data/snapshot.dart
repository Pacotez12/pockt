import 'dart:io';

import 'package:pockt/core/db/app_database.dart';

/// Crea una instantánea consistente de la base de datos [db] usando `VACUUM INTO`
/// hacia un archivo temporal y devuelve los bytes generados, limpiando el temporal.
Future<List<int>> snapshotDatabase(AppDatabase db) async {
  final tempDir = await Directory.systemTemp.createTemp('pockt_snapshot_');
  final tempFile = File('${tempDir.path}/snapshot.db');

  try {
    // Escapar comillas simples en la ruta para la sentencia SQLite
    final escapedPath = tempFile.path.replaceAll("'", "''");
    await db.customStatement("VACUUM INTO '$escapedPath'");
    return await tempFile.readAsBytes();
  } finally {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}
