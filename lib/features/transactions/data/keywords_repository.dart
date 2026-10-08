import 'package:drift/drift.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/entry/domain/natural_parser.dart';
import 'package:uuid/uuid.dart';

class KeywordsRepository {
  final AppDatabase db;

  KeywordsRepository(this.db);

  Stream<List<CategoryKeyword>> watchFor(String categoryId) {
    return (db.select(db.categoryKeywords)
          ..where((k) => k.categoryId.equals(categoryId))
          ..orderBy([
            (k) => OrderingTerm(expression: k.keyword, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<void> addUserKeyword(String categoryId, String keyword) async {
    final norm = normalizeKeyword(keyword);
    if (norm.isEmpty) return;

    final existing = await (db.select(db.categoryKeywords)
          ..where((k) => k.categoryId.equals(categoryId) & k.keyword.equals(norm)))
        .getSingleOrNull();

    if (existing != null) {
      return;
    }

    await db.into(db.categoryKeywords).insert(
          CategoryKeywordsCompanion.insert(
            id: const Uuid().v4(),
            categoryId: categoryId,
            keyword: norm,
            source: KeywordSource.user,
          ),
        );
  }

  Future<void> remove(String id) async {
    await (db.delete(db.categoryKeywords)..where((k) => k.id.equals(id))).go();
  }

  Future<Map<String, String>> keywordMap() async {
    // 1. MerchantMemory: categoría con más uses para cada merchantKey
    final memories = await db.select(db.merchantMemory).get();
    final bestMerchantByCategory =
        <String, ({String categoryId, int uses, DateTime lastUsedAt})>{};

    for (final m in memories) {
      final current = bestMerchantByCategory[m.merchantKey];
      if (current == null) {
        bestMerchantByCategory[m.merchantKey] = (
          categoryId: m.categoryId,
          uses: m.uses,
          lastUsedAt: m.lastUsedAt,
        );
      } else if (m.uses > current.uses ||
          (m.uses == current.uses && m.lastUsedAt.isAfter(current.lastUsedAt))) {
        bestMerchantByCategory[m.merchantKey] = (
          categoryId: m.categoryId,
          uses: m.uses,
          lastUsedAt: m.lastUsedAt,
        );
      }
    }

    // 2. CategoryKeywords (user y seed)
    final allKeywords = await db.select(db.categoryKeywords).get();
    final userKeywords = <String, String>{};
    final seedKeywords = <String, String>{};

    for (final kw in allKeywords) {
      if (kw.source == KeywordSource.user) {
        userKeywords[kw.keyword] = kw.categoryId;
      } else {
        seedKeywords[kw.keyword] = kw.categoryId;
      }
    }

    // Prioridad: MerchantMemory > user > seed
    final sortedMerchants = bestMerchantByCategory.entries.toList()
      ..sort((a, b) {
        final cmpUses = b.value.uses.compareTo(a.value.uses);
        if (cmpUses != 0) return cmpUses;
        return b.value.lastUsedAt.compareTo(a.value.lastUsedAt);
      });

    final result = <String, String>{};

    for (final entry in sortedMerchants) {
      result[entry.key] = entry.value.categoryId;
    }

    for (final entry in userKeywords.entries) {
      if (!result.containsKey(entry.key)) {
        result[entry.key] = entry.value;
      }
    }

    for (final entry in seedKeywords.entries) {
      if (!result.containsKey(entry.key)) {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }
}
