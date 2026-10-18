import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/home/ui/category_arc.dart';
import 'package:pockt/features/safe_to_spend/domain/safe_to_spend.dart';
import 'package:pockt/features/transactions/data/categories_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  late AppDatabase db;
  late CategoriesRepository catRepo;
  late TransactionsRepository txRepo;

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
    catRepo = CategoriesRepository(db);
    txRepo = TransactionsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  final testSafe = SafeToSpend(
    amount: 125800,
    todayAllowance: 125800,
    spentToday: 48500,
    quedan: 2251500,
    pendingRecurring: 0,
    proratedGoals: 0,
    daysUntilPay: 13,
    targetDate: DateTime(2026, 10, 31),
    hasIncomeSchedule: true,
  );

  Widget createTestHost({
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        safeToSpendProvider.overrideWith((ref) => Stream.value(testSafe)),
      ],
      child: MaterialApp(
        theme: buildDarkTheme(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  group('CategoryArc desplegable (C3 sin línea de categorías en reposo)', () {
    testWidgets('en reposo NO muestra los chips de categorías y muestra flechita ▾', (tester) async {
      final now = DateTime(2026, 10, 15, 12, 0);
      final cats = (await tester.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
      final comida = cats.firstWhere((c) => c.name == 'Comida');
      final transporte = cats.firstWhere((c) => c.name == 'Transporte');

      await tester.runAsync(() async {
        await txRepo.add(
          type: TxType.expense,
          amount: 300000,
          categoryId: comida.id,
          occurredAt: DateTime(2026, 10, 5, 12, 0),
        );
        await txRepo.add(
          type: TxType.expense,
          amount: 100000,
          categoryId: transporte.id,
          occurredAt: DateTime(2026, 10, 6, 12, 0),
        );
      });

      await tester.pumpWidget(
        createTestHost(
          child: CategoryArc(
            year: 2026,
            month: 10,
            nowLocal: now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Total presente
      expect(find.text('Gs. 400.000'), findsOneWidget);
      expect(find.textContaining('Gastado en octubre'), findsOneWidget);
      // Flechita ▾ indicadora presente
      expect(find.textContaining('▾'), findsOneWidget);

      // Chips de categorías ocultos en reposo
      expect(find.text('Comida'), findsNothing);
      expect(find.text('Transporte'), findsNothing);
    });

    testWidgets('al tocar el arco se despliegan los chips; al tocar el centro vuelve al total y los esconde', (tester) async {
      final now = DateTime(2026, 10, 15, 12, 0);
      final cats = (await tester.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
      final comida = cats.firstWhere((c) => c.name == 'Comida');
      final transporte = cats.firstWhere((c) => c.name == 'Transporte');

      await tester.runAsync(() async {
        await txRepo.add(
          type: TxType.expense,
          amount: 300000,
          categoryId: comida.id,
          occurredAt: DateTime(2026, 10, 5, 12, 0),
        );
        await txRepo.add(
          type: TxType.expense,
          amount: 100000,
          categoryId: transporte.id,
          occurredAt: DateTime(2026, 10, 6, 12, 0),
        );
      });

      await tester.pumpWidget(
        createTestHost(
          child: CategoryArc(
            year: 2026,
            month: 10,
            nowLocal: now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tocar sobre el centro / flechita para expandir
      await tester.tap(find.textContaining('Gastado en octubre'));
      await tester.pumpAndSettle();

      // Ahora los chips están desplegados
      expect(find.text('Comida'), findsOneWidget);
      expect(find.text('75 %'), findsOneWidget);
      expect(find.text('Transporte'), findsOneWidget);
      expect(find.text('25 %'), findsOneWidget);

      // Tocar un chip selecciona la categoría
      await tester.tap(find.text('Comida'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Comida en octubre'), findsOneWidget);
      expect(find.text('Gs. 300.000'), findsOneWidget);
      expect(find.text('75 % de lo gastado'), findsOneWidget);

      // Tocar el centro vuelve al total y esconde los chips
      await tester.tap(find.text('Gs. 300.000'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Gastado en octubre'), findsOneWidget);
      expect(find.text('Gs. 400.000'), findsOneWidget);
      expect(find.text('Comida'), findsNothing);
      expect(find.text('Transporte'), findsNothing);
    });

    testWidgets('tocar directamente un tramo del arco en reposo despliega y selecciona esa categoría', (tester) async {
      final now = DateTime(2026, 10, 15, 12, 0);
      final cats = (await tester.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
      final comida = cats.firstWhere((c) => c.name == 'Comida');
      final transporte = cats.firstWhere((c) => c.name == 'Transporte');

      await tester.runAsync(() async {
        await txRepo.add(
          type: TxType.expense,
          amount: 300000,
          categoryId: comida.id,
          occurredAt: DateTime(2026, 10, 5, 12, 0),
        );
        await txRepo.add(
          type: TxType.expense,
          amount: 100000,
          categoryId: transporte.id,
          occurredAt: DateTime(2026, 10, 6, 12, 0),
        );
      });

      await tester.pumpWidget(
        createTestHost(
          child: CategoryArc(
            year: 2026,
            month: 10,
            nowLocal: now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tocar tramo de Comida en el arco
      final arcPaint = find.byType(CustomPaint).first;
      final arcRect = tester.getRect(arcPaint);
      await tester.tapAt(Offset(arcRect.center.dx, arcRect.top + 10));
      await tester.pumpAndSettle();

      // Despliega y selecciona Comida
      expect(find.textContaining('Comida en octubre'), findsOneWidget);
      expect(find.text('Gs. 300.000'), findsOneWidget);
      expect(find.text('Comida'), findsOneWidget);
      expect(find.text('Transporte'), findsOneWidget);
    });
  });
}
