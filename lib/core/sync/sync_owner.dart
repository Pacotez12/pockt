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

  // 1. Si existe el ajuste legado sync.userId distinto del usuario actual, no vincular
  try {
    final settingsRows = await database.getAll(
      "SELECT value FROM settings WHERE key = 'sync.userId'",
    );
    if (settingsRows.isNotEmpty) {
      final legacyUserId = settingsRows.first['value'] as String?;
      if (legacyUserId != null &&
          legacyUserId.isNotEmpty &&
          legacyUserId != currentUserId) {
        throw CrossAccountSyncException(
          message:
              'La base de datos contiene datos de la cuenta anterior ($legacyUserId)',
          expectedUserId: legacyUserId,
          actualUserId: currentUserId,
        );
      }
    }
  } catch (e) {
    if (e is CrossAccountSyncException) rethrow;
    // Si la tabla settings aún no existe, continuar
  }

  // 2. Si hay cambios pendientes en la cola de subida (ps_crud no vacía), no vincular
  try {
    final crudRows = await database.getAll(
      'SELECT count(*) as count FROM ps_crud',
    );
    if (crudRows.isNotEmpty) {
      final count = crudRows.first['count'] as int? ?? 0;
      if (count > 0) {
        throw CrossAccountSyncException(
          message:
              'La base de datos contiene cambios pendientes sin sincronizar de otra sesión',
          expectedUserId: 'unknown_prior_user',
          actualUserId: currentUserId,
        );
      }
    }
  } catch (e) {
    if (e is CrossAccountSyncException) rethrow;
    // Si la tabla ps_crud aún no existe, no hay cola pendiente
  }

  // Flujo normal de primer uso real (sin legado en conflicto y sin cola pendiente)
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
