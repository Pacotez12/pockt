import 'package:flutter/foundation.dart';
import 'package:pockt/core/sync/sync_owner.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Backend boundary, shared by the Supabase adapter and offline test fakes.
abstract interface class PocktSupabaseBackend {
  factory PocktSupabaseBackend.fromSupabase(SupabaseClient client) =
      _SupabaseBackend;

  String? get accessToken;
  String? get currentUserId;
  Future<void> upsert(
    String table,
    Map<String, dynamic> data, {
    required String onConflict,
    required String accessToken,
  });
  Future<void> update(
    String table,
    String id,
    Map<String, dynamic> data, {
    required String accessToken,
  });
  Future<void> delete(
    String table,
    String id, {
    required String accessToken,
  });
}

class _SupabaseBackend implements PocktSupabaseBackend {
  final SupabaseClient client;

  _SupabaseBackend(this.client);

  @override
  String? get accessToken => client.auth.currentSession?.accessToken;

  @override
  String? get currentUserId => client.auth.currentSession?.user.id;

  @override
  Future<void> upsert(
    String table,
    Map<String, dynamic> data, {
    required String onConflict,
    required String accessToken,
  }) async {
    await client
        .from(table)
        .upsert(data, onConflict: onConflict)
        .setHeader('Authorization', 'Bearer $accessToken');
  }

  @override
  Future<void> update(
    String table,
    String id,
    Map<String, dynamic> data, {
    required String accessToken,
  }) async {
    await client
        .from(table)
        .update(data)
        .eq('id', id)
        .setHeader('Authorization', 'Bearer $accessToken');
  }

  @override
  Future<void> delete(
    String table,
    String id, {
    required String accessToken,
  }) async {
    await client
        .from(table)
        .delete()
        .eq('id', id)
        .setHeader('Authorization', 'Bearer $accessToken');
  }
}

class PocktSupabaseConnector extends PowerSyncBackendConnector {
  // Reused when initializing the shared Supabase auth client.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  final PocktSupabaseBackend backend;
  final String endpoint;
  final Future<String?> Function()? getOwnerUserId;

  PocktSupabaseConnector({
    required this.backend,
    this.endpoint = const String.fromEnvironment('POWERSYNC_URL'),
    this.getOwnerUserId,
  });

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final initialToken = backend.accessToken;
    if (initialToken == null) return null;

    final initialUserId = backend.currentUserId;
    if (initialUserId == null) return null;

    if (getOwnerUserId != null) {
      final ownerUserId = await getOwnerUserId!();
      // Falla cerrado: si falta dueño vinculado o no coincide con la sesión, no entregar credenciales
      if (ownerUserId == null || ownerUserId != initialUserId) {
        return null;
      }

      // Revalidar tras el await que la sesión o el token no cambiaron en pleno vuelo
      if (backend.accessToken != initialToken ||
          backend.currentUserId != initialUserId) {
        return null;
      }
    }

    return PowerSyncCredentials(endpoint: endpoint, token: initialToken);
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    final initialToken = backend.accessToken;
    if (initialToken == null) {
      throw const AuthException('No hay sesión activa para sincronizar datos.');
    }

    final initialUserId = backend.currentUserId;
    if (initialUserId == null) {
      throw const AuthException('No hay usuario autenticado para sincronizar datos.');
    }

    // 1. Obtener o migrar conservadoramente el propietario local de la base de datos
    // Protege contra enlazar ciegamente una base existente de c0ffd70 a una cuenta distinta
    // y vincula atómicamente con INSERT OR IGNORE ante concurrencia.
    final ownerUserId = await resolveOrMigrateSyncOwner(database, initialUserId);

    // Usamos el token inmutable capturado explícitamente para esta sesión y cuenta dueña.
    final immutableToken = initialToken;

    for (final op in transaction.crud) {
      // 2. Verificación de identidad previa a cada operación
      if (backend.currentUserId != ownerUserId || backend.accessToken != immutableToken) {
        throw CrossAccountSyncException(
          message: 'La sesión cambió antes de ejecutar la operación en la nube',
          expectedUserId: ownerUserId,
          actualUserId: backend.currentUserId ?? 'null',
        );
      }

      final data = {...?op.opData}..remove('user_id');
      try {
        switch (op.op) {
          case UpdateType.put:
            await backend.upsert(
              op.table,
              {
                ...data,
                'id': op.id,
              },
              onConflict: 'user_id,id',
              accessToken: immutableToken,
            );
          case UpdateType.patch:
            await backend.update(
              op.table,
              op.id,
              data,
              accessToken: immutableToken,
            );
          case UpdateType.delete:
            await backend.delete(
              op.table,
              op.id,
              accessToken: immutableToken,
            );
        }
      } on PostgrestException catch (error) {
        final code = error.code;
        final invalidData =
            code != null &&
            (code.startsWith('22') || code.startsWith('23'));
        if (!invalidData) rethrow;
        // Keep row contents and server messages out of logs.
        debugPrint('PowerSync: rejected ${op.op.name} on ${op.table} ($code)');
      }

      // 3. Verificación de identidad posterior a cada operación
      if (backend.currentUserId != ownerUserId || backend.accessToken != immutableToken) {
        throw CrossAccountSyncException(
          message: 'La sesión cambió durante la ejecución de la operación en la nube',
          expectedUserId: ownerUserId,
          actualUserId: backend.currentUserId ?? 'null',
        );
      }
    }

    // 4. Verificación final antes de confirmar la transacción local
    if (backend.currentUserId != ownerUserId || backend.accessToken != immutableToken) {
      throw CrossAccountSyncException(
        message: 'La sesión cambió antes de confirmar la transacción local',
        expectedUserId: ownerUserId,
        actualUserId: backend.currentUserId ?? 'null',
      );
    }

    await transaction.complete();
  }
}
