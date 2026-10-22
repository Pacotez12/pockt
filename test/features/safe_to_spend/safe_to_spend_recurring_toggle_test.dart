import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/recurring/data/recurring_repository.dart';
import 'package:pockt/features/safe_to_spend/domain/safe_to_spend.dart';

void main() {
  // Bug real (A54): apagar un recurrente no actualizaba "Podés gastar hoy"
  // hasta reiniciar la app.
  test('apagar un recurrente lo saca de "Podés gastar hoy" sin reiniciar', () async {
    final db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    final cat = await (db.select(db.categories)..limit(1)).getSingle();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await db.into(db.recurringRules).insert(
          RecurringRulesCompanion.insert(
            id: 'crunchy',
            name: 'Crunchyroll',
            type: TxType.expense,
            amount: 29975,
            categoryId: cat.id,
            frequency: 'monthly',
            nextDueDate: today,
          ),
        );

    final values = <SafeToSpend>[];
    final sub = container.listen(safeToSpendProvider, (_, next) {
      if (next.value != null) values.add(next.value!);
    });
    addTearDown(sub.close);

    Future<void> waitFor(bool Function(SafeToSpend v) ok) async {
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (values.isEmpty || !ok(values.last)) {
        if (DateTime.now().isAfter(deadline)) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    await waitFor((v) => v.pendingRecurring == 29975);
    expect(values.last.pendingRecurring, 29975);

    await RecurringRepository(db).setActive('crunchy', false);
    await waitFor((v) => v.pendingRecurring == 0);
    expect(values.last.pendingRecurring, 0);
  });
}
