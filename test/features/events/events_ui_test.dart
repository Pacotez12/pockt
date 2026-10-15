import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/events/data/events_repository.dart';
import 'package:pockt/features/events/ui/events_screen.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionsRepository txRepo;
  late EventsRepository eventsRepo;
  late String comidaId;

  setUp(() async {
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    txRepo = TransactionsRepository(db);
    eventsRepo = EventsRepository(db);

    final cats = await db.select(db.categories).get();
    comidaId = cats.firstWhere((c) => c.name == 'Comida').id;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        transactionsRepositoryProvider.overrideWithValue(txRepo),
        eventsRepositoryProvider.overrideWithValue(eventsRepo),
      ],
      child: MaterialApp(theme: buildDarkTheme(), home: child),
    );
  }

  testWidgets('EventsScreen shows empty state when no events exist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    await tester.pumpWidget(buildTestApp(const EventsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No tenés eventos'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('create-event-empty-btn')),
      findsOneWidget,
    );
  });

  testWidgets('EventsScreen creates an event', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    await tester.pumpWidget(buildTestApp(const EventsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-event-empty-btn')));
    await tester.pumpAndSettle();

    // Fill event form
    await tester.enterText(
      find.byKey(const ValueKey('event-name-input')),
      'Viaje a Encarnación',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('save-event-btn')));
    await tester.pumpAndSettle();

    expect(find.text('Viaje a Encarnación'), findsOneWidget);
  });

  testWidgets('Entry flow shows active event chip when an event is active', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    // Create an active event
    await eventsRepo.createEvent(
      name: 'Cumpleaños Luque',
      icon: 'cake',
      startDate: DateTime(2026, 10, 15),
      isActive: true,
    );

    await tester.pumpWidget(
      buildTestApp(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showEntryFlow(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('active-event-chip')), findsOneWidget);
    expect(find.textContaining('Cumpleaños Luque'), findsOneWidget);
  });

  testWidgets(
    'EventDetailScreen shows total spent, category breakdown and transactions',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.pumpWidget(const SizedBox()));

      final eventId = await eventsRepo.createEvent(
        name: 'Asadacho',
        icon: 'beer-bottle',
        startDate: DateTime(2026, 10, 15),
        isActive: true,
      );

      // Add expense linked to event
      await txRepo.add(
        type: TxType.expense,
        amount: 150000,
        categoryId: comidaId,
        merchant: 'Carnicería',
        occurredAt: DateTime(2026, 10, 15),
      );

      await tester.pumpWidget(
        buildTestApp(EventDetailScreen(eventId: eventId)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Asadacho'), findsWidgets);
      expect(find.text('Gs. 150.000'), findsNWidgets(3));
      expect(find.text('Comida'), findsOneWidget);
      expect(find.text('Carnicería'), findsOneWidget);
    },
  );
}
