import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:pockt/features/income/domain/pay_split.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/recurring/domain/recurrence.dart';

class SuggestionGenerator {
  final AppDatabase _db;
  final Notifier _notifier;
  final DateTime Function() _clock;
  final SuggestionsRepository _suggestionsRepo;

  SuggestionGenerator(
    this._db,
    this._notifier, {
    DateTime Function()? clock,
    SuggestionsRepository? suggestionsRepository,
  })  : _clock = clock ?? DateTime.now,
        _suggestionsRepo = suggestionsRepository ??
            SuggestionsRepository(_db, clock: clock);

  /// Genera sugerencias pendientes para recurrentes activas y el esquema de cobro vigente.
  /// Devuelve la cantidad de sugerencias nuevas creadas.
  Future<int> run() async {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    var createdCount = 0;

    // 1. Recurrentes activas
    final activeRules = await (_db.select(_db.recurringRules)
          ..where((r) => r.active.equals(true)))
        .get();

    for (final rule in activeRules) {
      final RecurrenceFrequency freq;
      switch (rule.frequency) {
        case 'weekly':
          freq = RecurrenceFrequency.weekly;
          break;
        case 'yearly':
          freq = RecurrenceFrequency.yearly;
          break;
        case 'monthly':
        default:
          freq = RecurrenceFrequency.monthly;
          break;
      }

      final dues = dueOccurrences(
        rule.nextDueDate,
        today,
        frequency: freq,
        dayOfMonth: rule.dayOfMonth,
        dayOfWeek: rule.dayOfWeek,
        monthOfYear: rule.monthOfYear,
      );

      for (final date in dues) {
        final created = await _suggestionsRepo.createIfAbsent(
          type: rule.type,
          amount: rule.amount,
          categoryId: rule.categoryId,
          merchant: rule.name,
          rawText: rule.name,
          occurredAt: date,
          source: TxSource.recurring,
          sourceRef: rule.id,
        );
        if (created) {
          createdCount++;
        }
      }

      if (dues.isNotEmpty) {
        final nextDue = nextOccurrence(
          dues.last,
          frequency: freq,
          dayOfMonth: rule.dayOfMonth,
          dayOfWeek: rule.dayOfWeek,
          monthOfYear: rule.monthOfYear,
        );
        await (_db.update(_db.recurringRules)..where((r) => r.id.equals(rule.id))).write(
          RecurringRulesCompanion(
            nextDueDate: Value(nextDue),
          ),
        );
      }
    }

    // 2. Esquema de cobro vigente
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final currentSchedule = await (_db.select(_db.incomeSchedules)
          ..where((s) => s.effectiveFrom.isSmallerOrEqualValue(todayEnd))
          ..orderBy([(s) => OrderingTerm.desc(s.effectiveFrom)])
          ..limit(1))
        .getSingleOrNull();

    if (currentSchedule != null) {
      final payDaysList = (jsonDecode(currentSchedule.payDays) as List)
          .map((e) => (e as num).toInt())
          .toList();

      final lastSuggested = await (_db.select(_db.suggestedTransactions)
            ..where((t) =>
                t.source.equalsValue(TxSource.incomeSchedule) &
                t.sourceRef.equals(currentSchedule.id))
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
            ..limit(1))
          .getSingleOrNull();

      final DateTime startDate;
      if (lastSuggested != null) {
        final lastDate = DateTime(
          lastSuggested.occurredAt.year,
          lastSuggested.occurredAt.month,
          lastSuggested.occurredAt.day,
        );
        startDate = lastDate.add(const Duration(days: 1));
      } else {
        startDate = DateTime(
          currentSchedule.effectiveFrom.year,
          currentSchedule.effectiveFrom.month,
          currentSchedule.effectiveFrom.day,
        );
      }

      if (!startDate.isAfter(today)) {
        final rules = parsePayDayRules(currentSchedule.payDayRules, payDaysList);
        final splits = parsePaySplitPercents(
          currentSchedule.paySplitPercents,
          count: payDaysList.length,
        );
        final splitAmountsList = currentSchedule.monthlyAmount != null
            ? splitAmounts(currentSchedule.monthlyAmount!, splits)
            : List.filled(payDaysList.length, 0);

        final payDaysToCreate = <({DateTime date, int amount})>[];
        var curYear = startDate.year;
        var curMonth = startDate.month;
        final endYear = today.year;
        final endMonth = today.month;

        while (curYear < endYear || (curYear == endYear && curMonth <= endMonth)) {
          final daysInMonth = DateTime(curYear, curMonth + 1, 0).day;
          for (var i = 0; i < payDaysList.length; i++) {
            final rawDay = payDaysList[i];
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

            final targetDate = DateTime(curYear, curMonth, day);
            final window = resolvePayWindow(targetDate, rule);
            final dayDate = DateTime(
              window.earliest.year,
              window.earliest.month,
              window.earliest.day,
            );
            if (!dayDate.isBefore(startDate) && !dayDate.isAfter(today)) {
              final amount =
                  i < splitAmountsList.length ? splitAmountsList[i] : 0;
              payDaysToCreate.add((date: dayDate, amount: amount));
            }
          }
          curMonth++;
          if (curMonth > 12) {
            curYear++;
            curMonth = 1;
          }
        }

        payDaysToCreate.sort((a, b) => a.date.compareTo(b.date));

        for (final item in payDaysToCreate) {
          final created = await _suggestionsRepo.createIfAbsent(
            type: TxType.income,
            amount: item.amount,
            categoryId: currentSchedule.categoryId,
            merchant: 'Cobro',
            rawText: 'Cobro programado',
            occurredAt: item.date,
            source: TxSource.incomeSchedule,
            sourceRef: currentSchedule.id,
          );
          if (created) {
            createdCount++;
          }
        }
      }
    }

    // 3. Notificación si se creó al menos 1 sugerencia
    if (createdCount >= 1) {
      final body = createdCount == 1
          ? 'Tenés 1 movimiento por confirmar'
          : 'Tenés $createdCount movimientos por confirmar';
      await _notifier.show('Pockt', body, payload: 'inbox');
    }

    return createdCount;
  }
}

final suggestionGeneratorProvider = Provider<SuggestionGenerator>((ref) {
  return SuggestionGenerator(
    ref.watch(databaseProvider),
    ref.watch(notifierProvider),
    suggestionsRepository: ref.watch(suggestionsRepositoryProvider),
  );
});
