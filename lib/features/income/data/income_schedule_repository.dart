import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:uuid/uuid.dart';

class IncomeScheduleRepository {
  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  IncomeScheduleRepository(this._db, {DateTime Function()? clock, Uuid? uuid})
    : _clock = clock ?? DateTime.now,
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
      ..orderBy([(t) => OrderingTerm.desc(t.effectiveFrom)])
      ..limit(1);

    return query.watchSingleOrNull();
  }

  /// Guarda el esquema de cobro con `effectiveFrom` = hoy local.
  /// Si ya hay uno vigente desde hoy, lo reemplaza (guardar varias veces el
  /// mismo día no deja filas empatadas); los esquemas de días anteriores no se
  /// tocan, así la historia sigue intacta.
  Future<void> setSchedule({
    required PayMode mode,
    required List<int> payDays,
    List<PayDayRule>? payDayRules,
    @Deprecated('Usar payDayRules') bool? shiftToPreviousBusinessDay,
    int? monthlyAmount,
    @Deprecated('Usar monthlyAmount') int? expectedAmount,
    List<int>? paySplitPercents,
    required String categoryId,
  }) async {
    final today = _todayLocal();
    final rules =
        payDayRules ??
        payDays.map((d) {
          if (shiftToPreviousBusinessDay == false) return PayDayRule.either;
          return d == -1 ? PayDayRule.previous : PayDayRule.either;
        }).toList();

    final actualMonthlyAmount =
        monthlyAmount ??
        (expectedAmount != null ? expectedAmount * payDays.length : null);

    final splits =
        paySplitPercents ??
        (payDays.length == 2
            ? const [50, 50]
            : (payDays.length == 1
                  ? const [100]
                  : List.filled(payDays.length, 100 ~/ payDays.length)));

    await _db.transaction(() async {
      await (_db.delete(
        _db.incomeSchedules,
      )..where((t) => t.effectiveFrom.equals(today))).go();
      await _db
          .into(_db.incomeSchedules)
          .insert(
            IncomeSchedulesCompanion.insert(
              id: _uuid.v4(),
              mode: mode.name,
              payDays: jsonEncode(payDays),
              payDayRules: jsonEncode(rules.map((r) => r.name).toList()),
              monthlyAmount: Value(actualMonthlyAmount),
              paySplitPercents: jsonEncode(splits),
              categoryId: categoryId,
              effectiveFrom: today,
            ),
          );
    });
  }
}
