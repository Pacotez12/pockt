import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';

/// Repositorio para la tabla `day_marks` que gestiona marcas por día (ej. "Hoy no gasté nada").
class DayMarksRepository {
  final AppDatabase db;

  DayMarksRepository(this.db);

  String _formatDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Marca [localDay] como día sin gastos ("Hoy no gasté nada").
  Future<void> markNoSpend(DateTime localDay) async {
    final key = _formatDay(localDay);
    await db.into(db.dayMarks).insertOnConflictUpdate(
          DayMarksCompanion(
            date: Value(key),
            noSpend: const Value(true),
          ),
        );
  }

  /// Devuelve el conjunto de fechas locales que tienen la marca `noSpend = true`
  /// en el rango [[fromLocal], [toLocal]].
  Future<Set<DateTime>> noSpendDays(
    DateTime fromLocal,
    DateTime toLocal,
  ) async {
    final fromStr = _formatDay(fromLocal);
    final toStr = _formatDay(toLocal);

    final query = db.select(db.dayMarks)
      ..where((t) =>
          t.noSpend.equals(true) &
          t.date.isBiggerOrEqualValue(fromStr) &
          t.date.isSmallerOrEqualValue(toStr));

    final rows = await query.get();
    return rows.map((r) => DateTime.parse(r.date)).toSet();
  }
}

final dayMarksRepositoryProvider = Provider<DayMarksRepository>((ref) {
  return DayMarksRepository(ref.watch(databaseProvider));
});
