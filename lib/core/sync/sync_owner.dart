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

/// Lee el valor de `sync.userId` almacenado en la tabla `settings` (usado en c0ffd70).
/// Devuelve null si la tabla no existe en `sqlite_master` o la clave no está presente.
///
/// Falla cerrado: los errores de base de datos o I/O no se enmascaran ni devuelven null,
/// propagándose para evitar que un fallo de lectura permita vincular la base a otra cuenta.
Future<String?> getLegacySyncUserId(PowerSyncDatabase database) async {
  final tableCheck = await database.getAll(
    "SELECT 1 FROM sqlite_master WHERE type IN ('table', 'view') AND name = 'settings'",
  );
  if (tableCheck.isEmpty) return null;
  final rows = await database.getAll(
    'SELECT value FROM settings WHERE key = ?',
    ['sync.userId'],
  );
  if (rows.isEmpty) return null;
  final val = rows.first['value'] as String?;
  return (val != null && val.isNotEmpty) ? val : null;
}

/// Resuelve o migra conservadoramente el propietario de la base local [database]
/// para la sesión autenticada [currentUserId].
///
/// Reglas de seguridad:
/// 1. Si `_pockt_sync_owner` ya existe: es la única fuente de verdad local inmutable.
///    Si no coincide con [currentUserId], lanza [CrossAccountSyncException].
/// 2. Si `_pockt_sync_owner` está vacío pero `settings` tiene un `sync.userId` previo (c0ffd70):
///    - Si [currentUserId] no coincide con el usuario previo: se BLOQUEA estrictamente.
///      No se permite enlazar ciegamente una base existente a una cuenta distinta.
///    - Si [currentUserId] coincide: se migra atómicamente a `_pockt_sync_owner`.
/// 3. Si ambos están vacíos: flujo normal de primera cuenta local (usuario offline
///    que inicia sesión por primera vez); se vincula atómicamente con `INSERT OR IGNORE`.
///
/// Alcance y limitaciones documentadas de seguridad:
/// - **Limitación inherente en bases antiguas (c0ffd70):**
///   En c0ffd70, `sync.userId` se persistía en la tabla `settings`, la cual forma
///   parte del esquema sincronizable de PowerSync y pudo haber sido modificada,
///   sincronizada desde la nube o restaurada en el pasado. Por ende, la coincidencia
///   entre la sesión activa y `settings.sync.userId` NO constituye una prueba
///   criptográfica de identidad histórica del contenido local, sino una heurística
///   conservadora de mejor esfuerzo para no bloquear a usuarios legítimos de c0ffd70.
///   La protección estricta e inviolable (aislamiento fuera de sincronización e
///   inmutabilidad local con `INSERT OR IGNORE`) rige plenamente una vez establecido
///   `_pockt_sync_owner`.
/// - **Fallo cerrado (Fail-closed):**
///   Cualquier error en la lectura de `sqlite_master` o `settings` se propaga
///   y detiene la ejecución; nunca se interpreta como base vacía ni se permite el vínculo.
/// - **Flujo de primera cuenta:**
///   Si una base tiene datos creados offline sin `_pockt_sync_owner` ni `sync.userId`,
///   se consideran datos previos al primer login y se vinculan a la primera cuenta
///   que inicie sesión (comportamiento offline-first intencional de Pockt).
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

  // Verificar si hay configuración previa de sincronización (c0ffd70) en settings
  final legacyUserId = await getLegacySyncUserId(database);
  if (legacyUserId != null) {
    if (legacyUserId != currentUserId) {
      throw CrossAccountSyncException(
        message:
            'La base de datos local contiene un registro previo de sincronización con otro usuario ($legacyUserId). '
            'No se permite vincular ni sincronizar con $currentUserId.',
        expectedUserId: legacyUserId,
        actualUserId: currentUserId,
      );
    }

    // Migración conservadora: vincular atómicamente a _pockt_sync_owner.
    // Una vez establecido el propietario local inmutable, la tabla sincronizada
    // `settings` nunca más es consultada para determinar la identidad.
    final winningOwner = await setSyncOwnerIfAbsent(database, currentUserId);
    if (winningOwner != currentUserId) {
      throw CrossAccountSyncException(
        message: 'Carrera concurrente al migrar propietario local',
        expectedUserId: winningOwner,
        actualUserId: currentUserId,
      );
    }

    return winningOwner;
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
