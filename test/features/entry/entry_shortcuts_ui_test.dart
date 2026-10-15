import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/features/entry/data/entry_shortcuts_repository.dart';
import 'package:pockt/features/entry/domain/entry_shortcut.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionsRepository txRepo;
  late EntryShortcutsRepository shortcutsRepo;
  late String comidaId;

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
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpEntryFlow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          transactionsRepositoryProvider.overrideWithValue(txRepo),
          entryShortcutsRepositoryProvider.overrideWithValue(shortcutsRepo),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showEntryFlow(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'muestra chips de atajos y un toque guarda inmediatamente con opción de deshacer',
    (tester) async {
      // Crear un atajo fijado
      final catComida = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(comidaId))).getSingle();
      await shortcutsRepo.pinShortcut(
        EntryShortcutItem(
          id: 'sc-1',
          merchant: 'Biggie',
          amount: 25000,
          categoryId: comidaId,
          categoryName: catComida.name,
          categoryIcon: catComida.icon,
          colorDark: catComida.colorDark,
          colorLight: catComida.colorLight,
          isPinned: true,
        ),
      );

      await pumpEntryFlow(tester);

      // Debe mostrarse el chip con "Biggie"
      final chipFinder = find.textContaining('Biggie');
      expect(chipFinder, findsOneWidget);

      // Tocar el chip para guardar
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // Se guardó la transacción en la base de datos
      final txs = await (db.select(
        db.transactions,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(txs.length, equals(1));
      expect(txs.first.merchant, equals('Biggie'));
      expect(txs.first.amount, equals(25000));

      // Se muestra el SnackBar con botón "Deshacer"
      final undoFinder = find.text('Deshacer');
      expect(undoFinder, findsOneWidget);

      // Tocar "Deshacer"
      await tester.tap(undoFinder);
      await tester.pumpAndSettle();

      // La transacción ahora está borrada (softDelete)
      final activeTxs = await (db.select(
        db.transactions,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(activeTxs, isEmpty);
    },
  );
}
