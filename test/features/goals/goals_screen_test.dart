import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/goals/ui/goals_screen.dart';

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

  Widget buildScreen() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        goalsRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(theme: buildDarkTheme(), home: const GoalsScreen()),
    );
  }

  testWidgets(
    'lista de metas muestra encabezado de ahorrado total y tarjetas de metas',
    (tester) async {
      final g1 = await repo.createGoal(
        name: 'Fondo de emergencia',
        icon: 'shield-check',
        targetAmount: 10000000,
        targetDate: DateTime(2027, 10, 15),
      );
      await repo.addContribution(
        goalId: g1,
        amount: 2500000,
        date: DateTime(2026, 10, 1),
      );

      final g2 = await repo.createGoal(
        name: 'Viaje',
        icon: 'airplane-tilt',
        targetAmount: 5000000,
      );
      await repo.addContribution(
        goalId: g2,
        amount: 1000000,
        date: DateTime(2026, 10, 5),
      );

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Encabezado con total: 2.500.000 + 1.000.000 = 3.500.000 en 2 metas
      expect(find.textContaining('3.500.000'), findsWidgets);
      expect(find.textContaining('2 metas'), findsOneWidget);

      // Tarjetas de metas
      expect(find.text('Fondo de emergencia'), findsOneWidget);
      expect(find.text('Viaje'), findsOneWidget);

      // Barra de progreso y porcentajes (25% y 20%)
      expect(find.textContaining('25 %'), findsOneWidget);
      expect(find.textContaining('20 %'), findsOneWidget);

      // Botón agregar meta
      expect(find.byKey(const ValueKey('add-goal-button')), findsOneWidget);
    },
  );

  testWidgets('estado vacío cuando no hay metas', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('No tenés metas activas'), findsOneWidget);
    expect(find.text('Crear primera meta'), findsOneWidget);
  });
}
