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
import 'package:pockt/features/home/ui/home_screen.dart';
import 'package:pockt/features/income/data/income_schedule_repository.dart';
import 'package:pockt/features/safe_to_spend/domain/safe_to_spend.dart';
import 'package:pockt/core/format/money.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  for (final scenario in [
    (today: DateTime(2026, 10, 15), days: 15),
    (today: DateTime(2026, 10, 29), days: 1),
    (today: DateTime(2026, 10, 31), days: 13),
  ]) {
    testWidgets(
      'toggle recurrente en Ajustes actualiza Podés gastar hoy en el Inicio: ${scenario.today}',
      (tester) async {
        tz.initializeTimeZones();
        setLocalZone('America/Asuncion');
        final db = AppDatabase.forTesting(
          DatabaseConnection(
            NativeDatabase.memory(),
            closeStreamsSynchronously: true,
          ),
        );
        addTearDown(db.close);

        final cat = await (db.select(db.categories)..limit(1)).getSingle();
        final today = scenario.today;
        final paidAt = dayRangeUtc(today).startUtc
            .add(const Duration(hours: 12));
        final withRecurring = formatGs((1500000 / scenario.days).round());
        final withoutRecurring = formatGs((2000000 / scenario.days).round());

        // Quincenal: día 15 y fin de mes; el sábado 31/10 se adelanta al 30.
        await db
            .into(db.incomeSchedules)
            .insert(
              IncomeSchedulesCompanion.insert(
                id: 'sched-1',
                mode: 'biweekly',
                payDays: '[15, -1]',
                payDayRules: '["either", "previous"]',
                paySplitPercents: '[50, 50]',
                categoryId: cat.id,
                monthlyAmount: const Value(4000000),
                effectiveFrom: DateTime(today.year, today.month, 1),
              ),
            );

        // Ingreso de salario registrado hoy
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                id: 'tx-salary-today',
                type: TxType.income,
                amount: 2000000,
                categoryId: cat.id,
                occurredAt: paidAt,
                createdAt: paidAt,
                updatedAt: paidAt,
                source: TxSource.incomeSchedule,
              ),
            );

        // Recurrente de 500.000 que vence hoy, antes del próximo cobro.
        await db
            .into(db.recurringRules)
            .insert(
              RecurringRulesCompanion.insert(
                id: 'rule-test-1',
                name: 'Servicio Test',
                type: TxType.expense,
                amount: 500000,
                categoryId: cat.id,
                frequency: 'monthly',
                nextDueDate: today,
                active: const Value(true),
              ),
            );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              notifierProvider.overrideWithValue(FakeNotifier()),
              safeToSpendClockProvider.overrideWithValue(() => today),
              incomeScheduleRepositoryProvider.overrideWithValue(
                IncomeScheduleRepository(db, clock: () => today),
              ),
            ],
            child: MaterialApp(
              theme: buildDarkTheme(),
              home: HomeScreen(nowLocal: today),
            ),
          ),
        );

        // Esperar a que se asiente la pantalla de Inicio
        await tester.pumpAndSettle();

        // Verificamos que se muestra "Podés gastar hoy"
        expect(find.text('Podés gastar hoy'), findsOneWidget);

        // Leemos el valor inicial de "Podés gastar hoy"
        // Divide el saldo menos el recurrente por los días de este escenario.
        expect(find.text(withRecurring), findsOneWidget);

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
        final switchFinder = find.byKey(
          const ValueKey('toggle-active-rule-test-1'),
        );
        expect(switchFinder, findsOneWidget);

        // Apagar el recurrente
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        final ruleInDb = await (db.select(
          db.recurringRules,
        )..where((r) => r.id.equals('rule-test-1'))).getSingle();
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
        // Sin el recurrente, divide los 2.000.000 por el mismo período.
        expect(find.text(withoutRecurring), findsOneWidget);

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

        final ruleInDbOn = await (db.select(
          db.recurringRules,
        )..where((r) => r.id.equals('rule-test-1'))).getSingle();
        expect(ruleInDbOn.active, isTrue);

        // Volver a Inicio
        await tester.tap(find.bySemanticsLabel('Volver'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Volver'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Volver'));
        await tester.pumpAndSettle();

        // Vuelve a restar el recurrente al reactivarlo.
        expect(find.text(withRecurring), findsOneWidget);
      },
    );
  }
}
