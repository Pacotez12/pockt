import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/entry/domain/entry_shortcut.dart';
import 'package:pockt/features/entry/domain/natural_parser.dart';
import 'package:uuid/uuid.dart';

class EntryShortcutsRepository {
  final AppDatabase db;

  EntryShortcutsRepository(this.db);

  String _shortcutKey({
    String? merchant,
    String? note,
    required int amount,
    required String categoryId,
  }) {
    final rawLabel = (merchant != null && merchant.trim().isNotEmpty)
        ? merchant.trim()
        : (note != null && note.trim().isNotEmpty)
        ? note.trim()
        : '';
    return '${normalizeKeyword(rawLabel)}_${amount}_$categoryId';
  }

  /// Emite la lista reactiva de atajos rápidos (máximo [limit], por defecto 6).
  Stream<List<EntryShortcutItem>> watchShortcuts({
    DateTime? now,
    int limit = 6,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final cutoff = effectiveNow.subtract(const Duration(days: 60)).toUtc();

    // Consultamos la tabla entry_shortcuts y transactions recientes
    final shortcutsQuery = db.select(db.entryShortcuts).join([
      innerJoin(
        db.categories,
        db.categories.id.equalsExp(db.entryShortcuts.categoryId),
      ),
    ]);

    final txQuery =
        db.select(db.transactions).join([
            innerJoin(
              db.categories,
              db.categories.id.equalsExp(db.transactions.categoryId),
            ),
          ])
          ..where(
            db.transactions.deletedAt.isNull() &
                db.transactions.type.equalsValue(TxType.expense) &
                db.transactions.occurredAt.isBiggerOrEqualValue(cutoff),
          )
          ..orderBy([OrderingTerm.desc(db.transactions.occurredAt)]);

    // Combina ambos streams mediante watch
    return shortcutsQuery.watch().asyncMap((scRows) async {
      final txRows = await txQuery.get();
      return _buildShortcuts(scRows, txRows, limit: limit);
    });
  }

  /// Obtiene puntualmente los atajos rápidos.
  Future<List<EntryShortcutItem>> getShortcuts({
    DateTime? now,
    int limit = 6,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final cutoff = effectiveNow.subtract(const Duration(days: 60)).toUtc();

    final scRows = await (db.select(db.entryShortcuts).join([
      innerJoin(
        db.categories,
        db.categories.id.equalsExp(db.entryShortcuts.categoryId),
      ),
    ])).get();

    final txRows =
        await (db.select(db.transactions).join([
                innerJoin(
                  db.categories,
                  db.categories.id.equalsExp(db.transactions.categoryId),
                ),
              ])
              ..where(
                db.transactions.deletedAt.isNull() &
                    db.transactions.type.equalsValue(TxType.expense) &
                    db.transactions.occurredAt.isBiggerOrEqualValue(cutoff),
              )
              ..orderBy([OrderingTerm.desc(db.transactions.occurredAt)]))
            .get();

    return _buildShortcuts(scRows, txRows, limit: limit);
  }

  List<EntryShortcutItem> _buildShortcuts(
    List<TypedResult> scRows,
    List<TypedResult> txRows, {
    required int limit,
  }) {
    final pinned = <EntryShortcutItem>[];
    final dismissedKeys = <String>{};
    final pinnedKeys = <String>{};

    for (final row in scRows) {
      final sc = row.readTable(db.entryShortcuts);
      final cat = row.readTable(db.categories);
      final key = _shortcutKey(
        merchant: sc.merchant,
        note: sc.note,
        amount: sc.amount,
        categoryId: sc.categoryId,
      );

      if (sc.isDismissed) {
        dismissedKeys.add(key);
      } else if (sc.isPinned) {
        pinnedKeys.add(key);
        pinned.add(
          EntryShortcutItem(
            id: sc.id,
            merchant: sc.merchant,
            note: sc.note,
            amount: sc.amount,
            categoryId: sc.categoryId,
            categoryName: cat.name,
            categoryIcon: cat.icon,
            colorDark: cat.colorDark,
            colorLight: cat.colorLight,
            isPinned: true,
          ),
        );
      }
    }

    // Agrupar repeticiones en transacciones de los últimos 60 días
    final Map<String, _CandidateGroup> candidateMap = {};

    for (final row in txRows) {
      final tx = row.readTable(db.transactions);
      final cat = row.readTable(db.categories);

      final rawMerchant = tx.merchant?.trim();
      final rawNote = tx.note?.trim();

      // Debe tener al menos comercio o nota para calificar como atajo reconocible
      if ((rawMerchant == null || rawMerchant.isEmpty) &&
          (rawNote == null || rawNote.isEmpty)) {
        continue;
      }

      final key = _shortcutKey(
        merchant: rawMerchant,
        note: rawNote,
        amount: tx.amount,
        categoryId: tx.categoryId,
      );

      if (dismissedKeys.contains(key) || pinnedKeys.contains(key)) {
        continue;
      }

      final group = candidateMap.putIfAbsent(
        key,
        () => _CandidateGroup(
          merchant: rawMerchant,
          note: rawNote,
          amount: tx.amount,
          categoryId: cat.id,
          categoryName: cat.name,
          categoryIcon: cat.icon,
          colorDark: cat.colorDark,
          colorLight: cat.colorLight,
        ),
      );
      group.count++;
      if (rawMerchant != null && rawMerchant.isNotEmpty) {
        group.merchantSpellings[rawMerchant] =
            (group.merchantSpellings[rawMerchant] ?? 0) + 1;
      }
    }

    // Solo candidatos con count >= 3
    final suggestions = candidateMap.values.where((c) => c.count >= 3).map((c) {
      String? bestMerchant = c.merchant;
      if (c.merchantSpellings.isNotEmpty) {
        bestMerchant = c.merchantSpellings.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
      }
      return EntryShortcutItem(
        id: 'sug_${c.categoryId}_${c.amount}_${bestMerchant ?? c.note}',
        merchant: bestMerchant,
        note: c.note,
        amount: c.amount,
        categoryId: c.categoryId,
        categoryName: c.categoryName,
        categoryIcon: c.categoryIcon,
        colorDark: c.colorDark,
        colorLight: c.colorLight,
        isPinned: false,
        count: c.count,
      );
    }).toList();

    // Ordenar sugerencias por mayor frecuencia
    suggestions.sort((a, b) => b.count.compareTo(a.count));

    final result = [...pinned, ...suggestions];
    if (result.length > limit) {
      return result.sublist(0, limit);
    }
    return result;
  }

  /// Fija un atajo en la tabla `entry_shortcuts`.
  Future<void> pinShortcut(EntryShortcutItem item) async {
    final existing =
        await (db.select(db.entryShortcuts)..where(
              (s) =>
                  s.categoryId.equals(item.categoryId) &
                  s.amount.equals(item.amount) &
                  (item.merchant != null
                      ? s.merchant.equals(item.merchant!)
                      : s.merchant.isNull()) &
                  (item.note != null
                      ? s.note.equals(item.note!)
                      : s.note.isNull()),
            ))
            .getSingleOrNull();

    final now = DateTime.now();
    if (existing != null) {
      await (db.update(
        db.entryShortcuts,
      )..where((s) => s.id.equals(existing.id))).write(
        EntryShortcutsCompanion(
          isPinned: const Value(true),
          isDismissed: const Value(false),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db
          .into(db.entryShortcuts)
          .insert(
            EntryShortcutsCompanion.insert(
              id: const Uuid().v4(),
              merchant: Value(item.merchant),
              note: Value(item.note),
              amount: item.amount,
              categoryId: item.categoryId,
              isPinned: const Value(true),
              isDismissed: const Value(false),
              createdAt: now,
            ),
          );
    }
  }

  /// Desfija un atajo fijado.
  Future<void> unpinShortcut(String id) async {
    await (db.update(db.entryShortcuts)..where((s) => s.id.equals(id))).write(
      EntryShortcutsCompanion(
        isPinned: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Quita un atajo (no se vuelve a sugerir).
  Future<void> dismissShortcut(EntryShortcutItem item) async {
    final existing =
        await (db.select(db.entryShortcuts)..where(
              (s) =>
                  s.categoryId.equals(item.categoryId) &
                  s.amount.equals(item.amount) &
                  (item.merchant != null
                      ? s.merchant.equals(item.merchant!)
                      : s.merchant.isNull()) &
                  (item.note != null
                      ? s.note.equals(item.note!)
                      : s.note.isNull()),
            ))
            .getSingleOrNull();

    final now = DateTime.now();
    if (existing != null) {
      await (db.update(
        db.entryShortcuts,
      )..where((s) => s.id.equals(existing.id))).write(
        EntryShortcutsCompanion(
          isDismissed: const Value(true),
          isPinned: const Value(false),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db
          .into(db.entryShortcuts)
          .insert(
            EntryShortcutsCompanion.insert(
              id: const Uuid().v4(),
              merchant: Value(item.merchant),
              note: Value(item.note),
              amount: item.amount,
              categoryId: item.categoryId,
              isPinned: const Value(false),
              isDismissed: const Value(true),
              createdAt: now,
            ),
          );
    }
  }
}

class _CandidateGroup {
  final String? merchant;
  final String? note;
  final int amount;
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final int colorDark;
  final int colorLight;
  int count = 0;
  final Map<String, int> merchantSpellings = {};

  _CandidateGroup({
    this.merchant,
    this.note,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.colorDark,
    required this.colorLight,
  });
}

final entryShortcutsRepositoryProvider = Provider<EntryShortcutsRepository>((
  ref,
) {
  return EntryShortcutsRepository(ref.watch(databaseProvider));
});

final entryShortcutsProvider = StreamProvider<List<EntryShortcutItem>>((ref) {
  final repo = ref.watch(entryShortcutsRepositoryProvider);
  return repo.watchShortcuts();
});
