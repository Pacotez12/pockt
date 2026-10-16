import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/goals/ui/goal_editor.dart';

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

  Widget buildEditor({String? goalId}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        goalsRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: buildDarkTheme(),
        home: GoalEditorScreen(goalId: goalId),
      ),
    );
  }

  testWidgets('crear nueva meta guarda en la base de datos', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.text('Nueva meta'), findsOneWidget);

    // Ingresar nombre
    final nameField = find.byKey(const ValueKey('goal-name-input'));
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'Viaje a Japón');

    // Ingresar monto
    final amountField = find.byKey(const ValueKey('goal-amount-input'));
    expect(amountField, findsOneWidget);
    await tester.enterText(amountField, '15000000');

    // Seleccionar ícono 'airplane-tilt'
    final iconButton = find.byKey(const ValueKey('goal-icon-airplane-tilt'));
    expect(iconButton, findsOneWidget);
    await tester.tap(iconButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Guardar
    final saveButton = find.byKey(const ValueKey('goal-save-button'));
    expect(saveButton, findsOneWidget);
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final goals = await (db.select(
      db.goals,
    )..where((g) => g.archived.equals(false))).get();
    expect(goals.length, equals(1));
    expect(goals.first.name, equals('Viaje a Japón'));
    expect(goals.first.targetAmount, equals(15000000));
    expect(goals.first.icon, equals('airplane-tilt'));
  });

  testWidgets('editar meta existente pre-carga valores y actualiza', (
    tester,
  ) async {
    final goalId = await repo.createGoal(
      name: 'Notebook',
      icon: 'laptop',
      targetAmount: 5000000,
    );

    await tester.pumpWidget(buildEditor(goalId: goalId));
    await tester.pumpAndSettle();

    expect(find.text('Editar meta'), findsOneWidget);
    expect(find.text('Notebook'), findsOneWidget);

    // Cambiar nombre
    final nameField = find.byKey(const ValueKey('goal-name-input'));
    await tester.enterText(nameField, 'MacBook Pro');

    // Guardar
    final saveButton = find.byKey(const ValueKey('goal-save-button'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final goal = await repo.getGoal(goalId);
    expect(goal!.name, equals('MacBook Pro'));
  });

  testWidgets(
    'con campos vacíos o monto 0 el botón Guardar está deshabilitado',
    (tester) async {
      await tester.pumpWidget(buildEditor());
      await tester.pumpAndSettle();

      final saveButtonFinder = find.byKey(const ValueKey('goal-save-button'));
      expect(saveButtonFinder, findsOneWidget);

      var savePressable = tester.widget<Pressable>(saveButtonFinder);
      expect(savePressable.onTap, isNull);

      // Ingresar solo nombre sin monto
      final nameField = find.byKey(const ValueKey('goal-name-input'));
      await tester.enterText(nameField, 'Ahorro');
      await tester.pump();

      savePressable = tester.widget<Pressable>(saveButtonFinder);
      expect(savePressable.onTap, isNull);

      // Ingresar monto válido
      final amountField = find.byKey(const ValueKey('goal-amount-input'));
      await tester.enterText(amountField, '500000');
      await tester.pump();

      savePressable = tester.widget<Pressable>(saveButtonFinder);
      expect(savePressable.onTap, isNotNull);
    },
  );
}
