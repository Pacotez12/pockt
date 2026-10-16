import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/entry/data/entry_shortcuts_repository.dart';
import 'package:pockt/features/entry/domain/entry_shortcut.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/transactions/data/categories_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

class CountingEntryShortcutsRepository extends EntryShortcutsRepository {
  int watchShortcutsCalls = 0;

  CountingEntryShortcutsRepository(super.db);

  @override
  Stream<List<EntryShortcutItem>> watchShortcuts({
    DateTime? now,
    int limit = 6,
  }) {
    watchShortcutsCalls++;
    return super.watchShortcuts(now: now, limit: limit);
  }
}

class CountingCategoriesRepository extends CategoriesRepository {
  int watchActiveCalls = 0;

  CountingCategoriesRepository(super.db);

  @override
  Stream<List<Category>> watchActive(
    CategoryKind kind, {
    CategoryOrder order = CategoryOrder.manual,
  }) {
    watchActiveCalls++;
    return super.watchActive(kind, order: order);
  }
}

void main() {
  late AppDatabase db;
  late TransactionsRepository txRepo;
  late CountingEntryShortcutsRepository shortcutsRepo;
  late CountingCategoriesRepository categoriesRepo;
  late String comidaId;

  setUp(() async {
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    txRepo = TransactionsRepository(db);
    shortcutsRepo = CountingEntryShortcutsRepository(db);
    categoriesRepo = CountingCategoriesRepository(db);

    final cats = await db.select(db.categories).get();
    comidaId = cats.firstWhere((c) => c.name == 'Comida').id;

    final catComida = cats.firstWhere((c) => c.id == comidaId);
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
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
    'Entry flow no recrea streams de atajos ni de categorías al escribir en el campo natural',
    (tester) async {
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
            categoriesRepositoryProvider.overrideWithValue(categoriesRepo),
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

      final initialShortcutsCalls = shortcutsRepo.watchShortcutsCalls;
      final initialCategoriesCalls = categoriesRepo.watchActiveCalls;

      expect(initialShortcutsCalls, 1);
      expect(initialCategoriesCalls, 1);

      // Escribir 5 caracteres uno por uno para provocar rebuilds en EntryCategoryPickerScreen
      final input = find.byType(TextField);
      expect(input, findsOneWidget);

      await tester.enterText(input, 'b');
      await tester.pump();
      await tester.enterText(input, 'bo');
      await tester.pump();
      await tester.enterText(input, 'bol');
      await tester.pump();
      await tester.enterText(input, 'bolt');
      await tester.pump();
      await tester.enterText(input, 'bolt 25000');
      await tester.pump();

      // Los streams de atajos y categorías NO deben haberse vuelto a consultar
      expect(
        shortcutsRepo.watchShortcutsCalls,
        initialShortcutsCalls,
        reason:
            'watchShortcuts no debe llamarse al escribir en el campo natural',
      );
      expect(
        categoriesRepo.watchActiveCalls,
        initialCategoriesCalls,
        reason: 'watchActive no debe llamarse al escribir en el campo natural',
      );
    },
  );

  testWidgets(
    'EntryCategoryPickerScreen no duplica suscripción a categorías en CategoryGrid',
    (tester) async {
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
            categoriesRepositoryProvider.overrideWithValue(categoriesRepo),
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

      // Debe haber exactamente 1 suscripción activa a categorías, no 2
      expect(
        categoriesRepo.watchActiveCalls,
        1,
        reason: 'CategoryGrid debe reutilizar las categorías ya suscritas por el picker',
      );
    },
  );
}
