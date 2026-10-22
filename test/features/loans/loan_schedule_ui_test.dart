import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/loans/domain/installment_schedule_parser.dart';
import 'package:pockt/features/loans/domain/loan_progress.dart';
import 'package:pockt/features/loans/ui/loan_detail_screen.dart';
import 'package:pockt/features/loans/ui/loan_editor.dart';

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

  testWidgets('LoanPaymentSheet precarga el monto de la próxima cuota y muestra subtítulo con número de cuota', (tester) async {
    final loan = Loan(
      id: 'loan-1',
      direction: LoanDirection.owe,
      kind: LoanKind.installments,
      name: 'Préstamo Itaú',
      totalAmount: 2415000,
      installmentAmount: null,
      installmentsTotal: 3,
      dueDay: 2,
      paidBeforeCount: 0,
      reminderDays: 2,
      startDate: DateTime(2027, 1, 1),
      createdAt: DateTime(2027, 1, 1),
      updatedAt: DateTime(2027, 1, 1),
    );

    final nextInst = LoanInstallment(
      loanId: 'loan-1',
      number: 2,
      dueDate: DateTime.utc(2027, 2, 2),
      amount: 805000,
    );

    final progress = LoanProgress(
      paid: 905000,
      balance: 1510000,
      installmentsPaid: 1,
      installmentsRemaining: 2,
      percent: 0.36,
      isClosed: false,
      nextDueDate: DateTime.utc(2027, 2, 2),
      nextInstallment: nextInst,
    );

    await tester.pumpWidget(buildTestApp(
      home: Scaffold(
        body: LoanPaymentSheet(
          loan: loan,
          progress: progress,
          isExtra: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Préstamo Itaú · cuota 2 de 3'), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.controller!.text, contains('805.000'));
  });

  testWidgets('LoanEditorScreen permite seleccionar Cronograma, valida y guarda cuotas', (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(buildTestApp(home: const LoanEditorScreen()));
    await tester.pumpAndSettle();

    // Seleccionar Cronograma
    await tester.tap(find.text('Cronograma'));
    await tester.pumpAndSettle();

    // Ingresar nombre
    await tester.enterText(find.widgetWithText(TextField, 'Nombre o concepto'), 'Préstamo Itaú');

    // Pegar cronograma con error
    final scheduleField = find.byKey(const ValueKey('schedule-input'));
    expect(scheduleField, findsOneWidget);

    await tester.enterText(scheduleField, '1 fecha-invalida 905.000');
    await tester.pumpAndSettle();

    expect(find.textContaining('Línea 1'), findsOneWidget);

    // Pegar cronograma válido
    const validSchedule = '''
1 02/01/2027 905.000
2 02/02/2027 805.000
3 02/03/2027 705.000
''';
    await tester.enterText(scheduleField, validSchedule);
    await tester.pumpAndSettle();

    expect(find.text('3 cuotas'), findsOneWidget);
    expect(find.text('Gs. 2.415.000'), findsOneWidget);

    // Guardar
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final allLoans = await (db.select(db.loans)..where((l) => l.closedAt.isNull())).get();
    expect(allLoans.length, 1);
    expect(allLoans.first.name, 'Préstamo Itaú');
    expect(allLoans.first.totalAmount, 2415000);

    final installments = await repo.getInstallments(allLoans.first.id);
    expect(installments.length, 3);
    expect(installments[0].amount, 905000);
    expect(installments[1].amount, 805000);
    expect(installments[2].amount, 705000);
  });

  testWidgets('LoanDetailScreen muestra tarjetas Próxima cuota y Cronograma', (tester) async {
    final schedule = [
      ParsedInstallment(number: 1, dueDate: DateTime(2027, 1, 2), amount: 905000),
      ParsedInstallment(number: 2, dueDate: DateTime(2027, 2, 2), amount: 805000),
      ParsedInstallment(number: 3, dueDate: DateTime(2027, 3, 2), amount: 705000),
    ];

    final loanId = await repo.createLoan(
      direction: LoanDirection.owe,
      kind: LoanKind.installments,
      name: 'Préstamo Itaú',
      totalAmount: 0,
      startDate: DateTime(2027, 1, 1),
      schedule: schedule,
    );

    await tester.pumpWidget(buildTestApp(home: LoanDetailScreen(loanId: loanId)));
    await tester.pumpAndSettle();

    expect(find.text('Próxima cuota · 1 de 3'), findsOneWidget);
    expect(find.text('Gs. 905.000'), findsWidgets);
    expect(find.text('Cronograma'), findsOneWidget);
    expect(find.text('Cuota 1 · 02/01/2027'), findsOneWidget);
    expect(find.text('Cuota 2 · 02/02/2027'), findsOneWidget);
    expect(find.text('Cuota 3 · 02/03/2027'), findsOneWidget);
  });

  testWidgets('LoanDetailScreen muestra fila informativa de cuotas ya pagadas antes de Pockt', (tester) async {
    final loanId = await repo.createLoan(
      direction: LoanDirection.owe,
      kind: LoanKind.installments,
      name: 'Préstamo moto',
      totalAmount: 6390000,
      installmentAmount: 355000,
      installmentsTotal: 18,
      dueDay: 25,
      paidBeforeCount: 1,
      startDate: DateTime(2027, 1, 1),
    );

    await tester.pumpWidget(buildTestApp(home: LoanDetailScreen(loanId: loanId)));
    await tester.pumpAndSettle();

    expect(find.text('Cuota 1 · antes de Pockt'), findsOneWidget);
    expect(find.text('Gs. 355.000'), findsWidgets);
    expect(find.text('Aún no registraste pagos para este préstamo.'), findsNothing);
  });

  testWidgets('LoanEditorScreen muestra Debo / Presté con título y subtítulo centrados', (tester) async {
    await tester.pumpWidget(buildTestApp(home: const LoanEditorScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Debo'), findsOneWidget);
    expect(find.text('me prestaron / cuotas'), findsOneWidget);
    expect(find.text('Presté'), findsOneWidget);
    expect(find.text('me deben'), findsOneWidget);
  });

  testWidgets('LoanEditorScreen en cronograma no duplica el título y usa singular 1 cuota', (tester) async {
    await tester.pumpWidget(buildTestApp(home: const LoanEditorScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cronograma'));
    await tester.pumpAndSettle();

    // El título "Cronograma" dentro de la tarjeta aparece una sola vez (no duplicado en el input)
    expect(
      find.descendant(
        of: find.byType(GlassCard),
        matching: find.text('Cronograma'),
      ),
      findsOneWidget,
    );
    expect(find.text('Pegá el cronograma (una cuota por línea)'), findsNothing);

    final scheduleField = find.byKey(const ValueKey('schedule-input'));
    await tester.enterText(scheduleField, '1 02/01/2027 905.000\n');
    await tester.pumpAndSettle();

    expect(find.text('1 cuota'), findsOneWidget);
  });

  testWidgets('LoanEditorScreen selector -/+ de cuotas ya pagadas antes de Pockt', (tester) async {
    await tester.pumpWidget(buildTestApp(home: const LoanEditorScreen()));
    await tester.pumpAndSettle();

    // Scroll hasta el selector si está offscreen
    await tester.ensureVisible(find.byKey(const ValueKey('paid-before-count')));
    expect(find.text('Cuotas que ya pagaste antes de usar Pockt'), findsOneWidget);
    expect(find.byKey(const ValueKey('paid-before-count')), findsOneWidget);
    expect(find.text('0'), findsWidgets);

    // Ingresar monto de cuota y cant cuotas
    await tester.ensureVisible(find.widgetWithText(TextField, 'Monto de cuota'));
    await tester.enterText(find.widgetWithText(TextField, 'Monto de cuota'), '355.000');
    await tester.enterText(find.widgetWithText(TextField, 'Cant. cuotas'), '18');
    await tester.pumpAndSettle();

    // Incrementar a 1
    await tester.ensureVisible(find.byKey(const ValueKey('paid-before-inc')));
    await tester.tap(find.byKey(const ValueKey('paid-before-inc')));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsWidgets);
    expect(find.textContaining('Cuentan como pagadas (Gs. 355.000) pero no como gasto.'), findsOneWidget);

    // Decrementar a 0
    await tester.ensureVisible(find.byKey(const ValueKey('paid-before-dec')));
    await tester.tap(find.byKey(const ValueKey('paid-before-dec')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cuentan como pagadas (Gs. 0) pero no como gasto.'), findsOneWidget);
  });

  testWidgets('LoanEditorScreen pide confirmación al descartar con cambios', (tester) async {
    await tester.pumpWidget(buildTestApp(home: const LoanEditorScreen()));
    await tester.pumpAndSettle();

    // Ingresar un nombre
    await tester.enterText(find.widgetWithText(TextField, 'Nombre o concepto'), 'Mi préstamo');
    await tester.pumpAndSettle();

    // Tocar botón atrás
    await tester.tap(find.byKey(const ValueKey('loan-editor-back')));
    await tester.pumpAndSettle();

    expect(find.text('¿Descartar el préstamo?'), findsOneWidget);
    expect(find.text('Si salís ahora se pierde lo que cargaste.'), findsOneWidget);

    // Cancelar
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();

    expect(find.text('¿Descartar el préstamo?'), findsNothing);
    expect(find.text('Nuevo préstamo'), findsOneWidget);

    // Descartar
    await tester.tap(find.byKey(const ValueKey('loan-editor-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    // Se cerró la pantalla (no encuentra el AppBar 'Nuevo préstamo')
    expect(find.text('Nuevo préstamo'), findsNothing);
  });
}
