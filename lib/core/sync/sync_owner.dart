import 'package:powersync/powersync.dart';

/// Excepción lanzada cuando se intenta sincronizar o subir datos de una base local
/// vinculada a otra cuenta de usuario distinta.
class CrossAccountSyncException implements Exception {
  final String message;
  final String expectedUserId;
  final String actualUserId;

  const CrossAccountSyncException({
    required this.message,
    required this.expectedUserId,
    required this.actualUserId,
  });

  @override
  String toString() =>
      'CrossAccountSyncException: $message (dueño: $expectedUserId, sesión: $actualUserId)';
}

/// Obtiene el ID del usuario propietario de la base de datos local [database].
///
/// La tabla `_pockt_sync_owner` es una tabla SQLite puramente local
/// (no forma parte de `pocktPowerSyncSchema`), por lo que nunca se sincroniza
/// a la nube ni se sobrescribe por datos remotos o restauraciones.
Future<String?> getSyncOwner(PowerSyncDatabase database) async {
  await database.execute(
    'CREATE TABLE IF NOT EXISTS _pockt_sync_owner (id TEXT PRIMARY KEY, user_id TEXT, bound_at INTEGER);',
  );
  final rows = await database.getAll(
    'SELECT user_id FROM _pockt_sync_owner WHERE id = ?',
    ['owner'],
  );
  if (rows.isEmpty) return null;
  return rows.first['user_id'] as String?;
}

/// Vincula atómicamente la base de datos local [database] al usuario [userId]
/// solo si no estaba vinculada previamente (concurrencia segura).
///
/// Utiliza `INSERT OR IGNORE` (nunca `INSERT OR REPLACE`) para que ante carreras
/// concurrentes la primera vinculación sea definitiva. Devuelve el `user_id` ganador.
Future<String> setSyncOwnerIfAbsent(PowerSyncDatabase database, String userId) async {
  await database.execute(
    'CREATE TABLE IF NOT EXISTS _pockt_sync_owner (id TEXT PRIMARY KEY, user_id TEXT, bound_at INTEGER);',
  );
  await database.execute(
    'INSERT OR IGNORE INTO _pockt_sync_owner (id, user_id, bound_at) VALUES (?, ?, ?);',
    ['owner', userId, DateTime.now().millisecondsSinceEpoch],
  );
  final rows = await database.getAll(
    'SELECT user_id FROM _pockt_sync_owner WHERE id = ?',
    ['owner'],
  );
  return rows.first['user_id'] as String;
}

/// Vincula la base de datos local [database] al usuario [userId] si está vacía.
Future<String> setSyncOwner(PowerSyncDatabase database, String userId) =>
    setSyncOwnerIfAbsent(database, userId);

/// Resuelve el propietario de la base local [database] para la sesión autenticada [currentUserId].
///
/// Reglas de seguridad:
/// 1. Si `_pockt_sync_owner` ya existe: es la única fuente de verdad local inmutable.
///    Si no coincide con [currentUserId], lanza [CrossAccountSyncException].
/// 2. Si `_pockt_sync_owner` está vacío: flujo normal de primera cuenta local
///    (usuario offline que inicia sesión por primera vez); se vincula atómicamente con `INSERT OR IGNORE`.
Future<String> resolveOrMigrateSyncOwner(
  PowerSyncDatabase database,
  String currentUserId,
) async {
  final localOwner = await getSyncOwner(database);
  if (localOwner != null) {
    if (localOwner != currentUserId) {
      throw CrossAccountSyncException(
        message: 'La base de datos local está vinculada a otro usuario ($localOwner)',
        expectedUserId: localOwner,
        actualUserId: currentUserId,
      );
    }
    return localOwner;
  }

  // Flujo normal de primera cuenta local
  final winningOwner = await setSyncOwnerIfAbsent(database, currentUserId);
  if (winningOwner != currentUserId) {
    throw CrossAccountSyncException(
      message: 'Carrera concurrente al vincular propietario local',
      expectedUserId: winningOwner,
      actualUserId: currentUserId,
    );
  }
  return winningOwner;
}
