import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/home/ui/home_screen.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/loans/ui/loans_screen.dart';
import 'package:pockt/features/settings/ui/settings_screen.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  late AppDatabase db;
  late LoansRepository loansRepo;
  late TransactionsRepository txRepo;

  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() async {
    setLocalZone('America/Asuncion');
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    loansRepo = LoansRepository(db);
    txRepo = TransactionsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        loansRepositoryProvider.overrideWithValue(loansRepo),
        transactionsRepositoryProvider.overrideWithValue(txRepo),
      ],
      child: MaterialApp(
        theme: buildDarkTheme(),
        home: child,
      ),
    );
  }

  group('Tarjeta Préstamos en HomeScreen', () {
    testWidgets('no aparece si no hay préstamos activos', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          HomeScreen(
            initialYear: 2026,
            initialMonth: 10,
            nowLocal: DateTime(2026, 10, 10, 12, 0),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('home-loans-card')), findsNothing);
    });

    testWidgets('aparece con préstamos activos y muestra resumen y hasta 3 vencimientos', (tester) async {
      // Crear 4 préstamos activos
      await loansRepo.createLoan(
        direction: LoanDirection.owe,
        kind: LoanKind.installments,
        name: 'Préstamo Auto',
        totalAmount: 12000000,
        installmentAmount: 1000000,
        installmentsTotal: 12,
        dueDay: 15,
        startDate: DateTime(2026, 10, 1),
      );

      await loansRepo.createLoan(
        direction: LoanDirection.owe,
        kind: LoanKind.installments,
        name: 'Celular Cuotas',
        totalAmount: 3600000,
        installmentAmount: 300000,
        installmentsTotal: 12,
        dueDay: 20,
        startDate: DateTime(2026, 10, 1),
      );

      await loansRepo.createLoan(
        direction: LoanDirection.lent,
        kind: LoanKind.loan,
        name: 'Préstamo a Juan',
        totalAmount: 500000,
        dueDay: 25,
        startDate: DateTime(2026, 10, 1),
      );

      await loansRepo.createLoan(
        direction: LoanDirection.owe,
        kind: LoanKind.loan,
        name: 'Deuda extra',
        totalAmount: 200000,
        dueDay: 28,
        startDate: DateTime(2026, 10, 1),
      );

      await tester.pumpWidget(
        createTestWidget(
          HomeScreen(
            initialYear: 2026,
            initialMonth: 10,
            nowLocal: DateTime(2026, 10, 10, 12, 0),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('home-loans-card')), findsOneWidget);
      expect(find.text('Préstamos y cuotas'), findsOneWidget);
      expect(find.text('Debés'), findsOneWidget);
      expect(find.text('Te deben'), findsOneWidget);

      // Muestra los 3 vencimientos más próximos
      expect(find.text('Préstamo Auto'), findsOneWidget);
      expect(find.text('Celular Cuotas'), findsOneWidget);
      expect(find.text('Préstamo a Juan'), findsOneWidget);
      // El 4to no debe aparecer en los 3 primeros
      expect(find.text('Deuda extra'), findsNothing);

      // Al tocar la tarjeta navega a LoansScreen
      await tester.tap(find.byKey(const ValueKey('home-loans-card')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LoansScreen), findsOneWidget);
    });
  });

  group('Acceso en SettingsScreen', () {
    testWidgets('muestra acceso Préstamos y cuotas bajo Tu dinero y navega', (tester) async {
      await tester.pumpWidget(createTestWidget(const SettingsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('settings-loans-tile')), findsOneWidget);
      expect(find.text('Préstamos y cuotas'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('settings-loans-tile')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LoansScreen), findsOneWidget);
    });
  });

  group('Flujo de carga con categoría Préstamos', () {
    testWidgets('al elegir Préstamos muestra hoja de selección y vincula el préstamo elegido', (tester) async {
      final loanId = await loansRepo.createLoan(
        direction: LoanDirection.owe,
        kind: LoanKind.installments,
        name: 'Préstamo Heladera',
        totalAmount: 4800000,
        installmentAmount: 400000,
        installmentsTotal: 12,
        dueDay: 10,
        startDate: DateTime(2026, 10, 1),
      );

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(const EntryCategoryPickerScreen(initialType: TxType.expense)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(GridView), const Offset(0, -300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final prestamosCatFinder = find.text('Préstamos');
      expect(prestamosCatFinder, findsOneWidget);
      await tester.tap(prestamosCatFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Debe aparecer la hoja para elegir préstamo
      expect(find.text('¿A qué préstamo corresponde?'), findsOneWidget);
      expect(find.text('Préstamo Heladera'), findsOneWidget);
      expect(find.text('Ninguno / Gasto general'), findsOneWidget);

      // Seleccionar el préstamo
      await tester.tap(find.text('Préstamo Heladera'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Entra al teclado de montos con el monto prellenado
      // Guardar el pago
      final saveBtn = find.byKey(const ValueKey('keypad-btn-action'));
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar que el movimiento se guardó con loanId
      final txs = await (db.select(db.transactions)..where((t) => t.loanId.equals(loanId))).get();
      expect(txs.length, 1);
      expect(txs.first.loanId, loanId);
    });

    testWidgets('al elegir Ninguno / Gasto general se crea el movimiento sin loanId', (tester) async {
      await loansRepo.createLoan(
        direction: LoanDirection.owe,
        kind: LoanKind.installments,
        name: 'Préstamo Auto',
        totalAmount: 10000000,
        installmentAmount: 500000,
        startDate: DateTime(2026, 10, 1),
      );

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(const EntryCategoryPickerScreen(initialType: TxType.expense)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(GridView), const Offset(0, -300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final prestamosCatFinder = find.text('Préstamos');
      await tester.tap(prestamosCatFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tocar Ninguno / Gasto general
      await tester.tap(find.text('Ninguno / Gasto general'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Escribir monto 150.000
      await tester.tap(find.widgetWithText(Pressable, '1'));
      await tester.pump();
      await tester.tap(find.widgetWithText(Pressable, '5'));
      await tester.pump();
      await tester.tap(find.widgetWithText(Pressable, '000'));
      await tester.pump();

      // Guardar
      await tester.tap(find.byKey(const ValueKey('keypad-btn-action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final txs = await (db.select(db.transactions)..where((t) => t.amount.equals(15000))).get();
      expect(txs.length, 1);
      expect(txs.first.loanId, isNull);
    });
  });
}
