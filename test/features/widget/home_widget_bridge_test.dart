import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/entry/ui/amount_keypad.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/widget/home_widget_bridge.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    await db.delete(db.categories).go();
  });


  tearDown(() async {
    await db.close();
  });

  Future<Category> createCategory({
    required String id,
    required String name,
    required int sortOrder,
    bool archived = false,
  }) async {
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            id: id,
            name: name,
            icon: 'tag',
            colorLight: 0xFFFFFFFF,
            colorDark: 0xFF000000,
            kind: CategoryKind.expense,
            sortOrder: sortOrder,
            archived: Value(archived),
          ),
        );
    return (await (db.select(db.categories)..where((c) => c.id.equals(id))).getSingle());
  }

  Future<void> addExpense({
    required String categoryId,
    required DateTime occurredAt,
  }) async {
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'tx-${occurredAt.microsecondsSinceEpoch}-${categoryId.hashCode}',
            type: TxType.expense,
            amount: 50000,
            categoryId: categoryId,
            occurredAt: occurredAt,
            createdAt: occurredAt,
            updatedAt: occurredAt,
            source: TxSource.manual,
          ),
        );
  }

  test('topCategories ordena por cantidad de gastos en los últimos 60 días', () async {
    final now = DateTime(2026, 10, 9, 12, 0);

    final catA = await createCategory(id: 'cat-a', name: 'Comida', sortOrder: 1);
    final catB = await createCategory(id: 'cat-b', name: 'Transporte', sortOrder: 2);
    final catC = await createCategory(id: 'cat-c', name: 'Ocio', sortOrder: 3);
    final catD = await createCategory(id: 'cat-d', name: 'Salud', sortOrder: 4);

    // Comida: 3 gastos recientes
    await addExpense(categoryId: catA.id, occurredAt: now.subtract(const Duration(days: 5)));
    await addExpense(categoryId: catA.id, occurredAt: now.subtract(const Duration(days: 10)));
    await addExpense(categoryId: catA.id, occurredAt: now.subtract(const Duration(days: 15)));

    // Ocio: 5 gastos recientes
    for (var i = 1; i <= 5; i++) {
      await addExpense(categoryId: catC.id, occurredAt: now.subtract(Duration(days: i)));
    }

    // Transporte: 1 gasto reciente
    await addExpense(categoryId: catB.id, occurredAt: now.subtract(const Duration(days: 20)));

    // Salud: 0 gastos

    final top = await topCategories(db, n: 4, nowLocal: now);
    expect(top.map((c) => c.id).toList(), [catC.id, catA.id, catB.id, catD.id]);
  });

  test('topCategories excluye movimientos de más de 60 días atrás', () async {
    final now = DateTime(2026, 10, 9, 12, 0);

    final catA = await createCategory(id: 'cat-a', name: 'Comida', sortOrder: 1);
    final catB = await createCategory(id: 'cat-b', name: 'Transporte', sortOrder: 2);

    // Comida tiene 10 gastos pero ocurrieron hace 65 días
    for (var i = 0; i < 10; i++) {
      await addExpense(categoryId: catA.id, occurredAt: now.subtract(Duration(days: 65 + i)));
    }

    // Transporte tiene 2 gastos recientes (hace 10 y 20 días)
    await addExpense(categoryId: catB.id, occurredAt: now.subtract(const Duration(days: 10)));
    await addExpense(categoryId: catB.id, occurredAt: now.subtract(const Duration(days: 20)));

    final top = await topCategories(db, n: 2, nowLocal: now);
    expect(top.first.id, catB.id);
  });

  test('topCategories excluye categorías archivadas', () async {
    final now = DateTime(2026, 10, 9, 12, 0);

    final catArchived = await createCategory(id: 'cat-arch', name: 'Archivada', sortOrder: 1, archived: true);
    final catActive = await createCategory(id: 'cat-act', name: 'Activa', sortOrder: 2, archived: false);

    // La archivada tiene 20 gastos recientes
    for (var i = 0; i < 20; i++) {
      await addExpense(categoryId: catArchived.id, occurredAt: now.subtract(Duration(days: i + 1)));
    }

    final top = await topCategories(db, n: 4, nowLocal: now);
    expect(top.any((c) => c.id == catArchived.id), isFalse);
    expect(top.any((c) => c.id == catActive.id), isTrue);
  });

  test('topCategories completa hasta 4 usando sortOrder para categorías sin gastos', () async {
    final now = DateTime(2026, 10, 9, 12, 0);

    final cat1 = await createCategory(id: 'cat-1', name: 'Cat 1', sortOrder: 10);
    final cat2 = await createCategory(id: 'cat-2', name: 'Cat 2', sortOrder: 20);
    final cat3 = await createCategory(id: 'cat-3', name: 'Cat 3', sortOrder: 30);
    final cat4 = await createCategory(id: 'cat-4', name: 'Cat 4', sortOrder: 40);
    await createCategory(id: 'cat-5', name: 'Cat 5', sortOrder: 50);

    // Solo Cat 3 tiene 1 gasto
    await addExpense(categoryId: cat3.id, occurredAt: now.subtract(const Duration(days: 2)));

    // Debe devolver [Cat 3 (por gasto), Cat 1 (sortOrder 10), Cat 2 (sortOrder 20), Cat 4 (sortOrder 40)]
    final top = await topCategories(db, n: 4, nowLocal: now);
    expect(top.map((c) => c.id).toList(), [cat3.id, cat1.id, cat2.id, cat4.id]);
  });

  test('HomeWidgetBridge.update guarda las 4 categorías y llama a updateWidget en la plataforma', () async {
    final now = DateTime(2026, 10, 9, 12, 0);
    final cat1 = await createCategory(id: 'cat-1', name: 'Cat 1', sortOrder: 10);
    final cat2 = await createCategory(id: 'cat-2', name: 'Cat 2', sortOrder: 20);
    final cat3 = await createCategory(id: 'cat-3', name: 'Cat 3', sortOrder: 30);
    final cat4 = await createCategory(id: 'cat-4', name: 'Cat 4', sortOrder: 40);

    final fakePlatform = FakeHomeWidgetPlatform();
    addTearDown(fakePlatform.dispose);

    await HomeWidgetBridge.update(db: db, nowLocal: now, platform: fakePlatform);

    expect(fakePlatform.data['category_count'], 4);
    expect(fakePlatform.data['category_id_0'], cat1.id);
    expect(fakePlatform.data['category_name_0'], cat1.name);
    expect(fakePlatform.data['category_id_1'], cat2.id);
    expect(fakePlatform.data['category_id_2'], cat3.id);
    expect(fakePlatform.data['category_id_3'], cat4.id);
    expect(fakePlatform.updateCallCount, 1);
  });

  testWidgets('handleWidgetLaunchUri con pockt://entry?category=<id> abre AmountKeypadScreen con esa categoría', (tester) async {
    final cat = await createCategory(id: 'cat-test-1', name: 'Farmacia', sortOrder: 1);

    late BuildContext targetContext;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                targetContext = ctx;
                return const Text('Home');
              },
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      unawaited(handleWidgetLaunchUri(
        targetContext,
        Uri.parse('pockt://entry?category=${cat.id}'),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.byType(AmountKeypadScreen), findsOneWidget);
    expect(find.text('Farmacia'), findsOneWidget);
  });

  testWidgets('handleWidgetLaunchUri con pockt://entry abre selector de categorías', (tester) async {
    await createCategory(id: 'cat-test-2', name: 'Super', sortOrder: 1);

    late BuildContext targetContext;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                targetContext = ctx;
                return const Text('Home');
              },
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      unawaited(handleWidgetLaunchUri(
        targetContext,
        Uri.parse('pockt://entry'),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.byType(EntryCategoryPickerScreen), findsOneWidget);
  });

  testWidgets('handleWidgetLaunchUri con uri ajena no navega', (tester) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                targetContext = ctx;
                return const Text('Home');
              },
            ),
          ),
        ),
      ),
    );

    unawaited(handleWidgetLaunchUri(
      targetContext,
      Uri.parse('https://pockt.app/something'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(AmountKeypadScreen), findsNothing);
    expect(find.byType(EntryCategoryPickerScreen), findsNothing);
  });
}

