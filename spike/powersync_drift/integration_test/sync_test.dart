import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:powersync/powersync.dart' as ps;
import 'package:powersync_drift/database.dart';
import 'package:powersync_drift/schema.dart';
import 'package:uuid/uuid.dart';

String getToken(String email) {
  final script = File('../infra/token.sh');
  final result = Process.runSync(script.path, [email]);
  if (result.exitCode != 0) {
    throw Exception('token.sh failed for $email: ${result.stderr}');
  }
  return result.stdout.toString().trim();
}

String getUserIdFromJwt(String jwt) {
  final parts = jwt.split('.');
  final payload = jsonDecode(
    utf8.decode(base64Url.decode(base64.normalize(parts[1]))),
  ) as Map<String, dynamic>;
  return payload['sub'] as String;
}

void runPsql(String sql) {
  final res = Process.runSync('docker', [
    'exec',
    'supabase_db_pockt-spike',
    'psql',
    '-U',
    'postgres',
    '-d',
    'postgres',
    '-c',
    sql,
  ]);
  if (res.exitCode != 0) {
    throw Exception('psql failed: ${res.stderr}');
  }
}

String queryPsql(String sql) {
  final res = Process.runSync('docker', [
    'exec',
    'supabase_db_pockt-spike',
    'psql',
    '-U',
    'postgres',
    '-d',
    'postgres',
    '-Atqc',
    sql,
  ]);
  if (res.exitCode != 0) {
    throw Exception('psql query failed: ${res.stderr}');
  }
  return res.stdout.toString().trim();
}

