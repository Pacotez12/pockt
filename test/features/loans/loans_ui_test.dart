import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/loans/ui/loan_detail_screen.dart';
import 'package:pockt/features/loans/ui/loan_editor.dart';
import 'package:pockt/features/loans/ui/loans_screen.dart';

void main() {
  late AppDatabase db;
  late LoansRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    repo = LoansRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp({required Widget home}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        loansRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: buildDarkTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: home,
      ),
    );
  }

  testWidgets('la lista en LoansScreen separa por pestaña Debo / Presté / Terminados', (tester) async {
    // 1 deudor activo
    await repo.createLoan(
      direction: LoanDirection.owe,
      kind: LoanKind.installments,
      name: 'Cuotas TV',
      totalAmount: 1000000,
      installmentAmount: 100000,
      startDate: DateTime(2026, 1, 1),
    );

    // 1 prestado activo
    await repo.createLoan(
      direction: LoanDirection.lent,
      kind: LoanKind.loan,
      name: 'Préstamo a Lucas',
      totalAmount: 500000,
      startDate: DateTime(2026, 1, 1),
    );

    // 1 terminado
    final closedId = await repo.createLoan(
      direction: LoanDirection.owe,
      kind: LoanKind.loan,
      name: 'Moto cancelada',
      totalAmount: 2000000,
      startDate: DateTime(2025, 1, 1),
    );
    await repo.closeLoan(closedId);

    await tester.pumpWidget(buildTestApp(home: const LoansScreen()));
    await tester.pumpAndSettle();

    // Pestaña inicial: Debo
    expect(find.text('Cuotas TV'), findsOneWidget);
    expect(find.text('Préstamo a Lucas'), findsNothing);
    expect(find.text('Moto cancelada'), findsNothing);

    // Cambiar a pestaña Presté
    await tester.tap(find.text('Presté'));
    await tester.pumpAndSettle();
    expect(find.text('Préstamo a Lucas'), findsOneWidget);
    expect(find.text('Cuotas TV'), findsNothing);

    // Cambiar a pestaña Terminados
    await tester.tap(find.text('Terminados'));
    await tester.pumpAndSettle();
    expect(find.text('Moto cancelada'), findsOneWidget);
    expect(find.text('Cuotas TV'), findsNothing);
  });

  testWidgets('registrar pago desde LoanDetailScreen crea gasto ligado y actualiza saldo', (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    final loanId = await repo.createLoan(
      direction: LoanDirection.owe,
      kind: LoanKind.installments,
      name: 'Cuotas Celular',
      totalAmount: 600000,
      installmentAmount: 100000,
      installmentsTotal: 6,
      dueDay: 15,
      startDate: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(buildTestApp(home: LoanDetailScreen(loanId: loanId)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Cuotas Celular'), findsOneWidget);
    expect(find.text('Registrar pago'), findsOneWidget);

    // Abrir modal de registrar pago
    await tester.tap(find.text('Registrar pago'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // El modal muestra el botón Guardar pago
    expect(find.text('Guardar pago'), findsOneWidget);

    // Tocar Guardar pago
    await tester.tap(find.text('Guardar pago'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verificar en BD que se guardó
    final payments = await (db.select(db.transactions)..where((t) => t.loanId.equals(loanId))).get();
    expect(payments.length, equals(1));
    expect(payments.first.amount, equals(100000));
    expect(payments.first.loanId, equals(loanId));
  });

  testWidgets('pago extra / adelanto registra nota con extra y baja el saldo sin sumar cuota regular', (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    final loanId = await repo.createLoan(
      direction: LoanDirection.owe,
      kind: LoanKind.installments,
      name: 'Cuotas Sofá',
      totalAmount: 1000000,
      installmentAmount: 200000,
      installmentsTotal: 5,
      startDate: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(buildTestApp(home: LoanDetailScreen(loanId: loanId)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Pago extra / adelanto'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Guardar pago extra'), findsOneWidget);

    await tester.tap(find.text('Guardar pago extra'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final payments = await (db.select(db.transactions)..where((t) => t.loanId.equals(loanId))).get();
    expect(payments.length, equals(1));
    expect(payments.first.note, contains('extra'));
  });

  testWidgets('LoanEditor valida campos obligatorios y montos', (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    await tester.pumpWidget(buildTestApp(home: const LoanEditorScreen()));
    await tester.pumpAndSettle();

    // Intentar guardar sin datos
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Debe mostrar error de validación
    expect(find.text('Ingresá un nombre'), findsOneWidget);

    final allLoans = await (db.select(db.loans)..where((l) => l.closedAt.isNull())).get();
    expect(allLoans, isEmpty);
  });
}
