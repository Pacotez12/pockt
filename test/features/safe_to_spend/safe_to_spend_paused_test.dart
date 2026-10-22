import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/recurring/data/recurring_repository.dart';
import 'package:pockt/features/safe_to_spend/domain/safe_to_spend.dart';

class _Probe extends ConsumerWidget {
  const _Probe();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(safeToSpendProvider).value;
    return Text('pending:${v?.pendingRecurring}', textDirection: TextDirection.ltr);
  }
}

void main() {
  // Bug real (A54): el Inicio queda tapado por Ajustes (TickerMode apagado),
  // Riverpod pausa el provider y al volver no muestra el cambio del recurrente.
  testWidgets('el valor se actualiza al volver si cambió mientras estaba tapado', (tester) async {
    final db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(db.close);
    final enabled = ValueNotifier(true);

    await tester.runAsync(() async {
      final cat = await (db.select(db.categories)..limit(1)).getSingle();
      final now = DateTime.now();
      await db.into(db.recurringRules).insert(
            RecurringRulesCompanion.insert(
              id: 'crunchy',
              name: 'Crunchyroll',
              type: TxType.expense,
              amount: 29975,
              categoryId: cat.id,
              frequency: 'monthly',
              nextDueDate: DateTime(now.year, now.month, now.day),
            ),
          );
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: ValueListenableBuilder<bool>(
        valueListenable: enabled,
        builder: (_, on, _) => TickerMode(enabled: on, child: const _Probe()),
      ),
    ));
    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
    }

    await settle();
    expect(find.text('pending:29975'), findsOneWidget);

    enabled.value = false; // se abre Ajustes encima
    await settle();
    await tester.runAsync(() => RecurringRepository(db).setActive('crunchy', false));
    await settle();
    enabled.value = true; // vuelve al Inicio
    await settle();
    expect(find.text('pending:0'), findsOneWidget);
  });
}
