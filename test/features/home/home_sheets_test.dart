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
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/goals/domain/goal_progress.dart';
import 'package:pockt/features/goals/ui/goals_screen.dart';
import 'package:pockt/features/home/ui/home_goals_sheet.dart';
import 'package:pockt/features/home/ui/home_loans_sheet.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/loans/domain/loan_progress.dart';
import 'package:pockt/features/loans/ui/loans_screen.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  late AppDatabase db;

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
  });

  tearDown(() async {
    await db.close();
  });

  group('HomeLoansSheet y HomeGoalsSheet', () {
    testWidgets('HomeLoansSheet muestra total que debés, cuotas y permite navegar a Ver todo y detalle', (tester) async {
      final loan1 = Loan(
        id: 'l-1',
        direction: LoanDirection.owe,
        kind: LoanKind.installments,
        name: 'Celular en cuotas',
        totalAmount: 3600000,
        installmentAmount: 300000,
        installmentsTotal: 12,
        dueDay: 10,
        startDate: DateTime(2026, 1, 1),
        reminderDays: 2,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final progress1 = LoanProgress(
        paid: 1500000,
        balance: 2100000,
        percent: 0.42,
        installmentsPaid: 5,
        isClosed: false,
        daysUntilNextDue: 5,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            activeLoansWithProgressProvider.overrideWith(
              (ref) => Stream.value([
                LoanWithProgress(loan: loan1, progress: progress1),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: Scaffold(
              body: HomeLoansSheet(routeAnimation: null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Título y "Ver todo ›"
      expect(find.text('Préstamos'), findsOneWidget);
      expect(find.text('Ver todo ›'), findsOneWidget);

      // Resumen
      expect(find.text('DEBÉS'), findsOneWidget);
      expect(find.text('Gs. 2.100.000'), findsOneWidget);
      expect(find.text('1 activo'), findsOneWidget);

      // Item
      expect(find.text('Celular en cuotas'), findsOneWidget);
      expect(find.text('Cuota Gs. 300.000'), findsOneWidget);
      expect(find.text('5 de 12'), findsOneWidget);

      // Botón principal
      expect(find.text('Registrar pago'), findsOneWidget);

      // Tocar "Ver todo ›" abre LoansScreen
      await tester.tap(find.text('Ver todo ›'));
      await tester.pumpAndSettle();
      expect(find.byType(LoansScreen), findsOneWidget);
    });

    testWidgets('HomeGoalsSheet muestra total ahorrado, metas y permite navegar a Ver todo y detalle', (tester) async {
      final goal1 = Goal(
        id: 'g-1',
        name: 'Vacaciones',
        icon: 'airplane',
        targetAmount: 5000000,
        createdAt: DateTime(2026, 1, 1),
        archived: false,
      );
      final progress1 = GoalProgress(
        saved: 1800000,
        percent: 0.36,
        remaining: 3200000,
        isCompleted: false,
        realDailyPace: 10000,
        realMonthlyPace: 300000,
        status: const GoalStatus.onTrack(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            activeGoalsWithProgressProvider.overrideWith(
              (ref) => Stream.value([
                GoalWithProgress(goal: goal1, progress: progress1),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: Scaffold(
              body: HomeGoalsSheet(routeAnimation: null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Título y "Ver todo ›"
      expect(find.text('Metas'), findsOneWidget);
      expect(find.text('Ver todo ›'), findsOneWidget);

      // Resumen
      expect(find.text('AHORRADO'), findsOneWidget);
      expect(find.text('Gs. 1.800.000'), findsOneWidget);
      expect(find.text('1 activa'), findsOneWidget);

      // Item
      expect(find.text('Vacaciones'), findsOneWidget);
      expect(find.text('36 %'), findsOneWidget);
      expect(find.text('Gs. 1.800.000 de Gs. 5.000.000'), findsOneWidget);
      expect(find.text('a tiempo'), findsOneWidget);

      // Botón principal
      expect(find.text('Aportar'), findsOneWidget);

      // Tocar "Ver todo ›" abre GoalsScreen
      await tester.tap(find.text('Ver todo ›'));
      await tester.pumpAndSettle();
      expect(find.byType(GoalsScreen), findsOneWidget);
    });
  });
}
