import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_sqlite_async/drift_sqlite_async.dart';
import 'package:http/http.dart' as http;
import 'package:powersync/powersync.dart' as ps;
import 'package:sqlite_async/sqlite_async.dart' as sa;

part 'database.g.dart';

class SpikeTx extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().named('user_id')();
  IntColumn get amount => integer()();
  TextColumn get note => text().nullable()();
  IntColumn get occurredAt => integer().named('occurred_at')();
  IntColumn get updatedAt => integer().named('updated_at')();
  IntColumn get deletedAt => integer().nullable().named('deleted_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'spike_tx';
}

Set<TableUpdate> _transformUpdates(sa.UpdateNotification notification) {
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

class SupabaseConnector extends ps.PowerSyncBackendConnector {
  final String endpoint;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String jwt;

  SupabaseConnector({
    required this.endpoint,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.jwt,
  });

  @override
  Future<ps.PowerSyncCredentials?> fetchCredentials() async {
    return ps.PowerSyncCredentials(
      endpoint: endpoint,
      token: jwt,
    );
  }

  @override
  Future<void> uploadData(ps.PowerSyncDatabase database) async {
    final batch = await database.getCrudBatch();
    if (batch == null) return;

    for (final op in batch.crud) {
      final table = op.table;
      final id = op.id;
      final headers = {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      };

      switch (op.op) {
        case ps.UpdateType.put:
          final url = Uri.parse('$supabaseUrl/rest/v1/$table');
          final response = await http.post(
            url,
            headers: {
              ...headers,
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode({'id': id, ...?op.opData}),
          );
          if (response.statusCode >= 300) {
            throw Exception(
              'Failed to put $table/$id: ${response.statusCode} ${response.body}',
            );
          }
          break;

        case ps.UpdateType.patch:
          final url = Uri.parse('$supabaseUrl/rest/v1/$table?id=eq.$id');
          final response = await http.patch(
            url,
            headers: headers,
            body: jsonEncode(op.opData),
          );
          if (response.statusCode >= 300) {
            throw Exception(
              'Failed to patch $table/$id: ${response.statusCode} ${response.body}',
            );
          }
          break;

        case ps.UpdateType.delete:
          final url = Uri.parse('$supabaseUrl/rest/v1/$table?id=eq.$id');
          final response = await http.delete(
            url,
            headers: headers,
          );
          if (response.statusCode >= 300) {
            throw Exception(
              'Failed to delete $table/$id: ${response.statusCode} ${response.body}',
            );
          }
          break;
      }
    }

    await batch.complete();
  }
}

/// Lee una variable de spike/infra/.env (ignorado por git) o del entorno.
String? infraEnv(String key) {
  final fromEnv = Platform.environment[key];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  final envFile = File('../infra/.env');
  if (!envFile.existsSync()) return null;
  for (final line in envFile.readAsLinesSync()) {
    if (line.startsWith('$key=')) return line.substring(key.length + 1).trim();
  }
  return null;
}

String resolvePowerSyncUrl() {
  final url = Platform.environment['POWERSYNC_URL'];
  if (url != null && url.isNotEmpty) return url;
  return 'http://localhost:${infraEnv('PS_HOST_PORT') ?? '18080'}';
}

@DriftDatabase(tables: [SpikeTx])
class SpikeDb extends _$SpikeDb {
  final ps.PowerSyncDatabase powerSyncDb;
  SupabaseConnector? _connector;

  SpikeDb(this.powerSyncDb)
      : super(SqliteAsyncDriftConnection(
          powerSyncDb,
          transformTableUpdates: _transformUpdates,
        ));

  @override
  int get schemaVersion => 1;

  Future<void> connectAs(
    String jwt, {
    String? powersyncUrl,
    String supabaseUrl = 'http://localhost:54321',
    String? supabaseAnonKey,
  }) async {
    final endpoint = powersyncUrl ?? resolvePowerSyncUrl();
    _connector = SupabaseConnector(
      endpoint: endpoint,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? infraEnv('SUPABASE_ANON_KEY')!,
      jwt: jwt,
    );
    await powerSyncDb.connect(connector: _connector!);
  }

  Future<void> disconnect() async {
    await powerSyncDb.disconnect();
  }
}
