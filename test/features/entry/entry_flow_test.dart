import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/transactions/data/categories_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:timezone/data/latest.dart' as tz;

class FailingTransactionsRepo extends TransactionsRepository {
  FailingTransactionsRepo(super.db);

  @override
  Future<String> add({
    required TxType type,
    required int amount,
    required String categoryId,
    required DateTime occurredAt,
    String? merchant,
    String? note,
  }) async {
    throw Exception('Error simulado al guardar');
  }

  @override
  Future<void> update(
    String id, {
    int? amount,
    String? categoryId,
    DateTime? occurredAt,
    String? merchant,
    String? note,
  }) async {
    throw Exception('Error simulado al actualizar');
  }
}

void main() {
  late AppDatabase testDb;
  late CategoriesRepository catRepo;
  late TransactionsRepository txRepo;

  setUpAll(() {
    tz.initializeTimeZones();
  });

  // Las lecturas de streams de Drift dentro de un test se hacen con
  // t.runAsync: con el reloj simulado de testWidgets, `.watch().first`
  // deja trabajo pendiente y el test nunca termina.
  setUp(() async {
    setLocalZone('America/Asuncion');
    // closeStreamsSynchronously evita que los streams de Drift dejen timers
    // pendientes que cuelgan el reloj simulado de testWidgets.
    testDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    catRepo = CategoriesRepository(testDb);
    txRepo = TransactionsRepository(testDb);
  });

  tearDown(() async {
    await testDb.close();
  });

  Future<void> openEntry(
    WidgetTester tester, {
    TransactionsRepository? customTxRepo,
    TxType initialType = TxType.expense,
    String? initialCategoryId,
    TxView? editing,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          if (customTxRepo != null)
            transactionsRepositoryProvider.overrideWithValue(customTxRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showEntryFlow(
                    context,
                    initialType: initialType,
                    initialCategoryId: initialCategoryId,
                    editing: editing,
                  ),
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

  testWidgets('categoría → monto → guardar crea el gasto', (t) async {
    await openEntry(t);
    await t.tap(find.text('Comida'));
    await t.pumpAndSettle();
    for (final k in ['1', '5', '000']) {
      await t.tap(find.text(k));
      await t.pump();
    }
    expect(find.text('Gs. 15.000'), findsOneWidget);
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    final recent = (await t.runAsync(() => txRepo.watchRecent().first))!;
    expect(recent.single.tx.amount, 15000);
    expect(recent.single.category.name, 'Comida');
  });

  testWidgets('Guardar deshabilitado con monto 0', (t) async {
    await openEntry(t);
    await t.tap(find.text('Comida'));
    await t.pumpAndSettle();
    final button = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'));
    expect(button.onPressed, isNull);
  });

  testWidgets('error al guardar mantiene la pantalla y el monto', (t) async {
    final failingRepo = FailingTransactionsRepo(testDb);
    await openEntry(t, customTxRepo: failingRepo);
    await t.tap(find.text('Comida'));
    await t.pumpAndSettle();
    for (final k in ['1', '5', '000']) {
      await t.tap(find.text(k));
      await t.pump();
    }
    expect(find.text('Gs. 15.000'), findsOneWidget);
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();

    expect(find.text('Gs. 15.000'), findsOneWidget);
    expect(find.textContaining('Error simulado al guardar'), findsOneWidget);
  });

  testWidgets('el interruptor Ingreso muestra categorías de ingreso', (t) async {
    await openEntry(t);
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Sueldo'), findsNothing);

    await t.tap(find.text('Ingreso'));
    await t.pumpAndSettle();

    expect(find.text('Sueldo'), findsOneWidget);
    expect(find.text('Comida'), findsNothing);
  });

  testWidgets('edición precarga y actualiza', (t) async {
    final categories = (await t.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
    final transporte = categories.firstWhere((c) => c.name == 'Transporte');
    final id = (await t.runAsync(() => txRepo.add(
      type: TxType.expense,
      amount: 28500,
      categoryId: transporte.id,
      occurredAt: DateTime.utc(2026, 10, 8, 12, 0),
    )))!;
    final txList = (await t.runAsync(() => txRepo.watchRecent().first))!;
    final txView = txList.firstWhere((v) => v.tx.id == id);

    await openEntry(t, editing: txView);
    expect(find.text('Gs. 28.500'), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await t.tap(find.text('⌫'));
      await t.pump();
    }
    for (final k in ['3', '0', '000']) {
      await t.tap(find.text(k));
      await t.pump();
    }
    expect(find.text('Gs. 30.000'), findsOneWidget);

    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();

    final updatedList = (await t.runAsync(() => txRepo.watchRecent().first))!;
    expect(updatedList.single.tx.amount, 30000);
  });

  testWidgets('escribir bolt 28.500 y confirmar la propuesta abre el teclado de Transporte con Gs. 28.500', (t) async {
    await openEntry(t);
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    await t.enterText(textField, 'bolt 28.500');
    await t.pumpAndSettle();

    final proposal = find.byKey(const ValueKey('natural-proposal-card'));
    expect(proposal, findsOneWidget);
    expect(find.descendant(of: proposal, matching: find.text('Transporte')), findsOneWidget);
    expect(find.descendant(of: proposal, matching: find.text('Gs. 28.500')), findsOneWidget);

    await t.tap(proposal);
    await t.pumpAndSettle();

    expect(find.text('Gs. 28.500'), findsOneWidget);
    expect(find.text('Transporte'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
  });

  testWidgets('con texto bolt 60000 el movimiento guardado no tiene hora 00:00', (t) async {
    await openEntry(t);
    final textField = find.byType(TextField);
    await t.enterText(textField, 'bolt 60000');
    await t.pumpAndSettle();

    final proposal = find.byKey(const ValueKey('natural-proposal-card'));
    await t.tap(proposal);
    await t.pumpAndSettle();

    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();

    final txs = (await t.runAsync(() => txRepo.watchRecent().first))!;
    final tx = txs.first.tx;
    final local = toLocal(tx.occurredAt);
    expect(local.hour == 0 && local.minute == 0 && local.second == 0, isFalse);
  });

  testWidgets('al tocar una categoría en la grilla existe un Hero en vuelo con tag cat-<id>', (t) async {
    await openEntry(t);

    final cat = (await t.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!
        .firstWhere((c) => c.name == 'Comida');
    final heroTag = 'cat-${cat.id}';

    // Antes del tap no hay shuttle en vuelo
    expect(find.byKey(ValueKey('hero-flight-$heroTag')), findsNothing);

    // Tocamos la categoría Comida en la grilla
    await t.tap(find.text('Comida'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 150));

    // Durante la transición, el Hero está en vuelo dentro del Overlay
    final flightShuttle = find.byKey(ValueKey('hero-flight-$heroTag'));
    expect(flightShuttle, findsOneWidget);
    expect(
      find.descendant(of: find.byType(Overlay), matching: flightShuttle),
      findsOneWidget,
    );

    // Completamos la animación
    await t.pumpAndSettle();

    // Al finalizar la transición, el shuttle termina y la pantalla de teclado está lista
    expect(flightShuttle, findsNothing);
    expect(find.text('Gs. 0'), findsOneWidget);
  });

  testWidgets('con reduce motion la transición no monta el Hero en vuelo', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
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
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();

    final cat = (await t.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!
        .firstWhere((c) => c.name == 'Comida');
    final heroTag = 'cat-${cat.id}';

    await t.tap(find.text('Comida'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 150));

    // Con reduce motion no hay Hero en vuelo en el Overlay
    expect(find.byKey(ValueKey('hero-flight-$heroTag')), findsNothing);

    await t.pumpAndSettle();
    expect(find.text('Gs. 0'), findsOneWidget);
  });
}
