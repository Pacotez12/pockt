import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/features/transactions/data/categories_repository.dart';

void main() {
  late AppDatabase db;
  late CategoriesRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CategoriesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('seed: 10 categorías de gasto y 3 de ingreso', () async {
    final expenses = await repo.watchActive(CategoryKind.expense).first;
    final incomes = await repo.watchActive(CategoryKind.income).first;
    expect(expenses, hasLength(10));
    expect(incomes, hasLength(3));
  });

  test('seed: ningún name ni icon contiene emojis', () async {
    final expenses = await repo.watchActive(CategoryKind.expense).first;
    final incomes = await repo.watchActive(CategoryKind.income).first;
    final all = [...expenses, ...incomes];

    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
      unicode: true,
    );

    for (final cat in all) {
      expect(cat.name, isNot(matches(emojiRegex)),
          reason: 'Categoría ${cat.name} contiene emoji en el nombre');
      expect(cat.icon, isNot(matches(emojiRegex)),
          reason: 'Categoría ${cat.name} tiene emoji en icon: ${cat.icon}');
    }
  });

  test('seed: todas las claves de icon resuelven a un ícono real', () async {
    final expenses = await repo.watchActive(CategoryKind.expense).first;
    final incomes = await repo.watchActive(CategoryKind.income).first;
    final all = [...expenses, ...incomes];

    for (final cat in all) {
      expect(kCategoryIconKeys, contains(cat.icon),
          reason: 'La clave de ícono ${cat.icon} no está en kCategoryIconKeys');
      if (cat.icon != 'package') {
        expect(
          categoryIconData(cat.icon),
          isNot(equals(PhosphorIconsDuotone.package)),
          reason: 'La categoría ${cat.name} (${cat.icon}) resolvió al respaldo package',
        );
      }
    }
  });
}
