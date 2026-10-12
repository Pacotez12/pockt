import 'dart:math';
import 'package:drift/drift.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/loans/domain/loan_progress.dart';
import 'package:pockt/features/reminders/domain/reminder_plan.dart';

/// Helper para verificar si un horario cae en las horas de silencio.
bool _isInQuietHours(
  int h,
  int m,
  ({int h, int m}) quietStart,
  ({int h, int m}) quietEnd,
) {
  final timeVal = h * 60 + m;
  final startVal = quietStart.h * 60 + quietStart.m;
  final endVal = quietEnd.h * 60 + quietEnd.m;

  if (startVal == endVal) return false;

  if (startVal < endVal) {
    return timeVal >= startVal && timeVal < endVal;
  } else {
    return timeVal >= startVal || timeVal < endVal;
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

/// Genera el ID numérico de notificación para un préstamo.
int loanNotificationId(String loanId) {
  return 7000000 + (loanId.hashCode.abs() % 900000);
}

/// Planifica el recordatorio de vencimiento para un préstamo según la especificación §7c.
///
/// Retorna `null` si:
/// - El préstamo está cerrado (`closedAt != null`) o su saldo es 0.
/// - No tiene `dueDay` o `reminderDays <= 0`.
/// - Ya se realizó el pago regular de la cuota del mes correspondiente.
PlannedReminder? planLoanReminder({
  required Loan loan,
  required List<Transaction> payments,
  required DateTime nowLocal,
  ({int h, int m}) quietStart = (h: 23, m: 0),
  ({int h, int m}) quietEnd = (h: 9, m: 0),
}) {
  if (loan.closedAt != null) return null;
  if (loan.dueDay == null) return null;
  if (loan.reminderDays <= 0) return null;

  final progress = calculateLoanProgress(
    loan: loan,
    payments: payments,
    now: nowLocal,
  );
  if (progress.isClosed || progress.balance <= 0) return null;

  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

  // Calcular fecha de vencimiento del mes actual
  final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
  final effectiveDueDay = min(loan.dueDay!, daysInMonth);
  final currentMonthDue = DateTime(today.year, today.month, effectiveDueDay);

  // Determinar si ya se pagó la cuota de este mes
  final validPayments = payments.where((p) => p.deletedAt == null && !isLoanExtraPayment(p));
  final paymentsThisMonth = validPayments.where((p) {
    final isCorrectType = loan.direction == LoanDirection.owe
        ? p.type == TxType.expense
        : p.type == TxType.income;
    return isCorrectType &&
        p.occurredAt.year == today.year &&
        p.occurredAt.month == today.month;
  });

  if (paymentsThisMonth.isNotEmpty) {
    // La cuota del mes ya está pagada: no se envía aviso para este mes
    return null;
  }

  // La fecha de aviso es N días antes del vencimiento
  final reminderDate = currentMonthDue.subtract(Duration(days: loan.reminderDays));

  // Hora por defecto: 09:00
  var targetH = 9;
  var targetM = 0;
  if (_isInQuietHours(targetH, targetM, quietStart, quietEnd)) {
    targetH = quietEnd.h;
    targetM = quietEnd.m;
  }

  final scheduledAt = DateTime(
    reminderDate.year,
    reminderDate.month,
    reminderDate.day,
    targetH,
    targetM,
  );

  final installment = loan.installmentAmount ?? progress.balance;
  final amountFormatted = formatGs(installment);

  final title = 'Vence cuota: ${loan.name}';
  final body = '${loan.name}: cuota de $amountFormatted vence en ${loan.reminderDays} días (día ${loan.dueDay}).';

  return PlannedReminder(
    atLocal: scheduledAt,
    notificationId: loanNotificationId(loan.id),
    title: title,
    body: body,
  );
}

/// Reprograma los avisos de préstamos en segundo plano o al actualizar la app.
Future<void> rescheduleLoanReminders({
  required AppDatabase db,
  required Notifier notifier,
  SettingsRepository? settingsRepo,
  required DateTime nowLocal,
}) async {
  final activeLoans = await (db.select(db.loans)..where((l) => l.closedAt.isNull())).get();

  final quietStartStr = await settingsRepo?.get(SettingsKeys.remindersQuietStart) ?? '23:00';
  final quietEndStr = await settingsRepo?.get(SettingsKeys.remindersQuietEnd) ?? '09:00';
  final quietStart = _parseTime(quietStartStr, fallbackH: 23, fallbackM: 0);
  final quietEnd = _parseTime(quietEndStr, fallbackH: 9, fallbackM: 0);

  for (final loan in activeLoans) {
    final notifId = loanNotificationId(loan.id);
    await notifier.cancel(notifId);

    final payments = await (db.select(db.transactions)
          ..where((t) => t.loanId.equals(loan.id) & t.deletedAt.isNull()))
        .get();

    final reminder = planLoanReminder(
      loan: loan,
      payments: payments,
      nowLocal: nowLocal,
      quietStart: quietStart,
      quietEnd: quietEnd,
    );

    if (reminder != null && !reminder.atLocal.isBefore(nowLocal)) {
      await notifier.schedule(reminder);
    }
  }
}
