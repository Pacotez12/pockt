import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/income/ui/carry_over_card.dart';

void main() {
  late AppDatabase db;
  final periodStart = DateTime(2026, 10, 15);

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget build() => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      theme: buildDarkTheme(),
      home: Scaffold(
        body: CarryOverCard(amount: 500000, periodStart: periodStart),
      ),
    ),
  );

  test('carryOverDecided compara contra el inicio del período', () {
    expect(carryOverDecided('2026-10-15', periodStart), isTrue);
    expect(carryOverDecided('2026-09-30', periodStart), isFalse);
    expect(carryOverDecided(null, periodStart), isFalse);
  });

  testWidgets('Sumar a esta quincena guarda la decisión del período', (
    tester,
  ) async {
    await tester.pumpWidget(build());
    await tester.pump();

    expect(find.textContaining('Te sobraron'), findsOneWidget);
    // Sin metas no se ofrece pasar a una meta.
    expect(find.text('Pasar a una meta'), findsNothing);

    await tester.tap(find.text('Sumar a esta quincena'));
    await tester.pump();

    final saved = await SettingsRepository(db).get(kCarryOverDecidedKey);
    expect(saved, '2026-10-15');
  });

  testWidgets('Pasar a una meta aporta el sobrante y guarda la decisión', (
    tester,
  ) async {
    final goals = GoalsRepository(db);
    final goalId = await goals.createGoal(
      name: 'PC Gamer',
      icon: 'laptop',
      targetAmount: 15000000,
    );

    await tester.pumpWidget(build());
    await tester.pump();

    await tester.tap(find.text('Pasar a una meta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PC Gamer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Deja correr las escrituras reales de Drift fuera del reloj falso.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    final contribs = await db.select(db.goalContributions).get();
    expect(contribs.single.goalId, goalId);
    expect(contribs.single.amount, 500000);
    expect(
      await SettingsRepository(db).get(kCarryOverDecidedKey),
      '2026-10-15',
    );
  });
}
