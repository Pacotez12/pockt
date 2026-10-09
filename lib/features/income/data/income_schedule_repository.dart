import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:uuid/uuid.dart';

class IncomeScheduleRepository {
  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  IncomeScheduleRepository(
    this._db, {
    DateTime Function()? clock,
    Uuid? uuid,
  })  : _clock = clock ?? DateTime.now,
        _uuid = uuid ?? const Uuid();

  DateTime _todayLocal() {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// Emite el esquema de cobro vigente (el de `effectiveFrom` más reciente <= hoy).
  Stream<IncomeSchedule?> watchCurrent() {
    final today = _todayLocal();
    final query = _db.select(_db.incomeSchedules)
      ..where((t) => t.effectiveFrom.isSmallerOrEqualValue(today))
      ..orderBy([
        (t) => OrderingTerm.desc(t.effectiveFrom),
      ])
      ..limit(1);

    return query.watchSingleOrNull();
  }

  /// Guarda un nuevo esquema de cobro con `effectiveFrom` = hoy local.
  /// Nunca edita los esquemas anteriores.
  Future<void> setSchedule({
    required PayMode mode,
    required List<int> payDays,
    List<PayDayRule>? payDayRules,
    @Deprecated('Usar payDayRules') bool? shiftToPreviousBusinessDay,
    int? expectedAmount,
    required String categoryId,
  }) async {
    final today = _todayLocal();
    final rules = payDayRules ??
        payDays.map((d) {
          if (shiftToPreviousBusinessDay == false) return PayDayRule.either;
          return d == -1 ? PayDayRule.previous : PayDayRule.either;
        }).toList();

    await _db.into(_db.incomeSchedules).insert(
          IncomeSchedulesCompanion.insert(
            id: _uuid.v4(),
            mode: mode.name,
            payDays: jsonEncode(payDays),
            payDayRules: jsonEncode(rules.map((r) => r.name).toList()),
            expectedAmount: Value(expectedAmount),
            categoryId: categoryId,
            effectiveFrom: today,
          ),
        );
  }
}
