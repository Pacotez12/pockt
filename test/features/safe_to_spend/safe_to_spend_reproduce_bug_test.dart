import 'package:drift/drift.dart' show DatabaseConnection, Value;
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
import 'package:pockt/features/shell/ui/app_shell.dart';

void main() {
  testWidgets('toggle recurrente en Ajustes actualiza Podés gastar hoy en el Inicio', (tester) async {
    setLocalZone('America/Asuncion');
    final db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(db.close);

    final cat = await (db.select(db.categories)..limit(1)).getSingle();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Esquema quincenal: cobro día 1 y 15 (o hoy y en 10 días)
    await db.into(db.incomeSchedules).insert(
          IncomeSchedulesCompanion.insert(
            id: 'sched-1',
            mode: 'biweekly',
            payDays: '[${today.day}, ${today.day + 10}]',
            payDayRules: '["either", "previous"]',
            paySplitPercents: '[50, 50]',
            categoryId: cat.id,
            monthlyAmount: const Value(4000000),
            effectiveFrom: DateTime(today.year, today.month, 1),
          ),
        );

    // Ingreso de salario registrado hoy
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'tx-salary-today',
            type: TxType.income,
            amount: 2000000,
            categoryId: cat.id,
            occurredAt: today,
            createdAt: today,
            updatedAt: today,
            source: TxSource.incomeSchedule,
          ),
        );

    // Recurrente de 500.000 que vence en 3 días (antes del próximo cobro)
    await db.into(db.recurringRules).insert(
          RecurringRulesCompanion.insert(
            id: 'rule-test-1',
            name: 'Servicio Test',
            type: TxType.expense,
            amount: 500000,
            categoryId: cat.id,
            frequency: 'monthly',
            nextDueDate: today.add(const Duration(days: 3)),
            active: const Value(true),
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notifierProvider.overrideWithValue(FakeNotifier()),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: const AppShell(),
        ),
      ),
    );

    // Esperar a que se asiente la pantalla de Inicio
    await tester.pumpAndSettle();

    // Verificamos que se muestra "Podés gastar hoy"
    expect(find.text('Podés gastar hoy'), findsOneWidget);

    // Leemos el valor inicial de "Podés gastar hoy"
    // Con 2.000.000 - 500.000 (recurrente) = 1.500.000 / 8 días = 187.500
    expect(find.text('Gs. 187.500'), findsOneWidget);

    // Navegar a Ajustes
    await tester.tap(find.byKey(const ValueKey('home-settings-button')));
    await tester.pumpAndSettle();

    // Navegar a Tu dinero
    await tester.tap(find.byKey(const ValueKey('settings-section-money')));
    await tester.pumpAndSettle();

    // Navegar a Recurrentes
    await tester.tap(find.byKey(const ValueKey('settings-recurring-tile')));
    await tester.pumpAndSettle();

    // Encontrar el switch del recurrente
    final switchFinder = find.byKey(const ValueKey('toggle-active-rule-test-1'));
    expect(switchFinder, findsOneWidget);

    // Apagar el recurrente
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    final ruleInDb = await (db.select(db.recurringRules)..where((r) => r.id.equals('rule-test-1'))).getSingle();
    expect(ruleInDb.active, isFalse);

    // Volver de Recurrentes a Tu dinero
    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();

    // Volver de Tu dinero a Ajustes
    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();

    // Volver de Ajustes a Inicio
    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();

    // En el Inicio, sin el recurrente de 500.000:
    // Con 2.000.000 / 8 días = 250.000
    expect(find.text('Gs. 250.000'), findsOneWidget);

    // Ahora probar en el otro sentido: volver a prenderlo
    await tester.tap(find.byKey(const ValueKey('home-settings-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-section-money')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-recurring-tile')));
    await tester.pumpAndSettle();

    // Prender el recurrente
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    final ruleInDbOn = await (db.select(db.recurringRules)..where((r) => r.id.equals('rule-test-1'))).getSingle();
    expect(ruleInDbOn.active, isTrue);

    // Volver a Inicio
    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();

    // Vuelve a restar el recurrente: 187.500
    expect(find.text('Gs. 187.500'), findsOneWidget);
  });
}
