import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
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
        final payDaysToCreate = <DateTime>[];
        var curYear = startDate.year;
        var curMonth = startDate.month;
        final endYear = today.year;
        final endMonth = today.month;

        while (curYear < endYear || (curYear == endYear && curMonth <= endMonth)) {
          final daysInM = payDaysInMonth(
            curYear,
            curMonth,
            payDaysList,
            shiftToPreviousBusinessDay:
                currentSchedule.shiftToPreviousBusinessDay,
          );
          for (final d in daysInM) {
            final dayDate = DateTime(d.year, d.month, d.day);
            if (!dayDate.isBefore(startDate) && !dayDate.isAfter(today)) {
              payDaysToCreate.add(dayDate);
            }
          }
          curMonth++;
          if (curMonth > 12) {
            curYear++;
            curMonth = 1;
          }
        }

        payDaysToCreate.sort();

        for (final dayDate in payDaysToCreate) {
          final created = await _suggestionsRepo.createIfAbsent(
            type: TxType.income,
            amount: currentSchedule.expectedAmount ?? 0,
            categoryId: currentSchedule.categoryId,
            merchant: 'Cobro',
            rawText: 'Cobro programado',
            occurredAt: dayDate,
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
