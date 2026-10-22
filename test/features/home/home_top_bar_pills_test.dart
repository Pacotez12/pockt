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
import 'package:pockt/features/home/ui/home_goals_sheet.dart';
import 'package:pockt/features/home/ui/home_loans_sheet.dart';
import 'package:pockt/features/home/ui/home_top_bar.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/loans/domain/loan_progress.dart';
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

  final testLoan = LoanWithProgress(
    loan: Loan(
      id: 'l-1',
      direction: LoanDirection.owe,
      kind: LoanKind.installments,
      name: 'Cuota',
      totalAmount: 1000000,
      paidBeforeCount: 0,
      startDate: DateTime(2026, 1, 1),
      reminderDays: 2,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    progress: LoanProgress(
      paid: 0,
      balance: 1000000,
      percent: 0,
      installmentsPaid: 0,
      isClosed: false,
    ),
  );

  final testGoal = GoalWithProgress(
    goal: Goal(
      id: 'g-1',
      name: 'Meta 1',
      icon: 'target',
      targetAmount: 2000000,
      createdAt: DateTime(2026, 1, 1),
      archived: false,
    ),
    progress: GoalProgress(
      saved: 500000,
      percent: 0.25,
      remaining: 1500000,
      isCompleted: false,
      realDailyPace: 5000,
      realMonthlyPace: 150000,
      status: const GoalStatus.onTrack(),
    ),
  );

  group('HomeTopBar pill buttons (Préstamos y Metas)', () {
    testWidgets('sin préstamos ni metas activas, solo muestra el botón de Ajustes', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            activeLoansWithProgressProvider.overrideWith((ref) => Stream.value([])),
            activeGoalsWithProgressProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: Scaffold(
              body: HomeTopBar(
                month: 10,
                onMonthSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home-pill-loans')), findsNothing);
      expect(find.byKey(const ValueKey('home-pill-goals')), findsNothing);
      expect(find.byKey(const ValueKey('home-settings-button')), findsOneWidget);
      expect(find.text('Octubre ▾'), findsOneWidget);
    });

    testWidgets('con préstamos y metas activas: al abrir muestra nombre ("Préstamos 1", "Metas 1") y mes abreviado "Oct ▾"', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            activeLoansWithProgressProvider.overrideWith((ref) => Stream.value([testLoan])),
            activeGoalsWithProgressProvider.overrideWith((ref) => Stream.value([testGoal])),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: Scaffold(
              body: HomeTopBar(
                month: 10,
                onMonthSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Mes abreviado
      expect(find.text('Oct ▾'), findsOneWidget);

      // Píldoras con nombre visible
      expect(find.byKey(const ValueKey('home-pill-loans')), findsOneWidget);
      expect(find.text('Préstamos'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2)); // 1 de préstamos y 1 de metas

      expect(find.byKey(const ValueKey('home-pill-goals')), findsOneWidget);
      expect(find.text('Metas'), findsOneWidget);

      // A los ~3s se achican con animación (no de golpe): a mitad de camino
      // la píldora es más angosta que al inicio pero más ancha que al final.
      final wideLoans = tester.getSize(find.byKey(const ValueKey('home-pill-loans'))).width;
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 120));
      final midLoans = tester.getSize(find.byKey(const ValueKey('home-pill-loans'))).width;
      await tester.pumpAndSettle();
      final narrowLoans = tester.getSize(find.byKey(const ValueKey('home-pill-loans'))).width;
      expect(midLoans, lessThan(wideLoans));
      expect(midLoans, greaterThan(narrowLoans));

      expect(find.text('Octubre ▾'), findsOneWidget);
      expect(find.text('Préstamos'), findsNothing);
      expect(find.text('Metas'), findsNothing);
      // Los números siguen visibles
      expect(find.text('1'), findsNWidgets(2));
    });

    testWidgets('tocar la píldora de Préstamos abre HomeLoansSheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            activeLoansWithProgressProvider.overrideWith((ref) => Stream.value([testLoan])),
            activeGoalsWithProgressProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: Scaffold(
              body: HomeTopBar(
                month: 10,
                onMonthSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-pill-loans')));
      await tester.pumpAndSettle();

      expect(find.byType(HomeLoansSheet), findsOneWidget);
    });

    testWidgets('tocar la píldora de Metas abre HomeGoalsSheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            activeLoansWithProgressProvider.overrideWith((ref) => Stream.value([])),
            activeGoalsWithProgressProvider.overrideWith((ref) => Stream.value([testGoal])),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: Scaffold(
              body: HomeTopBar(
                month: 10,
                onMonthSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-pill-goals')));
      await tester.pumpAndSettle();

      expect(find.byType(HomeGoalsSheet), findsOneWidget);
    });

    testWidgets('long-press en píldora muestra globito tooltip y al soltar desaparece', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            activeLoansWithProgressProvider.overrideWith((ref) => Stream.value([testLoan])),
            activeGoalsWithProgressProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: Scaffold(
              body: HomeTopBar(
                month: 10,
                onMonthSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press start
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-pill-loans'))));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Préstamos · 1 activo'), findsOneWidget);
      expect(find.text('Debés Gs. 1.000.000 · tocá para ver'), findsOneWidget);

      // Release finger
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Préstamos · 1 activo'), findsNothing);
    });
  });
}
