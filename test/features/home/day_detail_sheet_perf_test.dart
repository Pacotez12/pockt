import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/home/ui/day_detail_sheet.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:timezone/data/latest.dart' as tz;

class CountingTransactionsRepository extends TransactionsRepository {
  int watchDayCalls = 0;
  int watchDailyExpenseTotalsCalls = 0;

  CountingTransactionsRepository(super.db);

  @override
  Stream<List<TxView>> watchDay(DateTime localDay) {
    watchDayCalls++;
    return super.watchDay(localDay);
  }

  @override
  Stream<Map<int, int>> watchDailyExpenseTotals(
    int year,
    int month, {
    DatePeriod? period,
  }) {
    watchDailyExpenseTotalsCalls++;
    return super.watchDailyExpenseTotals(year, month, period: period);
  }
}

void main() {
  late AppDatabase testDb;
  late CountingTransactionsRepository countingRepo;

  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() {
    setLocalZone('America/Asuncion');
    testDb = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    countingRepo = CountingTransactionsRepository(testDb);
  });

  tearDown(() async {
    await testDb.close();
  });

  testWidgets(
    'DayDetailSheet no recrea streams de Drift al reconstruirse el widget',
    (tester) async {
      int rebuildCount = 0;
      late StateSetter setParentState;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
            transactionsRepositoryProvider.overrideWithValue(countingRepo),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: StatefulBuilder(
              builder: (context, setState) {
                setParentState = setState;
                return Scaffold(
                  body: Column(
                    children: [
                      Text('Rebuilds: $rebuildCount'),
                      Expanded(
                        child: DayDetailSheet(localDay: DateTime(2026, 10, 15)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(countingRepo.watchDayCalls, 1);
      expect(countingRepo.watchDailyExpenseTotalsCalls, 1);

      // Reconstruir el widget padre 5 veces
      for (int i = 0; i < 5; i++) {
        setParentState(() {
          rebuildCount++;
        });
        await tester.pump();
      }

      // Los streams NO deben haberse recreado en cada build
      expect(
        countingRepo.watchDayCalls,
        1,
        reason: 'watchDay no debe llamarse en cada build',
      );
      expect(
        countingRepo.watchDailyExpenseTotalsCalls,
        1,
        reason: 'watchDailyExpenseTotals no debe llamarse en cada build',
      );
    },
  );
}
