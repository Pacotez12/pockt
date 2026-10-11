import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/entry/ui/amount_keypad.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  late AppDatabase testDb;
  late SettingsRepository settingsRepo;
  late TransactionsRepository txRepo;

  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() async {
    setLocalZone('America/Asuncion');
    testDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    settingsRepo = SettingsRepository(testDb);
    txRepo = TransactionsRepository(testDb);
  });

  tearDown(() async {
    Haptics.enabled = true;
    Haptics.debugRecorder = null;
    await testDb.close();
  });

  Widget buildApp({required Widget child}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(testDb),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        transactionsRepositoryProvider.overrideWithValue(txRepo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  testWidgets('con mostUsed la grilla ordena por uso de 90 días', (t) async {
    await settingsRepo.set(SettingsKeys.entryCategoryOrder, 'mostUsed');

    final categories = await (testDb.select(testDb.categories)
          ..where((c) => c.kind.equalsValue(CategoryKind.expense) & c.archived.equals(false)))
        .get();
    final comida = categories.firstWhere((c) => c.name == 'Comida');
    final transporte = categories.firstWhere((c) => c.name == 'Transporte');

    // Agregamos 3 movimientos a Transporte y 1 a Comida en los últimos 90 días
    final now = DateTime.now();
    for (var i = 0; i < 3; i++) {
      await txRepo.add(
        type: TxType.expense,
        amount: 10000,
        categoryId: transporte.id,
        occurredAt: now.subtract(Duration(days: i + 1)),
      );
    }
    await txRepo.add(
      type: TxType.expense,
      amount: 20000,
      categoryId: comida.id,
      occurredAt: now.subtract(const Duration(days: 1)),
    );

    // Agregamos un movimiento viejo (>90 días) a Comida que no debe contar
    await txRepo.add(
      type: TxType.expense,
      amount: 50000,
      categoryId: comida.id,
      occurredAt: now.subtract(const Duration(days: 100)),
    );

    await t.pumpWidget(
      buildApp(
        child: CategoryGrid(
          currentType: TxType.expense,
          onCategorySelected: (_) {},
        ),
      ),
    );
    await t.pumpAndSettle();

    // Transporte (3 usos recientes) debe aparecer antes que Comida (1 uso reciente)
    final transporteFinder = find.text('Transporte');
    final comidaFinder = find.text('Comida');
    expect(transporteFinder, findsOneWidget);
    expect(comidaFinder, findsOneWidget);

    final transportePos = t.getTopLeft(transporteFinder);
    final comidaPos = t.getTopLeft(comidaFinder);

    // Transporte está en una posición anterior en la grilla (fila menor o columna menor)
    final comesBefore = transportePos.dy < comidaPos.dy ||
        (transportePos.dy == comidaPos.dy && transportePos.dx < comidaPos.dx);
    expect(comesBefore, isTrue, reason: 'Transporte (3 usos) debe aparecer antes que Comida (1 uso)');
  });

  testWidgets('la tecla muestra 00 y agrega dos ceros cuando quickKey es 00', (t) async {
    await settingsRepo.set(SettingsKeys.entryQuickKey, '00');

    final categories = await (testDb.select(testDb.categories)
          ..where((c) => c.kind.equalsValue(CategoryKind.expense)))
        .get();
    final comida = categories.first;

    await t.pumpWidget(
      buildApp(
        child: AmountKeypadScreen(
          category: comida,
          type: TxType.expense,
        ),
      ),
    );
    await t.pumpAndSettle();

    // La tecla '00' está visible y no '000'
    expect(find.text('00'), findsOneWidget);
    expect(find.text('000'), findsNothing);

    // Presionamos 5 y luego 00 -> 500
    await t.tap(find.text('5'));
    await t.pump();
    await t.tap(find.text('00'));
    await t.pump();

    expect(find.text('Gs. 500'), findsOneWidget);
  });

  testWidgets('con askNote aparece el campo antes de guardar', (t) async {
    await settingsRepo.set(SettingsKeys.entryAskNote, 'true');

    final categories = await (testDb.select(testDb.categories)
          ..where((c) => c.kind.equalsValue(CategoryKind.expense)))
        .get();
    final comida = categories.first;

    await t.pumpWidget(
      buildApp(
        child: AmountKeypadScreen(
          category: comida,
          type: TxType.expense,
        ),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.text('1'));
    await t.pump();
    await t.tap(find.text('5'));
    await t.pump();

    // Presionamos Guardar
    await t.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await t.pumpAndSettle();

    // Debe aparecer el diálogo con el campo de nota/comercio
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('Nota'), findsWidgets);
  });

  test('con vibración apagada Haptics.debugRecorder no registra nada', () async {
    Haptics.enabled = false;
    final recorded = <String>[];
    Haptics.debugRecorder = (kind) => recorded.add(kind);

    await Haptics.key();
    await Haptics.save();
    await Haptics.tick();
    await Haptics.warning();
    await Haptics.danger();

    expect(recorded, isEmpty);
  });
}
