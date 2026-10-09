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
import 'package:pockt/features/recurring/data/recurring_repository.dart';
import 'package:pockt/features/recurring/domain/recurrence.dart';
import 'package:pockt/features/recurring/ui/recurring_screen.dart';

void main() {
  late AppDatabase testDb;
  late FakeNotifier notifier;
  late RecurringRepository recurringRepo;
  const comidaId = '018f0000-0000-7000-8000-000000000001';

  setUp(() async {
    setLocalZone('America/Asuncion');
    testDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    notifier = FakeNotifier();
    recurringRepo = RecurringRepository(
      testDb,
      clock: () => DateTime(2026, 10, 8, 12, 0),
      notifier: notifier,
    );
  });

  tearDown(() async {
    await testDb.close();
  });

  Future<void> pumpRecurringScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          notifierProvider.overrideWithValue(notifier),
          recurringRepositoryProvider.overrideWithValue(recurringRepo),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const RecurringScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('estado vacío con invitación a crear el primero', (tester) async {
    await pumpRecurringScreen(tester);

    expect(find.text('Recurrentes'), findsOneWidget);
    expect(find.text('Sin recurrentes'), findsOneWidget);
    expect(find.text('Agregar recurrente'), findsOneWidget);
  });

  testWidgets('crear un recurrente lo lista con su próxima fecha', (tester) async {
    await pumpRecurringScreen(tester);

    // Abrir formulario de creación
    await tester.tap(find.byKey(const ValueKey('add-recurring-button')));
    await tester.pumpAndSettle();

    // Nombre
    await tester.enterText(
      find.byKey(const ValueKey('recurring-name-input')),
      'Netflix',
    );
    await tester.pumpAndSettle();

    // Monto usando el teclado
    await tester.tap(find.byKey(const ValueKey('recurring-amount-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AmountKeypadScreen), findsOneWidget);

    // Ingresar 55.000: '5', '5', '0', '0', '0'
    await tester.tap(find.text('5'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('5'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('0'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('0'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('0'));
    await tester.pump(const Duration(milliseconds: 50));

    // Guardar en teclado
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Guardar regla recurrente
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('save-recurring-button')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Netflix aparece listado
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Gs. 55.000'), findsOneWidget);
    expect(find.textContaining('Próximo:'), findsOneWidget);
  });

  testWidgets('pausar y despausar una regla recurrente', (tester) async {
    await tester.runAsync(() async {
      await recurringRepo.add(
        name: 'Spotify',
        type: TxType.expense,
        amount: 35000,
        categoryId: comidaId,
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 15,
      );
    });

    await pumpRecurringScreen(tester);
    expect(find.text('Spotify'), findsOneWidget);

    final rules = await tester.runAsync(() => recurringRepo.watchAll().first);
    final ruleId = rules!.first.id;

    // Toggle active
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey('toggle-active-$ruleId')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final updated = await tester.runAsync(() => recurringRepo.watchAll().first);
    expect(updated!.first.active, isFalse);
  });

  testWidgets('borrar una regla recurrente la quita de la lista', (tester) async {
    await tester.runAsync(() async {
      await recurringRepo.add(
        name: 'Gimnasio',
        type: TxType.expense,
        amount: 200000,
        categoryId: comidaId,
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 5,
      );
    });

    await pumpRecurringScreen(tester);
    expect(find.text('Gimnasio'), findsOneWidget);

    final rules = await tester.runAsync(() => recurringRepo.watchAll().first);
    final ruleId = rules!.first.id;

    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey('delete-recurring-$ruleId')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('Gimnasio'), findsNothing);
  });
}
