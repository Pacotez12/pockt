import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/home/ui/home_screen.dart';
import 'package:pockt/features/safe_to_spend/domain/safe_to_spend.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  late AppDatabase db;

  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() {
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

  final testSafeToSpend = SafeToSpend(
    amount: 150000,
    quedan: 1500000,
    pendingRecurring: 0,
    proratedGoals: 0,
    daysUntilPay: 10,
    targetDate: DateTime(2026, 10, 31),
    hasIncomeSchedule: false,
  );

  final testNegativeSafeToSpend = SafeToSpend(
    amount: -25000,
    quedan: -250000,
    pendingRecurring: 0,
    proratedGoals: 0,
    daysUntilPay: 10,
    targetDate: DateTime(2026, 10, 31),
    hasIncomeSchedule: false,
  );

  testWidgets(
    'modo safeToSpend por defecto: muestra "Podés gastar hoy" y subtítulo',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            safeToSpendProvider.overrideWith(
              (ref) => Stream.value(testSafeToSpend),
            ),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: HomeScreen(
              initialYear: 2026,
              initialMonth: 10,
              nowLocal: DateTime(2026, 10, 15, 12, 0),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Podés gastar hoy'), findsOneWidget);
      expect(find.text('Gs. 150.000'), findsOneWidget);
      expect(find.textContaining('Gastado'), findsOneWidget);
      expect(find.textContaining('Quedan Gs. 1.500.000'), findsOneWidget);
    },
  );

  testWidgets('modo safeToSpend negativo: muestra monto en color danger', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          safeToSpendProvider.overrideWith(
            (ref) => Stream.value(testNegativeSafeToSpend),
          ),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: HomeScreen(
            initialYear: 2026,
            initialMonth: 10,
            nowLocal: DateTime(2026, 10, 15, 12, 0),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Podés gastar hoy'), findsOneWidget);
    expect(find.text('−Gs. 25.000'), findsOneWidget);

    final textWidget = tester.widget<Text>(
      find.byKey(const ValueKey('safe-to-spend-amount')),
    );
    expect(textWidget.style?.color, equals(PocktColors.dark.danger));
  });

  testWidgets(
    'modo monthSpent: muestra "Gastado en octubre" y total tradicional',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            homeHeadlineProvider.overrideWith(
              (ref) => Stream.value(HomeHeadline.monthSpent),
            ),
            safeToSpendProvider.overrideWith(
              (ref) => Stream.value(testSafeToSpend),
            ),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: HomeScreen(
              initialYear: 2026,
              initialMonth: 10,
              nowLocal: DateTime(2026, 10, 15, 12, 0),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Gastado en octubre'), findsOneWidget);
      expect(find.text('Podés gastar hoy'), findsNothing);
      expect(
        find.byKey(const ValueKey('safe-to-spend-subtitle')),
        findsNothing,
      );
    },
  );

  testWidgets('modo safeToSpend con montos ocultos: respeta ocultar montos', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          privacyHideAmountsProvider.overrideWith((ref) => Stream.value(true)),
          safeToSpendProvider.overrideWith(
            (ref) => Stream.value(testSafeToSpend),
          ),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: HomeScreen(
            initialYear: 2026,
            initialMonth: 10,
            nowLocal: DateTime(2026, 10, 15, 12, 0),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Podés gastar hoy'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('spending-total-obscured')),
      findsOneWidget,
    );
    expect(find.text('Gastado •••• · Quedan ••••'), findsOneWidget);
  });
}
