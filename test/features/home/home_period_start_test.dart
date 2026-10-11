import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/budgets/ui/budgets_screen.dart';
import 'package:pockt/features/home/ui/home_screen.dart';
import 'package:pockt/features/income/data/income_schedule_repository.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  late AppDatabase testDb;
  late SettingsRepository settingsRepo;
  late TransactionsRepository txRepo;
  late IncomeScheduleRepository scheduleRepo;
  late String categoryId;

  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() async {
    setLocalZone('America/Asuncion');
    testDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    settingsRepo = SettingsRepository(testDb);
    txRepo = TransactionsRepository(testDb);
    scheduleRepo = IncomeScheduleRepository(testDb);

    // Crear categoría de comida
    categoryId = 'cat-comida';
    await testDb.into(testDb.categories).insert(
          CategoriesCompanion.insert(
            id: categoryId,
            name: 'Comida',
            icon: 'fork-knife',
            colorLight: 0xFF22C55E,
            colorDark: 0xFF22C55E,
            kind: CategoryKind.expense,
            sortOrder: 0,
          ),
        );

    // Crear esquema de cobro mensual a fin de mes (-1, con PayDayRule.previous)
    // En sept 2026: 30/09 (miércoles)
    // En oct 2026: 30/10 (viernes, porque 31/10 es sábado)
    await scheduleRepo.setSchedule(
      mode: PayMode.monthly,
      payDays: [-1],
      payDayRules: [PayDayRule.previous],
      monthlyAmount: 5000000,
      paySplitPercents: [100],
      categoryId: categoryId,
    );
  });

  tearDown(() async {
    await testDb.close();
  });

  testWidgets('totales del Inicio respetan ajuste period.monthStart', (tester) async {
    // Gasto 1: el 30/09/2026 a las 12:00 (Gs. 100.000)
    await txRepo.add(
      type: TxType.expense,
      amount: 100000,
      categoryId: categoryId,
      occurredAt: toLocal(DateTime(2026, 9, 30, 12, 0)),
    );

    // Gasto 2: el 30/10/2026 a las 12:00 (Gs. 50.000)
    await txRepo.add(
      type: TxType.expense,
      amount: 50000,
      categoryId: categoryId,
      occurredAt: toLocal(DateTime(2026, 10, 30, 12, 0)),
    );

    // Caso A: con 'calendar' (por defecto), el 05/10 sólo ve octubre (no incluye 30/09, sí incluye 30/10)
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: HomeScreen(
            initialYear: 2026,
            initialMonth: 10,
            nowLocal: DateTime(2026, 10, 5, 10, 0),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));

    // En calendar: el total de octubre incluye el gasto del 30/10 (50.000) y no el del 30/09
    expect(find.text('Gs. 50.000'), findsOneWidget);
    expect(find.text('Gs. 100.000'), findsNothing);

    // Caso B: cambiamos el ajuste a 'payday'
    await settingsRepo.set(SettingsKeys.periodMonthStart, 'payday');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));

    // En payday: el período de 05/10 es 30/09–29/10:
    // incluye el gasto del 30/09 (100.000) y excluye el del 30/10 (que empieza el ciclo siguiente)
    expect(find.text('Gs. 100.000'), findsOneWidget);
    expect(find.text('Gs. 50.000'), findsNothing);
  });

  testWidgets('presupuestos respetan ajuste period.monthStart', (tester) async {
    // Presupuesto de 150.000 para Comida
    await testDb.into(testDb.budgets).insert(
          BudgetsCompanion.insert(
            id: 'b-1',
            categoryId: categoryId,
            monthlyLimit: 150000,
          ),
        );

    // Gasto el 30/09/2026 por 100.000
    await txRepo.add(
      type: TxType.expense,
      amount: 100000,
      categoryId: categoryId,
      occurredAt: toLocal(DateTime(2026, 9, 30, 12, 0)),
    );

    // Con calendar: el gasto de 30/09 no cuenta en octubre (gastado: Gs. 0, quedan: Gs. 150.000)
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: BudgetsScreen(
            initialYear: 2026,
            initialMonth: 10,
            nowLocal: DateTime(2026, 10, 5, 10, 0),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('0 %'), findsOneWidget);
    expect(find.text('Gs. 0'), findsOneWidget);

    // Cambiamos a 'payday': ahora el gasto de 30/09 entra en el período
    await settingsRepo.set(SettingsKeys.periodMonthStart, 'payday');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('67 %'), findsOneWidget);
    expect(find.text('Gs. 100.000'), findsOneWidget);
  });
}
