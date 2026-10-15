import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/entry/data/entry_shortcuts_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionsRepository txRepo;
  late EntryShortcutsRepository shortcutsRepo;
  late String comidaId;
  late String transporteId;

  setUp(() async {
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    txRepo = TransactionsRepository(db);
    shortcutsRepo = EntryShortcutsRepository(db);

    final cats = await db.select(db.categories).get();
    comidaId = cats.firstWhere((c) => c.name == 'Comida').id;
    transporteId = cats.firstWhere((c) => c.name == 'Transporte').id;
  });

  tearDown(() async {
    await db.close();
  });

  test('no sugiere atajos si hay menos de 3 repeticiones', () async {
    final now = DateTime(2026, 10, 15, 12, 0);

    // 2 compras iguales en Biggie
    await txRepo.add(
      type: TxType.expense,
      amount: 25000,
      categoryId: comidaId,
      merchant: 'Biggie',
      occurredAt: now.subtract(const Duration(days: 5)),
    );
    await txRepo.add(
      type: TxType.expense,
      amount: 25000,
      categoryId: comidaId,
      merchant: 'Biggie',
      occurredAt: now.subtract(const Duration(days: 2)),
    );

    final shortcuts = await shortcutsRepo.getShortcuts(now: now);
    expect(shortcuts, isEmpty);
  });

  test('sugiere atajo al alcanzar 3 repeticiones en 60 días', () async {
    final now = DateTime(2026, 10, 15, 12, 0);

    for (var i = 1; i <= 3; i++) {
      await txRepo.add(
        type: TxType.expense,
        amount: 25000,
        categoryId: comidaId,
        merchant: 'Biggie',
        occurredAt: now.subtract(Duration(days: i * 5)),
      );
    }

    final shortcuts = await shortcutsRepo.getShortcuts(now: now);
    expect(shortcuts.length, equals(1));
    expect(shortcuts.first.label, equals('Biggie'));
    expect(shortcuts.first.amount, equals(25000));
    expect(shortcuts.first.count, equals(3));
    expect(shortcuts.first.isPinned, isFalse);
  });

  test('ignora repeticiones mayores a 60 días de antigüedad', () async {
    final now = DateTime(2026, 10, 15, 12, 0);

    // 2 repeticiones recientes
    await txRepo.add(
      type: TxType.expense,
      amount: 15000,
      categoryId: transporteId,
      merchant: 'Bolt',
      occurredAt: now.subtract(const Duration(days: 10)),
    );
    await txRepo.add(
      type: TxType.expense,
      amount: 15000,
      categoryId: transporteId,
      merchant: 'Bolt',
      occurredAt: now.subtract(const Duration(days: 20)),
    );
    // 1 repetición vieja (> 60 días)
    await txRepo.add(
      type: TxType.expense,
      amount: 15000,
      categoryId: transporteId,
      merchant: 'Bolt',
      occurredAt: now.subtract(const Duration(days: 65)),
    );

    final shortcuts = await shortcutsRepo.getShortcuts(now: now);
    expect(shortcuts, isEmpty);
  });

  test('fijar atajo lo coloca primero y permite quitarlo (dismiss)', () async {
    final now = DateTime(2026, 10, 15, 12, 0);

    // 3 de Biggie
    for (var i = 1; i <= 3; i++) {
      await txRepo.add(
        type: TxType.expense,
        amount: 25000,
        categoryId: comidaId,
        merchant: 'Biggie',
        occurredAt: now.subtract(Duration(days: i)),
      );
    }
    // 3 de Bolt
    for (var i = 1; i <= 3; i++) {
      await txRepo.add(
        type: TxType.expense,
        amount: 12000,
        categoryId: transporteId,
        merchant: 'Bolt',
        occurredAt: now.subtract(Duration(days: i)),
      );
    }

    var list = await shortcutsRepo.getShortcuts(now: now);
    expect(list.length, equals(2));

    // Fijar Bolt
    final bolt = list.firstWhere((s) => s.label == 'Bolt');
    await shortcutsRepo.pinShortcut(bolt);

    list = await shortcutsRepo.getShortcuts(now: now);
    expect(list.first.label, equals('Bolt'));
    expect(list.first.isPinned, isTrue);

    // Quitar Biggie
    final biggie = list.firstWhere((s) => s.label == 'Biggie');
    await shortcutsRepo.dismissShortcut(biggie);

    list = await shortcutsRepo.getShortcuts(now: now);
    expect(list.length, equals(1));
    expect(list.first.label, equals('Bolt'));
  });

  test('limita el total a máximo 6 atajos', () async {
    final now = DateTime(2026, 10, 15, 12, 0);

    for (var j = 1; j <= 8; j++) {
      for (var i = 1; i <= 3; i++) {
        await txRepo.add(
          type: TxType.expense,
          amount: j * 10000,
          categoryId: comidaId,
          merchant: 'Comercio $j',
          occurredAt: now.subtract(Duration(days: i)),
        );
      }
    }

    final shortcuts = await shortcutsRepo.getShortcuts(now: now);
    expect(shortcuts.length, equals(6));
  });
}
