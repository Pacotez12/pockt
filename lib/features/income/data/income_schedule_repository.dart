import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:pockt/features/income/domain/pay_split.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
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
  ///
  /// Si no había ningún esquema previo en la base de datos, crea una sugerencia
  /// para el cobro más reciente ya pasado (`previousPayWindow(hoy)`) con su
  /// monto del reparto, de forma idempotente.
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
      final hadNoPreviousSchedule =
          (await (_db.select(_db.incomeSchedules)..limit(1)).get()).isEmpty;

      await (_db.delete(
        _db.incomeSchedules,
      )..where((t) => t.effectiveFrom.equals(today))).go();

      final newScheduleId = _uuid.v4();
      await _db
          .into(_db.incomeSchedules)
          .insert(
            IncomeSchedulesCompanion.insert(
              id: newScheduleId,
              mode: mode.name,
              payDays: jsonEncode(payDays),
              payDayRules: jsonEncode(rules.map((r) => r.name).toList()),
              monthlyAmount: Value(actualMonthlyAmount),
              paySplitPercents: jsonEncode(splits),
              categoryId: categoryId,
              effectiveFrom: today,
            ),
          );

      if (hadNoPreviousSchedule) {
        final prevWindow = previousPayWindow(today, payDays, rules);
        if (prevWindow != null) {
          final year = prevWindow.earliest.year;
          final month = prevWindow.earliest.month;
          final daysInMonth = DateTime(year, month + 1, 0).day;
          int? matchIndex;
          for (var i = 0; i < payDays.length; i++) {
            final rawDay = payDays[i];
            final rule = (i < rules.length)
                ? rules[i]
                : (rawDay == -1 ? PayDayRule.previous : PayDayRule.either);
            final int day;
            if (rawDay == -1 || rawDay > daysInMonth) {
              day = daysInMonth;
            } else if (rawDay <= 0) {
              day = 1;
            } else {
              day = rawDay;
            }
            final targetDate = DateTime(year, month, day);
            final w = resolvePayWindow(targetDate, rule);
            if (w.earliest == prevWindow.earliest &&
                w.latest == prevWindow.latest) {
              matchIndex = i;
              break;
            }
          }

          final int amount;
          if (actualMonthlyAmount != null && matchIndex != null) {
            final splitList = splitAmounts(actualMonthlyAmount, splits);
            amount = matchIndex < splitList.length ? splitList[matchIndex] : 0;
          } else {
            amount = 0;
          }

          final alreadyExists = await (_db.select(_db.suggestedTransactions)
                ..where((t) =>
                    t.source.equalsValue(TxSource.incomeSchedule) &
                    t.occurredAt.equals(prevWindow.earliest)))
              .get();

          if (alreadyExists.isEmpty) {
            final suggestionsRepo =
                SuggestionsRepository(_db, clock: _clock, uuid: _uuid);
            await suggestionsRepo.createIfAbsent(
              type: TxType.income,
              amount: amount,
              categoryId: categoryId,
              merchant: 'Cobro',
              rawText: 'Cobro programado',
              occurredAt: prevWindow.earliest,
              source: TxSource.incomeSchedule,
              sourceRef: newScheduleId,
            );
          }
        }
      }
    });
  }
}

