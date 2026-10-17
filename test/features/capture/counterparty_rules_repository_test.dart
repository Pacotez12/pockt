import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/capture/data/counterparty_rules_repository.dart';

void main() {
  late AppDatabase db;
  late CounterpartyRulesRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    repo = CounterpartyRulesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CounterpartyRulesRepository', () {
    test('upsert inserta y actualiza sobre el mismo (nameKey, direction)', () async {
      await repo.upsert(
        nameKey: 'JUAN PEREZ',
        direction: TransferDirection.incoming,
        action: CounterpartyAction.income,
        categoryId: 'cat-1',
        autoApply: true,
      );

      final found1 = await repo.find('JUAN PEREZ', TransferDirection.incoming);
      expect(found1, isNotNull);
      expect(found1!.action, CounterpartyAction.income);
      expect(found1.categoryId, 'cat-1');
      expect(found1.autoApply, isTrue);

      // Actualizar la misma persona y dirección con otra acción
      await repo.upsert(
        nameKey: 'JUAN PEREZ',
        direction: TransferDirection.incoming,
        action: CounterpartyAction.loanRepayment,
        loanId: 'loan-1',
        autoApply: false,
      );

      final found2 = await repo.find('JUAN PEREZ', TransferDirection.incoming);
      expect(found2, isNotNull);
      expect(found2!.action, CounterpartyAction.loanRepayment);
      expect(found2.loanId, 'loan-1');
      expect(found2.autoApply, isFalse);

      final all = await repo.watchAll().first;
      expect(all.length, 1);
    });

    test('delete elimina la regla por id', () async {
      await repo.upsert(
        nameKey: 'MARIA LOPEZ',
        direction: TransferDirection.outgoing,
        action: CounterpartyAction.expense,
      );

      final rule = await repo.find('MARIA LOPEZ', TransferDirection.outgoing);
      expect(rule, isNotNull);

      await repo.delete(rule!.id);
      final afterDelete = await repo.find('MARIA LOPEZ', TransferDirection.outgoing);
      expect(afterDelete, isNull);
    });
  });
}
