import 'package:drift/drift.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/features/recurring/domain/recurrence.dart';
import 'package:uuid/uuid.dart';

class RecurringRepository {
  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;
  final Notifier? notifier;

  RecurringRepository(
    this._db, {
    DateTime Function()? clock,
    Uuid? uuid,
    this.notifier,
  })  : _clock = clock ?? DateTime.now,
        _uuid = uuid ?? const Uuid();

  DateTime _todayLocal() {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// Emite todas las reglas recurrentes ordenadas por fecha de próximo vencimiento.
  Stream<List<RecurringRule>> watchAll() {
    return (_db.select(_db.recurringRules)
          ..orderBy([
            (t) => OrderingTerm.asc(t.nextDueDate),
          ]))
        .watch();
  }

  /// Agrega una nueva regla recurrente.
  /// Calcula `nextDueDate` con `nextOccurrence` desde ayer (si hoy coincide, hoy es la primera).
  Future<String> add({
    required String name,
    required TxType type,
    required int amount,
    required String categoryId,
    required RecurrenceFrequency frequency,
    int? dayOfMonth,
    int? dayOfWeek,
    int? monthOfYear,
  }) async {
    final notif = notifier;
    if (notif != null) {
      final countResult = await (_db.selectOnly(_db.recurringRules)
            ..addColumns([_db.recurringRules.id.count()]))
          .getSingle();
      final total = countResult.read(_db.recurringRules.id.count()) ?? 0;
      if (total == 0) {
        await notif.ensurePermission();
      }
    }

    final id = _uuid.v4();
    final today = _todayLocal();
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    final nextDue = nextOccurrence(
      yesterday,
      frequency: frequency,
      dayOfMonth: dayOfMonth,
      dayOfWeek: dayOfWeek,
      monthOfYear: monthOfYear,
    );

    await _db.into(_db.recurringRules).insert(
          RecurringRulesCompanion.insert(
            id: id,
            name: name,
            type: type,
            amount: amount,
            categoryId: categoryId,
            frequency: frequency.name,
            dayOfMonth: Value(dayOfMonth),
            dayOfWeek: Value(dayOfWeek),
            monthOfYear: Value(monthOfYear),
            nextDueDate: nextDue,
            active: const Value(true),
          ),
        );

    return id;
  }

  /// Actualiza los campos de una regla existente.
  Future<void> update(
    String id, {
    String? name,
    TxType? type,
    int? amount,
    String? categoryId,
    RecurrenceFrequency? frequency,
    int? dayOfMonth,
    int? dayOfWeek,
    int? monthOfYear,
    DateTime? nextDueDate,
    bool? active,
  }) async {
    final scheduleChanged = frequency != null ||
        dayOfMonth != null ||
        dayOfWeek != null ||
        monthOfYear != null;
    if (nextDueDate == null && scheduleChanged) {
      // Recalcula dentro del mismo período de la próxima fecha actual, sin
      // volver a uno ya confirmado ni ir antes de hoy.
      final rule = await (_db.select(_db.recurringRules)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      final freq = frequency ??
          RecurrenceFrequency.values.firstWhere(
            (f) => f.name == rule.frequency,
            orElse: () => RecurrenceFrequency.monthly,
          );
      final old = rule.nextDueDate;
      final periodBase = switch (freq) {
        RecurrenceFrequency.monthly => DateTime(old.year, old.month, 0),
        RecurrenceFrequency.weekly => DateTime(old.year, old.month, old.day - 7),
        RecurrenceFrequency.yearly => DateTime(old.year, 1, 0),
      };
      final today = _todayLocal();
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      nextDueDate = nextOccurrence(
        periodBase.isAfter(yesterday) ? periodBase : yesterday,
        frequency: freq,
        dayOfMonth: dayOfMonth ?? rule.dayOfMonth,
        dayOfWeek: dayOfWeek ?? rule.dayOfWeek,
        monthOfYear: monthOfYear ?? rule.monthOfYear,
      );
    }
    await (_db.update(_db.recurringRules)..where((t) => t.id.equals(id))).write(
      RecurringRulesCompanion(
        name: Value.absentIfNull(name),
        type: Value.absentIfNull(type),
        amount: Value.absentIfNull(amount),
        categoryId: Value.absentIfNull(categoryId),
        frequency: frequency != null ? Value(frequency.name) : const Value.absent(),
        dayOfMonth: Value.absentIfNull(dayOfMonth),
        dayOfWeek: Value.absentIfNull(dayOfWeek),
        monthOfYear: Value.absentIfNull(monthOfYear),
        nextDueDate: Value.absentIfNull(nextDueDate),
        active: Value.absentIfNull(active),
      ),
    );
  }

  /// Pausa o activa una regla recurrente.
  Future<void> setActive(String id, bool active) async {
    await (_db.update(_db.recurringRules)..where((t) => t.id.equals(id))).write(
      RecurringRulesCompanion(
        active: Value(active),
      ),
    );
  }

  /// Elimina una regla recurrente.
  Future<void> delete(String id) async {
    await (_db.delete(_db.recurringRules)..where((t) => t.id.equals(id))).go();
  }
}
