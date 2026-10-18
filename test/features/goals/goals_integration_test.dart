import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/home/ui/home_screen.dart';
import 'package:pockt/features/settings/ui/settings_screen.dart';

void main() {
  late AppDatabase db;
  late GoalsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repo = GoalsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('Ajustes -> Tu dinero tiene acceso a Metas', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          goalsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tu dinero'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final goalsTile = find.byKey(const ValueKey('settings-goals-tile'));
    expect(goalsTile, findsOneWidget);
    expect(find.text('Metas'), findsOneWidget);
  });

  testWidgets(
    'Inicio muestra píldora de Metas si hay metas y se oculta si no hay',
    (tester) async {
      // 1. Sin metas: píldora oculta
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            goalsRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(theme: buildDarkTheme(), home: const HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home-pill-goals')), findsNothing);

      // 2. Con meta: píldora visible y al tocar abre la hoja
      await repo.createGoal(
        name: 'Viaje a Bariloche',
        icon: 'airplane-tilt',
        targetAmount: 4000000,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('home-pill-goals')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-pill-goals')));
      await tester.pumpAndSettle();
      expect(find.text('Viaje a Bariloche'), findsOneWidget);
    },
  );
}
