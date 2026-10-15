import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/goals/ui/goal_detail_screen.dart';

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

  Widget buildDetail(String goalId) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        goalsRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: buildDarkTheme(),
        home: GoalDetailScreen(goalId: goalId),
      ),
    );
  }

  testWidgets(
    'muestra anillo, datos de avance, botones Aportar/Retirar e historial',
    (tester) async {
      final goalId = await repo.createGoal(
        name: 'Fondo de emergencia',
        icon: 'shield-check',
        targetAmount: 10000000,
        targetDate: DateTime(2027, 1, 1),
      );

      await repo.addContribution(
        goalId: goalId,
        amount: 4000000,
        date: DateTime(2026, 10, 1),
        note: 'Aporte inicial',
      );

      await tester.pumpWidget(buildDetail(goalId));
      await tester.pumpAndSettle();

      expect(find.text('Fondo de emergencia'), findsOneWidget);
      // 4.000.000 de 10.000.000 -> 40 %
      expect(find.textContaining('40 %'), findsOneWidget);
      expect(find.textContaining('4.000.000'), findsWidgets);

      // Botones de acción
      expect(
        find.byKey(const ValueKey('goal-contribute-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('goal-withdraw-button')),
        findsOneWidget,
      );

      // Historial (puede estar abajo del scroll en pantalla de test 800x600)
      expect(
        find.text('Historial de aportes', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Aporte inicial', skipOffstage: false), findsOneWidget);

      // Menú de opciones (editar / archivar)
      expect(find.byKey(const ValueKey('goal-options-menu')), findsOneWidget);
    },
  );
}
