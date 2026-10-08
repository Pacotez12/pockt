import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/entry/domain/natural_parser.dart';
import 'package:pockt/features/transactions/data/categories_repository.dart';
import 'package:pockt/features/transactions/data/keywords_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase db;
  late CategoriesRepository catRepo;
  late TransactionsRepository txRepo;
  late KeywordsRepository kwRepo;

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    catRepo = CategoriesRepository(db);
    txRepo = TransactionsRepository(db);
    kwRepo = KeywordsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('renombrar Comida a Comidas -> keywordMap()["pizza"] sigue apuntando a su id', () async {
    final cats = await catRepo.watchActive(CategoryKind.expense).first;
    final comida = cats.firstWhere((c) => c.name == 'Comida');

    // Renombrar categoría en la base
    await (db.update(db.categories)..where((c) => c.id.equals(comida.id))).write(
      const CategoriesCompanion(name: Value('Comidas')),
    );

    final map = await kwRepo.keywordMap();
    expect(map['pizza'], comida.id);
  });

  test('guardar un gasto con comercio Superseis en Hogar -> hogar; 3 en Comida y 1 en Hogar -> gana Comida', () async {
    final cats = await catRepo.watchActive(CategoryKind.expense).first;
    final hogar = cats.firstWhere((c) => c.name == 'Hogar').id;
    final comida = cats.firstWhere((c) => c.name == 'Comida').id;
    final now = DateTime.utc(2026, 10, 8, 12, 0);

    // 1 gasto en Hogar con comercio Superseis
    await txRepo.add(
      type: TxType.expense,
      amount: 150000,
      categoryId: hogar,
      merchant: 'Superseis',
      occurredAt: now,
    );

    var map = await kwRepo.keywordMap();
    expect(map['superseis'], hogar);

    // 3 gastos en Comida con comercio Superseis
    for (var i = 0; i < 3; i++) {
      await txRepo.add(
        type: TxType.expense,
        amount: 50000,
        categoryId: comida,
        merchant: 'Superseis',
        occurredAt: now.add(Duration(hours: i + 1)),
      );
    }

    map = await kwRepo.keywordMap();
    expect(map['superseis'], comida);
  });

  test('addUserKeyword(salud, "Farma") -> parseNaturalEntry("farma 40000", ...)!.categoryId == salud', () async {
    final cats = await catRepo.watchActive(CategoryKind.expense).first;
    final salud = cats.firstWhere((c) => c.name == 'Salud').id;
    final now = DateTime(2026, 10, 8, 14, 0);

    await kwRepo.addUserKeyword(salud, 'Farma');

    final map = await kwRepo.keywordMap();
    final parsed = parseNaturalEntry(
      'farma 40000',
      nowLocal: now,
      keywordToCategoryId: map,
    );

    expect(parsed, isNotNull);
    expect(parsed!.amount, 40000);
    expect(parsed.categoryId, salud);
  });
}
