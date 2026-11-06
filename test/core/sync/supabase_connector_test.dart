import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/sync/supabase_connector.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeBackend implements PocktSupabaseBackend {
  @override
  String? accessToken = 'session-token';
  final calls = <Object>[];
  Object? error;

  Future<void> record(Object call) async {
    calls.add(call);
    final failure = error;
    error = null;
    if (failure != null) throw failure;
  }

  @override
  Future<void> upsert(
    String table,
    Map<String, dynamic> data, {
    required String onConflict,
  }) => record(['PUT', table, data, onConflict]);

  @override
  Future<void> update(String table, String id, Map<String, dynamic> data) =>
      record(['PATCH', table, id, data]);

  @override
  Future<void> delete(String table, String id) => record(['DELETE', table, id]);
}

CrudEntry entry(UpdateType type, [Map<String, dynamic>? data]) =>
    CrudEntry(1, type, 'transactions', 'row-1', 1, data);

Future<void> enqueue(
  PowerSyncDatabase database,
  List<CrudEntry> entries,
) async {
  await database.writeTransaction((tx) async {
    final transactionId = (await tx.get(
      'SELECT COALESCE(MAX(tx_id), 0) + 1 AS next FROM ps_crud',
    ))['next'];
    for (final op in entries) {
      await tx.execute('INSERT INTO ps_crud (tx_id, data) VALUES (?, ?)', [
        transactionId,
        jsonEncode({
          'op': op.op.toJson(),
          'type': op.table,
          'id': op.id,
          if (op.opData != null) 'data': op.opData,
        }),
      ]);
    }
  });
}

void main() {
  late FakeBackend backend;
  late PowerSyncDatabase database;
  late Directory directory;
  late PocktSupabaseConnector connector;

  setUp(() async {
    backend = FakeBackend();
    directory = await Directory.systemTemp.createTemp('pockt-connector-');
    database = PowerSyncDatabase(
      schema: Schema([
        Table('transactions', [
          Column.integer('amount'),
          Column.text('user_id'),
        ]),
      ]),
      path: '${directory.path}/test.sqlite',
    );
    await database.initialize();
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });
    connector = PocktSupabaseConnector(
      backend: backend,
      endpoint: 'https://sync.example.test',
    );
  });

  test(
    'PUT upserts with composite conflict key and server-owned user_id',
    () async {
      await enqueue(database, [
        entry(UpdateType.put, {'amount': 100, 'user_id': 'untrusted'}),
      ]);
      await connector.uploadData(database);
      expect(backend.calls, [
        [
          'PUT',
          'transactions',
          {'amount': 100, 'id': 'row-1'},
          'user_id,id',
        ],
      ]);
      expect(await database.getNextCrudTransaction(), isNull);
    },
  );

  test('PATCH updates by id without sending user_id', () async {
    await enqueue(database, [
      entry(UpdateType.patch, {'amount': null, 'user_id': 'untrusted'}),
    ]);
    await connector.uploadData(database);
    expect(backend.calls, [
      [
        'PATCH',
        'transactions',
        'row-1',
        {'amount': null},
      ],
    ]);
    expect(await database.getNextCrudTransaction(), isNull);
  });

  test('DELETE deletes by id', () async {
    await enqueue(database, [entry(UpdateType.delete)]);
    await connector.uploadData(database);
    expect(backend.calls, [
      ['DELETE', 'transactions', 'row-1'],
    ]);
    expect(await database.getNextCrudTransaction(), isNull);
  });

  test('network failure preserves transaction for retry', () async {
    final error = const SocketException('offline');
    backend.error = error;
    await enqueue(database, [
      entry(UpdateType.put, {'amount': 100}),
      entry(UpdateType.delete),
    ]);
    await expectLater(connector.uploadData(database), throwsA(same(error)));
    expect(await database.getNextCrudTransaction(), isNotNull);
    expect(backend.calls, hasLength(1));
    await connector.uploadData(database);
    expect(await database.getNextCrudTransaction(), isNull);
  });

  for (final code in [
    '500',
    '503',
    '401',
    '403',
    'PGRST301',
    '40001',
    '08006',
    '42501',
  ]) {
    test('retryable or unclassified error $code does not complete', () async {
      final error = PostgrestException(message: 'retry', code: code);
      backend.error = error;
      await enqueue(database, [entry(UpdateType.delete)]);
      await expectLater(connector.uploadData(database), throwsA(same(error)));
      expect(await database.getNextCrudTransaction(), isNotNull);
    });
  }

  for (final code in ['22003', '22P02', '23502', '23503', '23505']) {
    test('invalid data $code is logged and queue continues', () async {
      final logs = <String?>[];
      final previousPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
      addTearDown(() => debugPrint = previousPrint);
      backend.error = PostgrestException(
        message: 'private row contents',
        code: code,
      );
      await enqueue(database, [
        entry(UpdateType.put, {'amount': 100}),
        entry(UpdateType.delete),
      ]);
      await enqueue(database, [
        entry(UpdateType.patch, {'amount': 200}),
      ]);
      await connector.uploadData(database);
      expect(await database.getNextCrudTransaction(), isNotNull);
      expect(backend.calls, hasLength(2));
      expect(logs.join(), contains(code));
      expect(logs.join(), isNot(contains('private row contents')));
      await connector.uploadData(database);
      expect(await database.getNextCrudTransaction(), isNull);
      expect(backend.calls.last, [
        'PATCH',
        'transactions',
        'row-1',
        {'amount': 200},
      ]);
    });
  }

  test('empty queue makes no backend call', () async {
    await connector.uploadData(database);
    expect(backend.calls, isEmpty);
    expect(await database.getNextCrudTransaction(), isNull);
  });

  test(
    'credentials use the current session token and PowerSync endpoint',
    () async {
      final credentials = await connector.fetchCredentials();
      expect(credentials?.endpoint, 'https://sync.example.test');
      expect(credentials?.token, 'session-token');
      backend.accessToken = 'renewed-token';
      expect((await connector.fetchCredentials())?.token, 'renewed-token');
    },
  );

  test('without a session credentials are null', () async {
    backend.accessToken = null;
    expect(await connector.fetchCredentials(), isNull);
    expect(backend.calls, isEmpty);
  });

  test('without a session uploadData throws and preserves transaction', () async {
    backend.accessToken = null;
    await enqueue(database, [entry(UpdateType.delete)]);
    await expectLater(
      connector.uploadData(database),
      throwsA(isA<AuthException>()),
    );
    expect(await database.getNextCrudTransaction(), isNotNull);
    expect(backend.calls, isEmpty);
  });
}
