import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/reports/domain/ant_expenses.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  const catComida = Category(
    id: 'cat-1',
    name: 'Comida',
    icon: 'fork-knife',
    colorDark: 0xFFFFAA00,
    colorLight: 0xFFFF8800,
    kind: CategoryKind.expense,
    sortOrder: 0,
    archived: false,
  );

  const catTransporte = Category(
    id: 'cat-2',
    name: 'Transporte',
    icon: 'bus',
    colorDark: 0xFF00AAFF,
    colorLight: 0xFF0088DD,
    kind: CategoryKind.expense,
    sortOrder: 1,
    archived: false,
  );

  Transaction makeTx({
    required String id,
    required int amount,
    required String categoryId,
    String? merchant,
    TxType type = TxType.expense,
    DateTime? occurredAt,
  }) {
    return Transaction(
      id: id,
      type: type,
      amount: amount,
      currency: 'PYG',
      categoryId: categoryId,
      merchant: merchant,
      occurredAt: occurredAt ?? DateTime(2026, 10, 10, 12, 0),
      createdAt: DateTime(2026, 10, 10, 12, 0),
      updatedAt: occurredAt ?? DateTime(2026, 10, 10, 12, 0),
      source: TxSource.manual,
      isExtra: false,
    );
  }

  group('calculateAntExpenses', () {
    test('lista vacía devuelve totales en 0 y grupos vacíos', () {
      final summary = calculateAntExpenses(transactions: [], threshold: 30000);

      expect(summary.total, 0);
      expect(summary.count, 0);
      expect(summary.annualProjection, 0);
      expect(summary.threshold, 30000);
      expect(summary.groups, isEmpty);
    });

    test('ignora ingresos y gastos mayores al umbral', () {
      final items = [
        TxView(
          tx: makeTx(
            id: '1',
            amount: 25000,
            categoryId: catComida.id,
            merchant: 'Café',
          ),
          category: catComida,
        ),
        TxView(
          tx: makeTx(
            id: '2',
            amount: 35000,
            categoryId: catComida.id,
            merchant: 'Almuerzo',
          ),
          category: catComida,
        ),
        TxView(
          tx: makeTx(
            id: '3',
            amount: 15000,
            categoryId: catTransporte.id,
            type: TxType.income,
          ),
          category: catTransporte,
        ),
      ];

      final summary = calculateAntExpenses(
        transactions: items,
        threshold: 30000,
      );

      expect(summary.total, 25000);
      expect(summary.count, 1);
      expect(summary.annualProjection, 25000 * 12);
      expect(summary.groups.length, 1);
      expect(summary.groups.first.name, 'Café');
    });

    test('proyección anual es exactamente total del mes * 12', () {
      final items = [
        TxView(
          tx: makeTx(
            id: '1',
            amount: 10000,
            categoryId: catComida.id,
            merchant: 'Snack A',
          ),
          category: catComida,
        ),
        TxView(
          tx: makeTx(
            id: '2',
            amount: 20000,
            categoryId: catComida.id,
            merchant: 'Snack B',
          ),
          category: catComida,
        ),
      ];

      final summary = calculateAntExpenses(
        transactions: items,
        threshold: 30000,
      );

      expect(summary.total, 30000);
      expect(summary.count, 2);
      expect(summary.annualProjection, 360000);
    });

    test(
      'agrupa por comercio normalizando mayúsculas y calculando promedio',
      () {
        final items = [
          TxView(
            tx: makeTx(
              id: '1',
              amount: 10000,
              categoryId: catComida.id,
              merchant: 'Biggie',
            ),
            category: catComida,
          ),
          TxView(
            tx: makeTx(
              id: '2',
              amount: 20000,
              categoryId: catComida.id,
              merchant: 'biggie',
            ),
            category: catComida,
          ),
          TxView(
            tx: makeTx(
              id: '3',
              amount: 15000,
              categoryId: catComida.id,
              merchant: 'Biggie',
            ),
            category: catComida,
          ),
        ];

        final summary = calculateAntExpenses(
          transactions: items,
          threshold: 30000,
        );

        expect(summary.total, 45000);
        expect(summary.count, 3);
        expect(summary.groups.length, 1);
        final g = summary.groups.first;
        expect(g.name, 'Biggie');
        expect(g.total, 45000);
        expect(g.count, 3);
        expect(g.average, 15000);
        expect(g.categoryName, 'Comida');
        expect(g.categoryIcon, 'fork-knife');
      },
    );

    test('agrupa por categoría cuando el movimiento no tiene comercio', () {
      final items = [
        TxView(
          tx: makeTx(
            id: '1',
            amount: 8000,
            categoryId: catTransporte.id,
            merchant: null,
          ),
          category: catTransporte,
        ),
        TxView(
          tx: makeTx(
            id: '2',
            amount: 12000,
            categoryId: catTransporte.id,
            merchant: '   ',
          ),
          category: catTransporte,
        ),
        TxView(
          tx: makeTx(
            id: '3',
            amount: 15000,
            categoryId: catComida.id,
            merchant: 'Empanada',
          ),
          category: catComida,
        ),
      ];

      final summary = calculateAntExpenses(
        transactions: items,
        threshold: 30000,
      );

      expect(summary.total, 35000);
      expect(summary.count, 3);
      expect(summary.groups.length, 2);

      // Ordenado de mayor a menor total
      final first = summary.groups[0];
      final second = summary.groups[1];

      expect(first.name, 'Transporte');
      expect(first.total, 20000);
      expect(first.count, 2);
      expect(first.average, 10000);
      expect(first.categoryIcon, 'bus');

      expect(second.name, 'Empanada');
      expect(second.total, 15000);
      expect(second.count, 1);
      expect(second.average, 15000);
      expect(second.categoryIcon, 'fork-knife');
    });

    test('respeta umbral personalizado', () {
      final items = [
        TxView(
          tx: makeTx(
            id: '1',
            amount: 45000,
            categoryId: catComida.id,
            merchant: 'Café especial',
          ),
          category: catComida,
        ),
      ];

      final summaryStandard = calculateAntExpenses(
        transactions: items,
        threshold: 30000,
      );
      expect(summaryStandard.count, 0);

      final summaryCustom = calculateAntExpenses(
        transactions: items,
        threshold: 50000,
      );
      expect(summaryCustom.count, 1);
      expect(summaryCustom.total, 45000);
    });
  });
}
