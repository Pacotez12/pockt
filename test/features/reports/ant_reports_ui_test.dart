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
import 'package:pockt/features/reports/data/reports_repository.dart';
import 'package:pockt/features/reports/ui/reports_screen.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionsRepository txRepo;
  late ReportsRepository reportsRepo;
  late SettingsRepository settingsRepo;
  late String comidaId;
  late String transporteId;

  setUp(() async {
    setLocalZone('America/Asuncion');
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    txRepo = TransactionsRepository(db);
    reportsRepo = ReportsRepository(db);
    settingsRepo = SettingsRepository(db);

    final cats = await db.select(db.categories).get();
    comidaId = cats.firstWhere((c) => c.name == 'Comida').id;
    transporteId = cats.firstWhere((c) => c.name == 'Transporte').id;
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpReports(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          reportsRepositoryProvider.overrideWithValue(reportsRepo),
          transactionsRepositoryProvider.overrideWithValue(txRepo),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: const ReportsScreen(
            nowLocal: null,
            initialYear: 2026,
            initialMonth: 10,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'vista Hormiga muestra estado vacío cuando no hay gastos pequeños',
    (tester) async {
      // Solo un gasto grande > 30.000
      await txRepo.add(
        type: TxType.expense,
        amount: 80000,
        categoryId: comidaId,
        merchant: 'Supermercado',
        occurredAt: DateTime(2026, 10, 5, 12, 0),
      );

      await pumpReports(tester);

      // Tocar la pestaña Hormiga
      await tester.tap(find.text('Hormiga'));
      await tester.pumpAndSettle();

      expect(find.text('Sin gastos hormiga este mes'), findsOneWidget);
    },
  );

  testWidgets(
    'vista Hormiga muestra total, cantidad, proyección anual y agrupación',
    (tester) async {
      // 2 compras en Biggie (10.000 y 15.000)
      await txRepo.add(
        type: TxType.expense,
        amount: 10000,
        categoryId: comidaId,
        merchant: 'Biggie',
        occurredAt: DateTime(2026, 10, 5, 12, 0),
      );
      await txRepo.add(
        type: TxType.expense,
        amount: 15000,
        categoryId: comidaId,
        merchant: 'Biggie',
        occurredAt: DateTime(2026, 10, 7, 12, 0),
      );
      // 1 compra sin comercio en Transporte (12.000)
      await txRepo.add(
        type: TxType.expense,
        amount: 12000,
        categoryId: transporteId,
        merchant: null,
        occurredAt: DateTime(2026, 10, 8, 12, 0),
      );
      // 1 compra grande > 30.000 (no debe contar)
      await txRepo.add(
        type: TxType.expense,
        amount: 50000,
        categoryId: comidaId,
        merchant: 'Restaurante',
        occurredAt: DateTime(2026, 10, 9, 12, 0),
      );

      await pumpReports(tester);

      // Ir a la pestaña Hormiga
      await tester.tap(find.text('Hormiga'));
      await tester.pumpAndSettle();

      // Total = 10.000 + 15.000 + 12.000 = 37.000
      // Proyección anual = 37.000 * 12 = 444.000
      // Cantidad = 3
      expect(find.text('Gs. 37.000'), findsAtLeastNWidgets(1));
      expect(find.text('Gs. 444.000'), findsOneWidget);
      expect(find.text('3 compras'), findsAtLeastNWidgets(1));

      // Agrupación por comercio y categoría
      expect(find.text('Biggie'), findsOneWidget);
      expect(find.text('Gs. 25.000'), findsOneWidget);
      expect(find.text('Transporte'), findsAtLeastNWidgets(1));
      expect(find.text('Gs. 12.000'), findsOneWidget);
    },
  );
}
