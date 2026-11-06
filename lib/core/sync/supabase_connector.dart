import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Backend boundary, shared by the Supabase adapter and offline test fakes.
abstract interface class PocktSupabaseBackend {
  factory PocktSupabaseBackend.fromSupabase(SupabaseClient client) =
      _SupabaseBackend;

  String? get accessToken;
  Future<void> upsert(
    String table,
    Map<String, dynamic> data, {
    required String onConflict,
  });
  Future<void> update(String table, String id, Map<String, dynamic> data);
  Future<void> delete(String table, String id);
}

class _SupabaseBackend implements PocktSupabaseBackend {
  final SupabaseClient client;

  _SupabaseBackend(this.client);

  @override
  String? get accessToken => client.auth.currentSession?.accessToken;

  @override
  Future<void> upsert(
    String table,
    Map<String, dynamic> data, {
    required String onConflict,
  }) async {
    await client.from(table).upsert(data, onConflict: onConflict);
  }

  @override
  Future<void> update(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    await client.from(table).update(data).eq('id', id);
  }

  @override
  Future<void> delete(String table, String id) async {
    await client.from(table).delete().eq('id', id);
  }
}

class PocktSupabaseConnector extends PowerSyncBackendConnector {
  // Reused when initializing the shared Supabase auth client.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  final PocktSupabaseBackend backend;
  final String endpoint;

  PocktSupabaseConnector({
    required this.backend,
    this.endpoint = const String.fromEnvironment('POWERSYNC_URL'),
  });

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final token = backend.accessToken;
    if (token == null) return null;
    return PowerSyncCredentials(endpoint: endpoint, token: token);
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    if (backend.accessToken == null) {
      throw const AuthException('No hay sesión activa para sincronizar datos.');
    }

    for (final op in transaction.crud) {
      final data = {...?op.opData}..remove('user_id');
      try {
        switch (op.op) {
          case UpdateType.put:
            await backend.upsert(op.table, {
              ...data,
              'id': op.id,
            }, onConflict: 'user_id,id');
          case UpdateType.patch:
            await backend.update(op.table, op.id, data);
          case UpdateType.delete:
            await backend.delete(op.table, op.id);
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
    }
    await transaction.complete();
  }
}