Future<void> waitFor(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  Duration pollInterval = const Duration(milliseconds: 200),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (await condition()) return;
    await Future.delayed(pollInterval);
  }
  throw TimeoutException('Condition not met within $timeout');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String tokenA;
  late String userIdA;
  late String tokenB;
  late String userIdB;
  late Directory tempDir;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tokenA = getToken('a@test.local');
    userIdA = getUserIdFromJwt(tokenA);
    tokenB = getToken('b@test.local');
    userIdB = getUserIdFromJwt(tokenB);
    tempDir = Directory.systemTemp.createTempSync('powersync_sync_test_');
  });

  tearDownAll(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('app -> nube: insertar con Drift y en <10s verla en Postgres',
      (tester) async {
    final dbFile = p.join(tempDir.path, 'app_to_cloud.db');
    final psDb = ps.PowerSyncDatabase(schema: schema, path: dbFile);
    await psDb.initialize();
    final db = SpikeDb(psDb);
    await db.connectAs(tokenA);

    final txId = const Uuid().v4();
    const amount = 184000;
    const occurredAt = 1793260800;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await db.into(db.spikeTx).insert(
          SpikeTxCompanion.insert(
            id: txId,
            userId: userIdA,
            amount: amount,
            note: const Value('test app -> nube'),
            occurredAt: occurredAt,
            updatedAt: now,
          ),
        );

    // En menos de 10s verla en Postgres con los mismos valores
    await waitFor(() async {
      final res = queryPsql(
        "SELECT amount, occurred_at FROM public.spike_tx WHERE id = '$txId'",
      );
      return res == '$amount|$occurredAt';
    }, timeout: const Duration(seconds: 10));

    final finalRes = queryPsql(
      "SELECT amount, occurred_at FROM public.spike_tx WHERE id = '$txId'",
    );
    expect(finalRes, equals('$amount|$occurredAt'));

    await db.disconnect();
    await db.close();
    await psDb.close();
  });

  testWidgets(
      'nube -> app: insertar en Postgres y que watch() de Drift emita la fila en <10s',
      (tester) async {
    final dbFile = p.join(tempDir.path, 'cloud_to_app.db');
    final psDb = ps.PowerSyncDatabase(schema: schema, path: dbFile);
    await psDb.initialize();
    final db = SpikeDb(psDb);
    await db.connectAs(tokenA);

    final txId = const Uuid().v4();
    const amount = 75000;
    final occurredAt = 1793260800;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final streamCompleter = Completer<SpikeTxData>();
    final subscription = db.select(db.spikeTx).watch().listen((rows) {
      final match = rows.where((r) => r.id == txId);
      if (match.isNotEmpty && !streamCompleter.isCompleted) {
        streamCompleter.complete(match.first);
      }
    });

    // Insertar directamente en Postgres como user A
    runPsql(
      "INSERT INTO public.spike_tx (id, user_id, amount, note, occurred_at, updated_at) "
      "VALUES ('$txId', '$userIdA', $amount, 'test nube -> app', $occurredAt, $now)",
    );

    // Debe emitirse en menos de 10s
    final receivedRow = await streamCompleter.future.timeout(
      const Duration(seconds: 10),
    );

    expect(receivedRow.id, equals(txId));
    expect(receivedRow.amount, equals(amount));
    expect(receivedRow.occurredAt, equals(occurredAt));

    await subscription.cancel();
    await db.disconnect();
    await db.close();
    await psDb.close();
  });

  testWidgets(
      'sin conexión: desconectar, insertar, reconectar: fila llega a Postgres una sola vez',
      (tester) async {
    final dbFile = p.join(tempDir.path, 'offline_sync.db');
    final psDb = ps.PowerSyncDatabase(schema: schema, path: dbFile);
    await psDb.initialize();
    final db = SpikeDb(psDb);
    await db.connectAs(tokenA);

    // Desconectar
    await db.disconnect();

    final txId = const Uuid().v4();
    const amount = 99000;
    const occurredAt = 1793260800;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Insertar sin conexión
    await db.into(db.spikeTx).insert(
          SpikeTxCompanion.insert(
            id: txId,
            userId: userIdA,
            amount: amount,
            note: const Value('test offline'),
            occurredAt: occurredAt,
            updatedAt: now,
          ),
        );

    // Verificar que todavía no llegó a Postgres
    final countBefore = queryPsql(
      "SELECT count(*) FROM public.spike_tx WHERE id = '$txId'",
    );
    expect(countBefore, equals('0'));

    // Reconectar
    await db.connectAs(tokenA);

    // Debe llegar a Postgres y existir exactamente 1 vez
    await waitFor(() async {
      final count = queryPsql(
        "SELECT count(*) FROM public.spike_tx WHERE id = '$txId'",
      );
      return count == '1';
    }, timeout: const Duration(seconds: 10));

    final countAfter = queryPsql(
      "SELECT count(*) FROM public.spike_tx WHERE id = '$txId'",
    );
    expect(countAfter, equals('1'));

    await db.disconnect();
    await db.close();
    await psDb.close();
  });

  testWidgets(
      'otro usuario: conectado como b@test.local, la fila de a@test.local no aparece',
      (tester) async {
    // Insertar una fila para el usuario A en Postgres
    final txIdA = const Uuid().v4();
    const amount = 350000;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    runPsql(
      "INSERT INTO public.spike_tx (id, user_id, amount, note, occurred_at, updated_at) "
      "VALUES ('$txIdA', '$userIdA', $amount, 'user A tx', $now, $now)",
    );

    // Conectar usuario B en una base local limpia
    final dbFileB = p.join(tempDir.path, 'user_b.db');
    final psDbB = ps.PowerSyncDatabase(schema: schema, path: dbFileB);
    await psDbB.initialize();
    final dbB = SpikeDb(psDbB);
    await dbB.connectAs(tokenB);

    // Insertar también una fila propia de B para asegurar que la sync de B funciona
    final txIdB = const Uuid().v4();
    runPsql(
      "INSERT INTO public.spike_tx (id, user_id, amount, note, occurred_at, updated_at) "
      "VALUES ('$txIdB', '$userIdB', 12000, 'user B tx', $now, $now)",
    );

    // Esperar a que la fila propia de B llegue a su base local
    await waitFor(() async {
      final rows = await dbB.select(dbB.spikeTx).get();
      return rows.any((r) => r.id == txIdB);
    }, timeout: const Duration(seconds: 10));

    // Confirmar que la fila de A NO aparece localmente para B
    final rowsForB = await dbB.select(dbB.spikeTx).get();
    expect(rowsForB.any((r) => r.id == txIdA), isFalse);

    await dbB.disconnect();
    await dbB.close();
    await psDbB.close();
  });
}
