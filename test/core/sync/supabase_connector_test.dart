import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/sync/supabase_connector.dart';
import 'package:pockt/core/sync/sync_owner.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeBackend implements PocktSupabaseBackend {
  @override
  String? accessToken = 'session-token';
  @override
  String? currentUserId = 'user-1';
  final calls = <Object>[];
  final tokens = <String>[];
  Object? error;
  VoidCallback? onAfterCall;

  Future<void> record(Object call, String token) async {
    calls.add(call);
    tokens.add(token);
    final failure = error;
    error = null;
    if (failure != null) throw failure;
    onAfterCall?.call();
  }

  @override
  Future<void> upsert(
    String table,
    Map<String, dynamic> data, {
    required String onConflict,
    required String accessToken,
  }) => record(['PUT', table, data, onConflict], accessToken);

  @override
  Future<void> update(
    String table,
    String id,
    Map<String, dynamic> data, {
    required String accessToken,
  }) => record(['PATCH', table, id, data], accessToken);

  @override
  Future<void> delete(
    String table,
    String id, {
    required String accessToken,
  }) => record(['DELETE', table, id], accessToken);
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
        Table('settings', [
          Column.text('key'),
          Column.text('value'),
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

  test('credentials validate owner if getOwnerUserId is configured', () async {
    String? currentOwner = 'user-owner';
    final ownerConnector = PocktSupabaseConnector(
      backend: backend,
      endpoint: 'https://sync.example.test',
      getOwnerUserId: () async => currentOwner,
    );

    // Coincide con el dueño
    backend.currentUserId = 'user-owner';
    backend.accessToken = 'token-owner';
    final validCreds = await ownerConnector.fetchCredentials();
    expect(validCreds?.token, equals('token-owner'));

    // Sesión con otro usuario distinto
    backend.currentUserId = 'user-other';
    backend.accessToken = 'token-other';
    final invalidCreds = await ownerConnector.fetchCredentials();
    expect(invalidCreds, isNull);

    // Falla cerrado: si falta dueño vinculado (null), no entrega credenciales
    currentOwner = null;
    backend.currentUserId = 'user-owner';
    backend.accessToken = 'token-owner';
    final missingOwnerCreds = await ownerConnector.fetchCredentials();
    expect(missingOwnerCreds, isNull);
  });

  test(
    'fetchCredentials falla cerrado si la sesión o token cambian mientras espera getOwnerUserId',
    () async {
      final completer = Completer<String?>();
      final racingConnector = PocktSupabaseConnector(
        backend: backend,
        endpoint: 'https://sync.example.test',
        getOwnerUserId: () => completer.future,
      );

      backend.currentUserId = 'user-initial';
      backend.accessToken = 'token-initial';

      final futureCreds = racingConnector.fetchCredentials();

      // Cambiar usuario y token mientras getOwnerUserId está en vuelo
      backend.currentUserId = 'user-switched';
      backend.accessToken = 'token-switched';

      completer.complete('user-initial');
      final creds = await futureCreds;

      expect(creds, isNull);
    },
  );

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

  group('Protección contra subida a otra cuenta (cross-account leak)', () {
    test(
      'uploadData vincula la base al primer usuario si no tiene dueño (flujo normal)',
      () async {
        backend.currentUserId = 'user-first';
        backend.accessToken = 'token-first';
        await enqueue(database, [
          entry(UpdateType.put, {'amount': 100}),
        ]);
        await connector.uploadData(database);

        expect(backend.calls, isNotEmpty);
        expect(backend.tokens, equals(['token-first']));
        expect(await getSyncOwner(database), equals('user-first'));
      },
    );

    test(
      'setSyncOwnerIfAbsent es atómico y el primer vínculo gana bajo concurrencia',
      () async {
        // Ejecución concurrente simulada de dos llamadas de vinculación
        final results = await Future.wait([
          setSyncOwnerIfAbsent(database, 'user-winner'),
          setSyncOwnerIfAbsent(database, 'user-racer'),
        ]);

        // Ambas deben coincidir en el mismo ganador (el primer insert ignore)
        expect(results[0], equals(results[1]));
        expect(await getSyncOwner(database), equals(results[0]));

        // Intentar vincular de nuevo a otro usuario no sobreescribe
        final secondAttempt = await setSyncOwnerIfAbsent(database, 'user-late');
        expect(secondAttempt, equals(results[0]));
        expect(await getSyncOwner(database), equals(results[0]));
      },
    );

    test(
      'uploadData usa el token inmutable de la cuenta dueña en cada solicitud al backend',
      () async {
        await setSyncOwner(database, 'user-1');
        backend.currentUserId = 'user-1';
        backend.accessToken = 'token-immutable-1';

        await enqueue(database, [
          entry(UpdateType.put, {'amount': 100}),
          entry(UpdateType.patch, {'amount': 200}),
          entry(UpdateType.delete),
        ]);

        await connector.uploadData(database);

        expect(backend.tokens, [
          'token-immutable-1',
          'token-immutable-1',
          'token-immutable-1',
        ]);
      },
    );

    test(
      'uploadData bloquea la subida y lanza CrossAccountSyncException si la base pertenece a otro usuario',
      () async {
        // La base local está vinculada a user-1
        await setSyncOwner(database, 'user-1');

        // La sesión actual pertenece a user-2
        backend.currentUserId = 'user-2';
        await enqueue(database, [
          entry(UpdateType.put, {'amount': 500}),
        ]);

        await expectLater(
          connector.uploadData(database),
          throwsA(isA<CrossAccountSyncException>()),
        );

        // Nada fue enviado al backend bajo la cuenta de user-2
        expect(backend.calls, isEmpty);

        // La transacción no fue confirmada (ps_crud conserva la entrada)
        final crudRows = await database.getAll('SELECT * FROM ps_crud');
        expect(crudRows, isNotEmpty);
      },
    );

    test(
      'uploadData aborta si el token cambia en mitad de la transacción',
      () async {
        await setSyncOwner(database, 'user-1');
        backend.currentUserId = 'user-1';
        backend.accessToken = 'token-1';

        await enqueue(database, [
          entry(UpdateType.put, {'amount': 100}),
          entry(UpdateType.put, {'amount': 200}),
        ]);

        // Simular que el token cambia tras la primera llamada
        backend.onAfterCall = () {
          backend.accessToken = 'token-refreshed-or-other';
        };

        await expectLater(
          connector.uploadData(database),
          throwsA(isA<CrossAccountSyncException>()),
        );

        // Solo se ejecutó 1 operación y la transacción no se completó
        expect(backend.calls.length, equals(1));
        final crudRows = await database.getAll('SELECT * FROM ps_crud');
        expect(crudRows, isNotEmpty);
      },
    );

    test(
      'uploadData aborta si el usuario cambia en mitad de la transacción (carrera en vuelo)',
      () async {
        await setSyncOwner(database, 'user-1');
        backend.currentUserId = 'user-1';

        await enqueue(database, [
          entry(UpdateType.put, {'amount': 100}),
          entry(UpdateType.put, {'amount': 200}),
        ]);

        // Simular que el usuario cambia justo tras la primera llamada
        backend.onAfterCall = () {
          backend.currentUserId = 'user-switched-during-upload';
        };

        await expectLater(
          connector.uploadData(database),
          throwsA(isA<CrossAccountSyncException>()),
        );

        // Solo se ejecutó 1 operación y la segunda quedó abortada
        expect(backend.calls.length, equals(1));

        // La transacción no fue confirmada
        final crudRows = await database.getAll('SELECT * FROM ps_crud');
        expect(crudRows, isNotEmpty);
      },
    );

    test(
      'instalación legacy (c0ffd70): owner local vacío con sync.userId previo; cuenta distinta bloquea uploadData y preserva crud',
      () async {
        // En c0ffd70 se guardó sync.userId en settings
        await database.execute(
          "INSERT INTO settings (id, key, value) VALUES ('1', 'sync.userId', 'user-legacy-owner')",
        );
        expect(await getSyncOwner(database), isNull);

        // La sesión activa actual pertenece a otra cuenta distinta
        backend.currentUserId = 'user-intruder';
        backend.accessToken = 'token-intruder';
        await enqueue(database, [
          entry(UpdateType.put, {'amount': 999}),
        ]);

        await expectLater(
          connector.uploadData(database),
          throwsA(isA<CrossAccountSyncException>()),
        );

        // No se vinculó a user-intruder
        expect(await getSyncOwner(database), isNull);
        // No se envió nada al backend bajo la cuenta de user-intruder
        expect(backend.calls, isEmpty);
        // La cola se preservó intacta
        final crudRows = await database.getAll('SELECT * FROM ps_crud');
        expect(crudRows, isNotEmpty);
      },
    );

    test(
      'instalación legacy (c0ffd70): owner local vacío con sync.userId coincidente; migra conservadoramente a _pockt_sync_owner y completa uploadData',
      () async {
        // En c0ffd70 se guardó sync.userId en settings
        await database.execute(
          "INSERT INTO settings (id, key, value) VALUES ('1', 'sync.userId', 'user-legitimate')",
        );
        // Limpiar ps_crud de la inserción de prueba previa
        await database.execute('DELETE FROM ps_crud');
        expect(await getSyncOwner(database), isNull);

        // La sesión activa pertenece exactamente al mismo usuario
        backend.currentUserId = 'user-legitimate';
        backend.accessToken = 'token-legitimate';
        await enqueue(database, [
          entry(UpdateType.put, {'amount': 150}),
        ]);

        await connector.uploadData(database);

        // Ahora está formalizado en el owner local no sincronizable
        expect(await getSyncOwner(database), equals('user-legitimate'));

        // Se subió al backend con su token
        expect(backend.calls, isNotEmpty);
        expect(backend.tokens, equals(['token-legitimate']));
        expect(await database.getNextCrudTransaction(), isNull);
      },
    );

    test(
      'error de base de datos en lectura legacy falla cerrado (no vincula ni sube)',
      () async {
        final errorDirectory =
            await Directory.systemTemp.createTemp('pockt-err-');
        final errorDb = PowerSyncDatabase(
          schema: Schema([
            Table('settings', [Column.text('key'), Column.text('value')]),
          ]),
          path: '${errorDirectory.path}/error.sqlite',
        );
        await errorDb.initialize();
        await errorDb.close(); // Simular base cerrada / fallo de I/O

        // getLegacySyncUserId debe fallar cerrado propagando el error
        await expectLater(
          getLegacySyncUserId(errorDb),
          throwsA(anything),
        );

        // resolveOrMigrateSyncOwner no debe atrapar el error ni devolver owner
        await expectLater(
          resolveOrMigrateSyncOwner(errorDb, 'user-123'),
          throwsA(anything),
        );

        // uploadData debe abortar ante error en database sin realizar llamadas al backend
        final connectorWithBrokenDb = PocktSupabaseConnector(
          backend: backend,
          endpoint: 'https://sync.example.test',
        );
        backend.currentUserId = 'user-123';
        backend.accessToken = 'token-123';
        backend.calls.clear();

        await expectLater(
          connectorWithBrokenDb.uploadData(errorDb),
          throwsA(anything),
        );
        expect(backend.calls, isEmpty);

        await errorDirectory.delete(recursive: true);
      },
    );
  });
}
