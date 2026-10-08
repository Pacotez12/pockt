import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/entry/domain/natural_parser.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Categories,
  Transactions,
  SuggestedTransactions,
  RecurringRules,
  IncomeSchedules,
  Budgets,
  DayMarks,
  Settings,
  CategoryKeywords,
  MerchantMemory,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _seedCategories();
        await _seedCategoryKeywords();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(categoryKeywords);
          await m.createTable(merchantMemory);
          await _seedCategoryKeywords();
          await _preloadMerchantMemory();
        }
      },
    );
  }

  Future<void> _seedCategoryKeywords() async {
    final cats = await select(categories).get();
    final companionList = <CategoryKeywordsCompanion>[];
    const uuid = Uuid();

    for (final cat in cats) {
      final list = kSeedCategoryKeywords[cat.name];
      if (list != null) {
        final seen = <String>{};
        for (final kw in list) {
          final norm = normalizeKeyword(kw);
          if (norm.isNotEmpty && seen.add(norm)) {
            companionList.add(
              CategoryKeywordsCompanion.insert(
                id: uuid.v4(),
                categoryId: cat.id,
                keyword: norm,
                source: KeywordSource.seed,
              ),
            );
          }
        }
      }
    }

    if (companionList.isNotEmpty) {
      await batch((b) {
        b.insertAll(categoryKeywords, companionList);
      });
    }
  }

  Future<void> _preloadMerchantMemory() async {
    final txs = await (select(transactions)
          ..where((t) => t.merchant.isNotNull() & t.deletedAt.isNull()))
        .get();

    final counts = <(String, String), ({int uses, DateTime lastUsedAt})>{};

    for (final tx in txs) {
      final m = tx.merchant?.trim();
      if (m == null || m.isEmpty) continue;
      final norm = normalizeKeyword(m);
      if (norm.isEmpty) continue;

      final pair = (norm, tx.categoryId);
      final current = counts[pair];
      if (current == null) {
        counts[pair] = (uses: 1, lastUsedAt: tx.occurredAt);
      } else {
        final newest = tx.occurredAt.isAfter(current.lastUsedAt)
            ? tx.occurredAt
            : current.lastUsedAt;
        counts[pair] = (uses: current.uses + 1, lastUsedAt: newest);
      }
    }

    if (counts.isNotEmpty) {
      final companions = counts.entries.map((e) {
        return MerchantMemoryCompanion.insert(
          merchantKey: e.key.$1,
          categoryId: e.key.$2,
          uses: e.value.uses,
          lastUsedAt: e.value.lastUsedAt,
        );
      }).toList();

      await batch((b) {
        b.insertAll(merchantMemory, companions);
      });
    }
  }

  Future<void> _seedCategories() async {
    final seed = <CategoriesCompanion>[
      // 10 categorías de gasto
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000001'),
        name: Value('Comida'),
        icon: Value('fork-knife'),
        colorDark: Value(0xFFFF9F43),
        colorLight: Value(0xFFD9771A),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(0),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000002'),
        name: Value('Transporte'),
        icon: Value('car-profile'),
        colorDark: Value(0xFF54A0FF),
        colorLight: Value(0xFF1F6FD1),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(1),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000003'),
        name: Value('Hogar'),
        icon: Value('house-line'),
        colorDark: Value(0xFF1DD1A1),
        colorLight: Value(0xFF0E9673),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(2),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000004'),
        name: Value('Salud'),
        icon: Value('heartbeat'),
        colorDark: Value(0xFFFF6B6B),
        colorLight: Value(0xFFD64545),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(3),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000005'),
        name: Value('Ocio'),
        icon: Value('popcorn'),
        colorDark: Value(0xFFC56CF0),
        colorLight: Value(0xFF9B3FC9),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(4),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000006'),
        name: Value('Servicios'),
        icon: Value('lightning'),
        colorDark: Value(0xFF48DBFB),
        colorLight: Value(0xFF0E9CBF),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(5),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000007'),
        name: Value('Educación'),
        icon: Value('graduation-cap'),
        colorDark: Value(0xFFA4B0BE),
        colorLight: Value(0xFF5D6B7A),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(6),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000008'),
        name: Value('Regalos'),
        icon: Value('gift'),
        colorDark: Value(0xFFFECA57),
        colorLight: Value(0xFFC9921A),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(7),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000009'),
        name: Value('Ropa'),
        icon: Value('t-shirt'),
        colorDark: Value(0xFFF368E0),
        colorLight: Value(0xFFC43BB2),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(8),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000010'),
        name: Value('Otros'),
        icon: Value('package'),
        colorDark: Value(0xFF8395A7),
        colorLight: Value(0xFF556677),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(9),
      ),

      // 3 categorías de ingreso
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000011'),
        name: Value('Sueldo'),
        icon: Value('briefcase'),
        colorDark: Value(0xFF10B981),
        colorLight: Value(0xFF059669),
        kind: Value(CategoryKind.income),
        sortOrder: Value(0),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000012'),
        name: Value('Extra'),
        icon: Value('sparkle'),
        colorDark: Value(0xFF06B6D4),
        colorLight: Value(0xFF0891B2),
        kind: Value(CategoryKind.income),
        sortOrder: Value(1),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000013'),
        name: Value('Otros ingresos'),
        icon: Value('arrow-circle-down'),
        colorDark: Value(0xFF6366F1),
        colorLight: Value(0xFF4338CA),
        kind: Value(CategoryKind.income),
        sortOrder: Value(2),
      ),
    ];

    await batch((b) {
      b.insertAll(categories, seed);
    });
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'pockt');
  }
}
