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
import 'package:pockt/features/home/ui/home_screen.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  late AppDatabase db;
  late TransactionsRepository txRepo;
  const sueldoId = '018f0000-0000-7000-8000-000000000011';
  const comidaId = '018f0000-0000-7000-8000-000000000001';

  setUpAll(() => tz.initializeTimeZones());

  setUp(() async {
    setLocalZone('America/Asuncion');
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    txRepo = TransactionsRepository(db);
    await db
        .into(db.incomeSchedules)
        .insert(
          IncomeSchedulesCompanion.insert(
            id: 'sched-1',
            mode: 'biweekly',
            payDays: '[15, -1]',
            payDayRules: '["either", "previous"]',
            paySplitPercents: '[50, 50]',
            categoryId: sueldoId,
            effectiveFrom: DateTime(2026, 9, 30),
          ),
        );
    // Cobro de la quincena anterior y el de la actual.
    await txRepo.add(
      type: TxType.income,
      amount: 3200000,
      categoryId: sueldoId,
      occurredAt: DateTime(2026, 9, 30, 9),
    );
    await txRepo.add(
      type: TxType.income,
      amount: 3200000,
      categoryId: sueldoId,
      occurredAt: DateTime(2026, 10, 15, 9),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          homeHeadlineProvider.overrideWith(
            (ref) => Stream.value(HomeHeadline.monthSpent),
          ),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: HomeScreen(
            initialYear: 2026,
            initialMonth: 10,
            nowLocal: DateTime(2026, 10, 16, 10),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
  }

  testWidgets('el negativo de la quincena anterior se descuenta y se aclara', (
    tester,
  ) async {
    await txRepo.add(
      type: TxType.expense,
      amount: 3500000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 10, 12),
    );
    await pumpHome(tester);

    expect(
      find.text('incluye −Gs. 300.000 de la quincena anterior'),
      findsOneWidget,
    );
    expect(find.textContaining('Gs. 2.900.000'), findsWidgets);
    expect(find.textContaining('Te sobraron'), findsNothing);
  });

  testWidgets('lo que sobró ofrece la tarjeta y Sumar la cierra', (
    tester,
  ) async {
    await txRepo.add(
      type: TxType.expense,
      amount: 2700000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 10, 12),
    );
    await pumpHome(tester);

    expect(find.textContaining('Te sobraron'), findsOneWidget);
    await tester.ensureVisible(find.text('Sumar a esta quincena'));
    await tester.tap(find.text('Sumar a esta quincena'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Te sobraron'), findsNothing);
    expect(
      find.text('incluye +Gs. 500.000 de la quincena anterior'),
      findsOneWidget,
    );
  });
}
