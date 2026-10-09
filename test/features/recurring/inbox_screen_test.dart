import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/entry/ui/amount_keypad.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/recurring/ui/inbox_screen.dart';

void main() {
  late AppDatabase testDb;
  late FakeNotifier notifier;
  late SuggestionsRepository sugRepo;
  const comidaId = '018f0000-0000-7000-8000-000000000001';

  setUp(() async {
    setLocalZone('America/Asuncion');
    testDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    notifier = FakeNotifier();
    sugRepo = SuggestionsRepository(testDb);
  });

  tearDown(() async {
    await testDb.close();
  });

  Future<void> pumpInboxScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          notifierProvider.overrideWithValue(notifier),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const InboxScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('estado vacío cuando no hay sugerencias pendientes', (tester) async {
    await pumpInboxScreen(tester);

    expect(find.text('Todo al día'), findsOneWidget);
    expect(
      find.text('No tenés movimientos pendientes por confirmar.'),
      findsOneWidget,
    );
  });

  testWidgets('lista muestra sugerencias con nombre y monto', (tester) async {
    await tester.runAsync(() async {
      await sugRepo.createIfAbsent(
        type: TxType.expense,
        amount: 55000,
        categoryId: comidaId,
        merchant: 'Netflix',
        occurredAt: DateTime(2026, 10, 15, 10, 0),
        source: TxSource.recurring,
        sourceRef: 'rule-netflix',
      );
      await sugRepo.createIfAbsent(
        type: TxType.expense,
        amount: 120000,
        categoryId: comidaId,
        merchant: 'ANDE',
        occurredAt: DateTime(2026, 10, 15, 11, 0),
        source: TxSource.recurring,
        sourceRef: 'rule-ande',
      );
    });

    await pumpInboxScreen(tester);

    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Gs. 55.000'), findsOneWidget);
    expect(find.text('ANDE'), findsOneWidget);
    expect(find.text('Gs. 120.000'), findsOneWidget);
  });

  testWidgets('confirmar crea movimiento en transactions y la saca de la bandeja', (tester) async {
    await tester.runAsync(() async {
      await sugRepo.createIfAbsent(
        type: TxType.expense,
        amount: 45000,
        categoryId: comidaId,
        merchant: 'Spotify',
        occurredAt: DateTime(2026, 10, 15, 9, 0),
        source: TxSource.recurring,
        sourceRef: 'rule-spotify',
      );
    });

    await pumpInboxScreen(tester);
    expect(find.text('Spotify'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Confirmar'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Spotify'), findsNothing);
    expect(find.text('Todo al día'), findsOneWidget);

    final txs = await tester.runAsync(() => testDb.select(testDb.transactions).get());
    expect(txs!.length, 1);
    expect(txs.first.amount, 45000);
    expect(txs.first.merchant, 'Spotify');
    expect(txs.first.source, TxSource.recurring);
  });

  testWidgets('monto 0 no deja confirmar directo (obliga a editar)', (tester) async {
    await tester.runAsync(() async {
      await sugRepo.createIfAbsent(
        type: TxType.income,
        amount: 0,
        categoryId: null,
        merchant: 'Salario variable',
        occurredAt: DateTime(2026, 10, 15, 8, 0),
        source: TxSource.incomeSchedule,
        sourceRef: 'income-1',
      );
    });

    await pumpInboxScreen(tester);

    expect(find.text('Salario variable'), findsOneWidget);
    expect(find.text('Sin monto'), findsOneWidget);

    // Tocar Confirmar no hace nada porque está deshabilitado
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final txsBefore = await tester.runAsync(() => testDb.select(testDb.transactions).get());
    expect(txsBefore!.isEmpty, isTrue);
    expect(find.text('Salario variable'), findsOneWidget);

    // Tocar Editar abre el teclado
    await tester.tap(find.text('Editar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(AmountKeypadScreen), findsOneWidget);

    // Ingresar 25.000: '2', '5', '0', '0', '0'
    await tester.tap(find.text('2'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('5'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('0'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('0'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('0'));
    await tester.pump(const Duration(milliseconds: 50));

    // Guardar
    await tester.runAsync(() async {
      await tester.tap(find.text('Guardar'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // La sugerencia fue confirmada y desaparece de la bandeja
    expect(find.text('Salario variable'), findsNothing);
    final txsAfter = await tester.runAsync(() => testDb.select(testDb.transactions).get());
    expect(txsAfter!.length, 1);
    expect(txsAfter.first.amount, 25000);
  });

  testWidgets('descartar la saca de la bandeja sin crear movimiento', (tester) async {
    await tester.runAsync(() async {
      await sugRepo.createIfAbsent(
        type: TxType.expense,
        amount: 80000,
        categoryId: comidaId,
        merchant: 'Gasto Opcional',
        occurredAt: DateTime(2026, 10, 15, 12, 0),
        source: TxSource.recurring,
        sourceRef: 'rule-opt',
      );
    });

    await pumpInboxScreen(tester);
    expect(find.text('Gasto Opcional'), findsOneWidget);

    // Swipe para descartar
    await tester.drag(find.text('Gasto Opcional'), const Offset(-500, 0));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('Gasto Opcional'), findsNothing);
    final txs = await tester.runAsync(() => testDb.select(testDb.transactions).get());
    expect(txs!.isEmpty, isTrue);

    final sugs = await tester.runAsync(() => testDb.select(testDb.suggestedTransactions).get());
    expect(sugs!.first.status, 'dismissed');
  });
}
