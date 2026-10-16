import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/safe_to_spend/domain/safe_to_spend.dart';
import 'package:pockt/features/safe_to_spend/ui/buy_simulator_sheet.dart';
import 'package:pockt/features/shell/ui/app_shell.dart';
import 'package:pockt/features/widget/home_widget_bridge.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  late AppDatabase db;
  late Category testCategory;

  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() async {
    setLocalZone('America/Asuncion');
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

    // Sembrar una categoría de gasto de prueba
    testCategory = Category(
      id: 'cat-supermercado',
      name: 'Supermercado',
      icon: 'fork-knife',
      colorDark: 0xFF2ECC71,
      colorLight: 0xFF2ECC71,
      kind: CategoryKind.expense,
      archived: false,
      sortOrder: 1,
    );
    await db.into(db.categories).insert(testCategory);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildSheetApp({SafeToSpend? safeToSpendOverride}) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: buildDarkTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => showBuySimulatorSheet(
                  ctx,
                  initialCategory: testCategory,
                  initialSafeToSpend: safeToSpendOverride,
                ),
                child: const Text('Abrir simulador'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'abre la hoja ¿Lo compro?, ingresa monto con teclado y muestra antes -> después',
    (tester) async {
      final mockSafe = SafeToSpend(
        amount: 150000,
        quedan: 1500000,
        pendingRecurring: 0,
        proratedGoals: 0,
        daysUntilPay: 10,
        targetDate: DateTime(2026, 10, 31),
        hasIncomeSchedule: false,
      );

      await tester.pumpWidget(buildSheetApp(safeToSpendOverride: mockSafe));
      await tester.pumpAndSettle();

      // Abrir la hoja
      await tester.tap(find.text('Abrir simulador'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('¿Lo compro?'), findsOneWidget);
      expect(find.text('Supermercado'), findsOneWidget);

      // Teclado numérico: ingresar 200.000
      // Tocar '2', luego '000', luego '00' (o dos veces '0')
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('000'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Monto ingresado 2.000
      expect(find.textContaining('2.000'), findsWidgets);

      // Muestra sección antes -> después
      expect(find.text('Podés gastar hoy'), findsWidgets);
      expect(
        find.byKey(const ValueKey('buy-simulator-message')),
        findsOneWidget,
      );

      // Botones de acción
      expect(
        find.byKey(const ValueKey('buy-simulator-cancel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('buy-simulator-confirm')),
        findsOneWidget,
      );

      // Cancelar cierra la hoja
      await tester.tap(find.byKey(const ValueKey('buy-simulator-cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('¿Lo compro?'), findsNothing);
    },
  );

  testWidgets(
    'mantener apretado el + en AppShell abre el simulador ¿Lo compro?',
    (tester) async {
      final fakePlatform = FakeHomeWidgetPlatform();
      addTearDown(fakePlatform.dispose);

      final mockSafe = SafeToSpend(
        amount: 150000,
        quedan: 1500000,
        pendingRecurring: 0,
        proratedGoals: 0,
        daysUntilPay: 10,
        targetDate: DateTime(2026, 10, 31),
        hasIncomeSchedule: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            homeWidgetPlatformProvider.overrideWithValue(fakePlatform),
            safeToSpendProvider.overrideWith((ref) => Stream.value(mockSafe)),
          ],
          child: MaterialApp(theme: buildDarkTheme(), home: const AppShell()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final plusButton = find.byKey(const ValueKey('shell-plus-button'));
      expect(plusButton, findsOneWidget);

      // Mantener presionado (long press)
      await tester.longPress(plusButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('¿Lo compro?'), findsOneWidget);
    },
  );

  testWidgets('¿Lo compro?: cuando el monto es 0 muestra Escribí un monto', (
    tester,
  ) async {
    await tester.pumpWidget(buildSheetApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir simulador'));
    await tester.pumpAndSettle();

    expect(find.text('Escribí un monto'), findsOneWidget);
  });
}
