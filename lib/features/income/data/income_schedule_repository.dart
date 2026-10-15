import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:pockt/features/income/domain/salary_deduction.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:uuid/uuid.dart';

class IncomeScheduleRepository {
  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  IncomeScheduleRepository(this._db, {DateTime Function()? clock, Uuid? uuid})
    : _clock = clock ?? DateTime.now,
      _uuid = uuid ?? const Uuid();

  /// Saldo arrastrado al período que arranca en [periodStartLocalDay]:
  /// ingresos − gastos − aportes a metas desde el primer esquema de cobro
  /// hasta el día anterior al período (spec §7e). 0 si no hay esquema.
  Future<int> carryOverBefore(DateTime periodStartLocalDay) async {
    final first =
        await (_db.selectOnly(_db.incomeSchedules)
              ..addColumns([_db.incomeSchedules.effectiveFrom.min()]))
            .map((r) => r.read(_db.incomeSchedules.effectiveFrom.min()))
            .getSingle();
    if (first == null) return 0;
    final fromDay = DateTime(first.year, first.month, first.day);
    final toDay = DateTime(
      periodStartLocalDay.year,
      periodStartLocalDay.month,
      periodStartLocalDay.day,
    );
    if (!fromDay.isBefore(toDay)) return 0;

    final fromUtc = dayRangeUtc(fromDay).startUtc;
    final toUtc = dayRangeUtc(toDay).startUtc;
    final txs =
        await (_db.select(_db.transactions)..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.occurredAt.isBiggerOrEqualValue(fromUtc) &
                  t.occurredAt.isSmallerThanValue(toUtc),
            ))
            .get();
    final contribs =
        await (_db.select(_db.goalContributions)..where(
              (c) =>
                  c.date.isBiggerOrEqualValue(fromDay) &
                  c.date.isSmallerThanValue(toDay),
            ))
            .get();

    var net = 0;
    for (final t in txs) {
      net += t.type == TxType.income ? t.amount : -t.amount;
    }
    for (final c in contribs) {
      net -= c.amount;
    }
    return net;
  }

  /// Versión reactiva de [carryOverBefore].
  Stream<int> watchCarryOverBefore(DateTime periodStartLocalDay) {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.transactions,
            _db.goalContributions,
            _db.incomeSchedules,
          },
        )
        .watch()
        .asyncMap((_) => carryOverBefore(periodStartLocalDay));
  }

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

  /// Emite las deducciones asociadas a un esquema de cobro.
  Stream<List<SalaryDeduction>> watchDeductionsFor(String scheduleId) {
    final query = _db.select(_db.salaryDeductions)
      ..where((t) => t.scheduleId.equals(scheduleId));
    return query.watch();
  }

  /// Obtiene las deducciones asociadas a un esquema de cobro.
  Future<List<SalaryDeduction>> getDeductionsFor(String scheduleId) {
    final query = _db.select(_db.salaryDeductions)
      ..where((t) => t.scheduleId.equals(scheduleId));
    return query.get();
  }

  /// Guarda el esquema de cobro con `effectiveFrom` = hoy local.
  /// Si ya hay uno vigente desde hoy, lo reemplaza (guardar varias veces el
  /// mismo día no deja filas empatadas); los esquemas de días anteriores no se
  /// tocan, así la historia sigue intacta.
  ///
  /// Si no había ningún esquema previo en la base de datos, crea una sugerencia
  /// para el cobro más reciente ya pasado (`previousPayWindow(hoy)`) con su
  /// monto del reparto (neto si hay descuentos), de forma idempotente.
  Future<void> setSchedule({
    required PayMode mode,
    required List<int> payDays,
    List<PayDayRule>? payDayRules,
    @Deprecated('Usar payDayRules') bool? shiftToPreviousBusinessDay,
    int? monthlyAmount,
    @Deprecated('Usar monthlyAmount') int? expectedAmount,
    List<int>? paySplitPercents,
    required String categoryId,
    List<SalaryDeductionItem>? deductions,
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

      final existingForToday = await (_db.select(_db.incomeSchedules)
            ..where((t) => t.effectiveFrom.equals(today)))
          .get();
      for (final s in existingForToday) {
        await (_db.delete(_db.salaryDeductions)
              ..where((t) => t.scheduleId.equals(s.id)))
            .go();
      }

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

      if (deductions != null && deductions.isNotEmpty) {
        for (final d in deductions) {
          final dedId = _uuid.v4();
          await _db.into(_db.salaryDeductions).insert(
            SalaryDeductionsCompanion.insert(
              id: dedId,
              scheduleId: newScheduleId,
              name: d.name,
              kind: d.kind,
              value: d.value,
            ),
          );
        }
      }

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
            final netList = safeNetPayAmounts(
              actualMonthlyAmount,
              splits,
              deductions ?? const [],
            );
            amount = matchIndex < netList.length ? netList[matchIndex] : 0;
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

