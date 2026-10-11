import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/backup/data/snapshot.dart';
import 'package:pockt/features/transactions/data/categories_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase db;
  late CategoriesRepository catRepo;
  late TransactionsRepository txRepo;
  late Directory testTempDir;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    testTempDir = await Directory.systemTemp.createTemp('pockt_snapshot_test_');
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    catRepo = CategoriesRepository(db);
    txRepo = TransactionsRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await testTempDir.exists()) {
      await testTempDir.delete(recursive: true);
    }
  });

  test('la instantánea abierta como base nueva tiene los mismos movimientos', () async {
    // 1. Obtener categoría seeded y crear gasto inicial
    final expenses = await catRepo.watchActive(CategoryKind.expense).first;
    final cat = expenses.first;

    await txRepo.add(
      type: TxType.expense,
      amount: 150000,
      categoryId: cat.id,
      occurredAt: DateTime(2026, 10, 10, 14, 30),
      note: 'Compra semanal',
    );

    // 2. Generar instantánea de la base
    final snapshotBytes = await snapshotDatabase(db);
    expect(snapshotBytes, isNotEmpty);

    // 3. Abrir los bytes de la instantánea como una base nueva
    final snapshotFile = File('${testTempDir.path}/restored_1.db');
    await snapshotFile.writeAsBytes(snapshotBytes);

    final restoredDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase(snapshotFile), closeStreamsSynchronously: true),
    );
    addTearDown(restoredDb.close);

    final restoredTxRepo = TransactionsRepository(restoredDb);
    final recent = await restoredTxRepo.watchRecent().first;

    expect(recent.length, equals(1));
    expect(recent.first.tx.amount, equals(150000));
    expect(recent.first.tx.note, equals('Compra semanal'));
    expect(recent.first.category.id, equals(cat.id));
  });

  test('un gasto escrito justo antes de la instantánea aparece en la copia', () async {
    final expenses = await catRepo.watchActive(CategoryKind.expense).first;
    final catId = expenses.first.id;

    await txRepo.add(
      type: TxType.expense,
      amount: 45000,
      categoryId: catId,
      occurredAt: DateTime(2026, 10, 10, 10, 0),
      note: 'Medicamento 1',
    );

    // Escribir un segundo gasto justo antes de la instantánea
    await txRepo.add(
      type: TxType.expense,
      amount: 80000,
      categoryId: catId,
      occurredAt: DateTime(2026, 10, 10, 10, 15),
      note: 'Medicamento 2',
    );

    final snapshotBytes = await snapshotDatabase(db);

    final snapshotFile = File('${testTempDir.path}/restored_2.db');
    await snapshotFile.writeAsBytes(snapshotBytes);

    final restoredDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase(snapshotFile), closeStreamsSynchronously: true),
    );
    addTearDown(restoredDb.close);

    final restoredTxRepo = TransactionsRepository(restoredDb);
    final recent = await restoredTxRepo.watchRecent().first;

    expect(recent.length, equals(2));
    final amounts = recent.map((r) => r.tx.amount).toList();
    expect(amounts, containsAll([45000, 80000]));
  });
}
