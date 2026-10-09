import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/reports/data/reports_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionsRepository txRepo;
  late ReportsRepository reportsRepo;
  late String comidaId;
  late String transporteId;
  late String sueldoId;

  setUp(() async {
    setLocalZone('America/Asuncion');
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    txRepo = TransactionsRepository(db);
    reportsRepo = ReportsRepository(db);

    final cats = await db.select(db.categories).get();
    comidaId = cats.firstWhere((c) => c.name == 'Comida').id;
    transporteId = cats.firstWhere((c) => c.name == 'Transporte').id;
    sueldoId = cats.firstWhere((c) => c.name == 'Sueldo').id;
  });

  tearDown(() async {
    await db.close();
  });

  group('watchEvolution', () {
    test('evolución de 6 meses con huecos en 0 y movimientos borrados excluidos', () async {
      // Mayo 2026 (mes 5): sin datos -> 0
      // Junio 2026 (mes 6): gasto 100.000, ingreso 500.000
      await txRepo.add(
        type: TxType.expense,
        amount: 100000,
        categoryId: comidaId,
        occurredAt: DateTime(2026, 6, 10, 12, 0),
      );
      await txRepo.add(
        type: TxType.income,
        amount: 500000,
        categoryId: sueldoId,
        occurredAt: DateTime(2026, 6, 15, 12, 0),
      );

      // Julio 2026 (mes 7): un gasto normal y un gasto borrado
      await txRepo.add(
        type: TxType.expense,
        amount: 50000,
        categoryId: comidaId,
        occurredAt: DateTime(2026, 7, 5, 12, 0),
      );
      final txBorrada = await txRepo.add(
        type: TxType.expense,
        amount: 80000,
        categoryId: comidaId,
        occurredAt: DateTime(2026, 7, 6, 12, 0),
      );
      await txRepo.softDelete(txBorrada);

      // Agosto 2026 (mes 8): sin datos -> 0
      // Septiembre 2026 (mes 9): sin datos -> 0
      // Octubre 2026 (mes 10): gasto 300.000, ingreso 1.000.000
      await txRepo.add(
        type: TxType.expense,
        amount: 300000,
        categoryId: transporteId,
        occurredAt: DateTime(2026, 10, 2, 12, 0),
      );
      await txRepo.add(
        type: TxType.income,
        amount: 1000000,
        categoryId: sueldoId,
        occurredAt: DateTime(2026, 10, 5, 12, 0),
      );

      final evolution = await reportsRepo.watchEvolution(
        months: 6,
        todayLocal: DateTime(2026, 10, 15),
      ).first;

      expect(evolution.length, equals(6));

      // Orden: mayo a octubre (viejo a nuevo)
      expect(evolution.map((m) => '${m.year}-${m.month}').toList(), [
        '2026-5',
        '2026-6',
        '2026-7',
        '2026-8',
        '2026-9',
        '2026-10',
      ]);

      // Mayo: 0
      expect(evolution[0].expense, 0);
      expect(evolution[0].income, 0);
      expect(evolution[0].saving, 0);

      // Junio: gasto 100.000, ingreso 500.000 -> saving 400.000
      expect(evolution[1].expense, 100000);
      expect(evolution[1].income, 500000);
      expect(evolution[1].saving, 400000);

      // Julio: gasto 50.000 (borrado 80.000 excluido)
      expect(evolution[2].expense, 50000);
      expect(evolution[2].income, 0);
      expect(evolution[2].saving, -50000);

      // Agosto y Septiembre: 0
      expect(evolution[3].expense, 0);
      expect(evolution[4].expense, 0);

      // Octubre: gasto 300.000, ingreso 1.000.000 -> saving 700.000
      expect(evolution[5].expense, 300000);
      expect(evolution[5].income, 1000000);
      expect(evolution[5].saving, 700000);
    });
  });

  group('watchByMerchant', () {
    test('por comercio agrupa Superseis y superseis mostrando la escritura más usada', () async {
      // 2 veces 'Superseis' y 1 vez 'superseis'
      await txRepo.add(
        type: TxType.expense,
        amount: 100000,
        categoryId: comidaId,
        merchant: 'Superseis',
        occurredAt: DateTime(2026, 10, 1, 12, 0),
      );
      await txRepo.add(
        type: TxType.expense,
        amount: 50000,
        categoryId: comidaId,
        merchant: 'Superseis',
        occurredAt: DateTime(2026, 10, 2, 12, 0),
      );
      await txRepo.add(
        type: TxType.expense,
        amount: 30000,
        categoryId: comidaId,
        merchant: 'superseis',
        occurredAt: DateTime(2026, 10, 3, 12, 0),
      );

      // Otro comercio
      await txRepo.add(
        type: TxType.expense,
        amount: 25000,
        categoryId: transporteId,
        merchant: 'Bolt',
        occurredAt: DateTime(2026, 10, 4, 12, 0),
      );

      // Sin comercio (excluido)
      await txRepo.add(
        type: TxType.expense,
        amount: 10000,
        categoryId: comidaId,
        occurredAt: DateTime(2026, 10, 5, 12, 0),
      );

      // Borrado (excluido)
      final borrado = await txRepo.add(
        type: TxType.expense,
        amount: 99999,
        categoryId: comidaId,
        merchant: 'Biggie',
        occurredAt: DateTime(2026, 10, 6, 12, 0),
      );
      await txRepo.softDelete(borrado);

      final result = await reportsRepo.watchByMerchant(2026, 10).first;

      expect(result.length, equals(2));

      // Primero Superseis: total 180.000, count 3, nombre con mayúscula (más frecuente)
      expect(result[0].merchant, 'Superseis');
      expect(result[0].total, 180000);
      expect(result[0].count, 3);

      // Segundo Bolt: total 25.000, count 1
      expect(result[1].merchant, 'Bolt');
      expect(result[1].total, 25000);
      expect(result[1].count, 1);
    });
  });

  group('watchMonthByCategory', () {
    test('devuelve categorías con gastos ordenadas por total descendente', () async {
      await txRepo.add(
        type: TxType.expense,
        amount: 150000,
        categoryId: comidaId,
        occurredAt: DateTime(2026, 10, 1, 12, 0),
      );
      await txRepo.add(
        type: TxType.expense,
        amount: 300000,
        categoryId: transporteId,
        occurredAt: DateTime(2026, 10, 2, 12, 0),
      );

      final result = await reportsRepo.watchMonthByCategory(2026, 10).first;

      expect(result.length, equals(2));
      expect(result[0].category.id, transporteId);
      expect(result[0].total, 300000);
      expect(result[1].category.id, comidaId);
      expect(result[1].total, 150000);
    });
  });
}
