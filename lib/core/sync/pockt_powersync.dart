import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pockt/core/sync/migrate_legacy_db.dart';
import 'package:pockt/core/sync/powersync_schema.dart';
import 'package:powersync/powersync.dart';
import 'package:sqlite_async/sqlite_async.dart';

/// Transforma notificaciones de tablas internas de PowerSync (ps_data__ y ps_data_local__)
/// a los nombres de tabla que Drift y sus streams reactivos esperan.
Set<TableUpdate> transformTableUpdates(UpdateNotification notification) {
  final updates = <TableUpdate>{};
  for (final name in notification.tables) {
    updates.add(TableUpdate(name));
    if (name.startsWith('ps_data__')) {
      updates.add(TableUpdate(name.substring('ps_data__'.length)));
    } else if (name.startsWith('ps_data_local__')) {
      updates.add(TableUpdate(name.substring('ps_data_local__'.length)));
    }
  }
  return updates;
}

/// Ruta por defecto para la base de datos PowerSync en el dispositivo.
Future<String> defaultPowerSyncPath() async {
  final dir = await getApplicationSupportDirectory();
  return p.join(dir.path, 'pockt_powersync.db');
}

/// Ruta por defecto para la base de datos Drift legacy.
Future<String> defaultLegacyDriftPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'pockt.sqlite');
}

PowerSyncDatabase? _sharedPowerSyncDatabase;

@visibleForTesting
void resetSharedPowerSyncDatabase() {
  _sharedPowerSyncDatabase = null;
}

/// Abre e inicializa la base de datos PowerSync con [pocktPowerSyncSchema].
///
/// Si existe una base Drift legacy y no ha sido migrada, ejecuta la migración
/// una sola vez antes de retornar.
Future<PowerSyncDatabase> openPocktPowerSync({
  String? path,
  String? legacyDbPath,
}) async {
  if (path == null &&
      _sharedPowerSyncDatabase != null &&
      !_sharedPowerSyncDatabase!.closed) {
    return _sharedPowerSyncDatabase!;
  }

  final resolvedPath = path ?? await defaultPowerSyncPath();
  final db = PowerSyncDatabase(
    schema: pocktPowerSyncSchema,
    path: resolvedPath,
  );
  await db.initialize();

  // Migración desde base legacy si existe
  final legacyPath =
      legacyDbPath ?? (path == null ? await defaultLegacyDriftPath() : null);
  if (legacyPath != null && File(legacyPath).existsSync()) {
    if (!await isMigrationMarkSaved(db)) {
      await ensureLegacyDbMigrated(legacyPath);
      await migrateLegacyDriftDb(oldDbPath: legacyPath, target: db);
    }
  }

  if (path == null) {
    _sharedPowerSyncDatabase = db;
  }
  return db;
}
