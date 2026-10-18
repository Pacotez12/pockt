import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/home/domain/home_cards_config.dart';
import 'package:pockt/features/home/ui/home_cards_screen.dart';
import 'package:pockt/features/home/ui/home_screen.dart';
import 'package:pockt/features/income/domain/period_summary.dart';
import 'package:pockt/features/safe_to_spend/domain/safe_to_spend.dart';
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

  group('Tarjetas del Inicio y Franja Podés gastar hoy', () {
    test('defaultCards no contiene loans ni goals y calendar está primero', () {
      final cards = HomeCardItem.defaultCards();
      final ids = cards.map((c) => c.id).toList();
      expect(ids.contains('loans'), isFalse);
      expect(ids.contains('goals'), isFalse);
      expect(ids.first, equals('calendar'));
    });

    test('decode ignora préstamos y metas de configuraciones guardadas previas', () {
      const legacyJson =
          '[{"id":"period","visible":true},{"id":"loans","visible":true},{"id":"goals","visible":true},{"id":"calendar","visible":true}]';
      final decoded = HomeCardItem.decode(legacyJson);
      final ids = decoded.map((c) => c.id).toList();
      expect(ids.contains('loans'), isFalse);
      expect(ids.contains('goals'), isFalse);
      expect(ids.contains('calendar'), isTrue);
    });

    testWidgets('CompactSafeToSpendCard es una franja sin GlassCard', (tester) async {
      final now = DateTime(2026, 10, 15, 12, 0);
      final safe = SafeToSpend(
        amount: 63394,
        todayAllowance: 63394,
        spentToday: 0,
        quedan: 3451500,
        pendingRecurring: 0,
        proratedGoals: 0,
        daysUntilPay: 12,
        targetDate: DateTime(2026, 10, 31),
        hasIncomeSchedule: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            safeToSpendProvider.overrideWith((ref) => Stream.value(safe)),
            homePeriodSummaryProvider(now).overrideWithValue(
              HomePeriodSummary(
                schedule: IncomeSchedule(
                  id: 's-1',
                  mode: 'biweekly',
                  payDays: '[15, -1]',
                  payDayRules: '["either", "previous"]',
                  paySplitPercents: '[50, 50]',
                  categoryId: 'cat-salary',
                  effectiveFrom: DateTime(2026, 9, 1),
                ),
                periodLine: PeriodLine(
                  label: '2ª quincena',
                  remaining: 3451500,
                  daysToNextPay: 12,
                  nextPayDate: DateTime(2026, 10, 31),
                  periodStartDate: DateTime(2026, 10, 15),
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: Scaffold(
              body: CompactSafeToSpendCard(nowLocal: now),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No debe ser GlassCard
      expect(find.descendant(of: find.byType(CompactSafeToSpendCard), matching: find.byType(GlassCard)), findsNothing);

      // Fila 1: Podés gastar hoy y monto
      expect(find.text('Podés gastar hoy'), findsOneWidget);
      expect(find.text('Gs. 63.394'), findsOneWidget);

      // Con spentToday == 0: no muestra barrita ni texto "gastaste hoy"
      expect(find.textContaining('gastaste hoy'), findsNothing);

      // Fila 2: period-line
      expect(find.byKey(const ValueKey('period-line')), findsOneWidget);
      expect(find.textContaining('Gs. 3.451.500'), findsOneWidget);
    });

    testWidgets('HomeCardsScreen no lista loans ni goals', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: const HomeCardsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Préstamos y cuotas'), findsNothing);
      expect(find.text('Metas'), findsNothing);
      expect(find.text('Calendario de calor'), findsOneWidget);
    });
  });
}
