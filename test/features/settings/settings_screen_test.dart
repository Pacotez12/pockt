import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/income/ui/income_schedule_screen.dart';
import 'package:pockt/features/recurring/ui/recurring_screen.dart';
import 'package:pockt/features/settings/ui/category_keywords_screen.dart';
import 'package:pockt/features/settings/ui/settings_screen.dart';

void main() {
  late AppDatabase testDb;
  late FakeNotifier notifier;

  setUp(() async {
    setLocalZone('America/Asuncion');
    testDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    notifier = FakeNotifier();
  });

  tearDown(() async {
    await testDb.close();
  });

  Future<void> pumpSettingsScreen(WidgetTester tester) async {
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
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('SettingsScreen lista Categorías, Esquema de cobro y Recurrentes', (tester) async {
    await pumpSettingsScreen(tester);

    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Categorías'), findsOneWidget);
    expect(find.text('Esquema de cobro'), findsOneWidget);
    expect(find.text('Recurrentes'), findsOneWidget);
  });

  testWidgets('tocar Categorías navega a CategoryKeywordsScreen', (tester) async {
    await pumpSettingsScreen(tester);

    await tester.tap(find.text('Categorías'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryKeywordsScreen), findsOneWidget);
  });

  testWidgets('tocar Esquema de cobro navega a IncomeScheduleScreen', (tester) async {
    await pumpSettingsScreen(tester);

    await tester.tap(find.text('Esquema de cobro'));
    await tester.pumpAndSettle();

    expect(find.byType(IncomeScheduleScreen), findsOneWidget);
  });

  testWidgets('tocar Recurrentes navega a RecurringScreen', (tester) async {
    await pumpSettingsScreen(tester);

    await tester.tap(find.text('Recurrentes'));
    await tester.pumpAndSettle();

    expect(find.byType(RecurringScreen), findsOneWidget);
  });
}
