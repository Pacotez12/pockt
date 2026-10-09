import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/reminders/data/day_marks_repository.dart';
import 'package:pockt/features/reminders/domain/reminder_plan.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

/// Servicio encargado de aplicar y reprogramar el plan de recordatorios
/// usando [Notifier], [TransactionsRepository], [DayMarksRepository] y [SettingsRepository].
class ReminderScheduler {
  final Notifier notifier;
  final TransactionsRepository txRepo;
  final DayMarksRepository marksRepo;
  final SettingsRepository settingsRepo;

  ReminderScheduler(
    this.notifier,
    this.txRepo,
    this.marksRepo,
    this.settingsRepo,
  );

  /// Reprograma todos los recordatorios para los próximos 7 días según
  /// la configuración actual, los gastos existentes y los días sin gasto.
  Future<void> reschedule({required DateTime nowLocal}) async {
    // 1. Leer intensidad
    final intensityStr = await settingsRepo.get(
      SettingsKeys.remindersIntensity,
    );
    final intensity = switch (intensityStr) {
      'off' => ReminderIntensity.off,
      'soft' => ReminderIntensity.soft,
      'normal' => ReminderIntensity.normal,
      'insistent' => ReminderIntensity.insistent,
      _ => ReminderIntensity.normal,
    };

    // 2. Leer horas de silencio
    final quietStartStr =
        await settingsRepo.get(SettingsKeys.remindersQuietStart) ?? '23:00';
    final quietEndStr =
        await settingsRepo.get(SettingsKeys.remindersQuietEnd) ?? '09:00';

    final quietStart = _parseTime(quietStartStr, fallbackH: 23, fallbackM: 0);
    final quietEnd = _parseTime(quietEndStr, fallbackH: 9, fallbackM: 0);

    // 3. Consultar gastos y marcas
    final toLocal = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day + 7,
      23,
      59,
      59,
    );

    final expenseDays = await txRepo.daysWithExpense(nowLocal, toLocal);
    final noSpendDays = await marksRepo.noSpendDays(nowLocal, toLocal);

    // 4. Cancelar todos los recordatorios previos
    await notifier.cancelAllReminders();

    // Si está apagado, terminar aquí
    if (intensity == ReminderIntensity.off) {
      return;
    }

    // 5. Planificar
    final plan = planReminders(
      nowLocal: nowLocal,
      intensity: intensity,
      daysWithExpense: expenseDays,
      noSpendDays: noSpendDays,
      quietStart: quietStart,
      quietEnd: quietEnd,
      days: 7,
    );

    // 6. Programar cada recordatorio
    for (final reminder in plan) {
      await notifier.schedule(reminder);
    }
  }

  ({int h, int m}) _parseTime(
    String timeStr, {
    required int fallbackH,
    required int fallbackM,
  }) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return (h: int.parse(parts[0].trim()), m: int.parse(parts[1].trim()));
      }
    } catch (_) {}
    return (h: fallbackH, m: fallbackM);
  }
}

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return ReminderScheduler(
    ref.watch(notifierProvider),
    ref.watch(transactionsRepositoryProvider),
    ref.watch(dayMarksRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
  );
});
