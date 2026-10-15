import 'package:drift/drift.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/reminders/domain/reminder_plan.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

const int kWeeklySummaryNotificationId = 8888888;

/// Datos del resumen semanal consolidado.
class WeeklySummaryData {
  final int currentWeekTotal;
  final int previousWeekTotal;
  final int? percentageDiff;
  final String? topCategoryName;
  final int topCategoryAmount;
  final DateTime weekStart;
  final DateTime weekEnd;

  const WeeklySummaryData({
    required this.currentWeekTotal,
    required this.previousWeekTotal,
    this.percentageDiff,
    this.topCategoryName,
    this.topCategoryAmount = 0,
    required this.weekStart,
    required this.weekEnd,
  });
}

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

/// Calcula el próximo domingo a las 19:00 (o ajustado si 19:00 cae en horas de silencio).
DateTime nextSundayAt19(
  DateTime nowLocal, {
  ({int h, int m}) quietStart = (h: 23, m: 0),
  ({int h, int m}) quietEnd = (h: 9, m: 0),
}) {
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final daysUntilSunday = (DateTime.sunday - nowLocal.weekday) % 7;
  var targetDate = today.add(Duration(days: daysUntilSunday));

  var targetH = 19;
  var targetM = 0;
  if (_isInQuietHours(targetH, targetM, quietStart, quietEnd)) {
    targetH = quietEnd.h;
    targetM = quietEnd.m;
  }

  var scheduledAt = DateTime(
    targetDate.year,
    targetDate.month,
    targetDate.day,
    targetH,
    targetM,
  );

  // Si es hoy domingo pero la hora objetivo ya pasó, programar para el próximo domingo
  if (!scheduledAt.isAfter(nowLocal)) {
    targetDate = targetDate.add(const Duration(days: 7));
    scheduledAt = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      targetH,
      targetM,
    );
  }

  return scheduledAt;
}

/// Calcula el resumen de gastos de la semana y su comparación con la anterior.
WeeklySummaryData calculateWeeklySummary({
  required List<TxView> currentWeekTxs,
  required List<TxView> previousWeekTxs,
  required DateTime weekStart,
  required DateTime weekEnd,
}) {
  var curTotal = 0;
  final Map<String, int> catTotals = {};
  final Map<String, String> catNames = {};

  for (final item in currentWeekTxs) {
    if (item.tx.type != TxType.expense) continue;
    curTotal += item.tx.amount;
    catTotals[item.category.id] =
        (catTotals[item.category.id] ?? 0) + item.tx.amount;
    catNames[item.category.id] = item.category.name;
  }

  var prevTotal = 0;
  for (final item in previousWeekTxs) {
    if (item.tx.type != TxType.expense) continue;
    prevTotal += item.tx.amount;
  }

  int? diff;
  if (prevTotal > 0) {
    diff = (((curTotal - prevTotal) / prevTotal) * 100).round();
  } else if (curTotal > 0) {
    diff = null;
  } else {
    diff = 0;
  }

  String? topCat;
  int topAmount = 0;
  for (final entry in catTotals.entries) {
    if (entry.value > topAmount) {
      topAmount = entry.value;
      topCat = catNames[entry.key];
    }
  }

  return WeeklySummaryData(
    currentWeekTotal: curTotal,
    previousWeekTotal: prevTotal,
    percentageDiff: diff,
    topCategoryName: topCat,
    topCategoryAmount: topAmount,
    weekStart: weekStart,
    weekEnd: weekEnd,
  );
}

/// Genera el texto del resumen semanal en español paraguayo natural.
String buildWeeklySummaryNotificationBody(WeeklySummaryData summary) {
  if (summary.currentWeekTotal == 0) {
    return 'Sin gastos registrados esta semana. ¡Buena semana!';
  }

  final totalFormatted = formatGs(summary.currentWeekTotal);
  final String diffPart;
  if (summary.percentageDiff != null) {
    final sign = summary.percentageDiff! > 0 ? '+' : '';
    diffPart = '$sign${summary.percentageDiff}% vs la anterior';
  } else {
    diffPart = 'primera semana con gastos';
  }

  final catPart = summary.topCategoryName != null
      ? ' Categoría principal: ${summary.topCategoryName}.'
      : '';

  return 'Gastaste $totalFormatted esta semana ($diffPart).$catPart';
}

/// Programa la notificación del resumen semanal según la configuración.
Future<void> scheduleWeeklySummary({
  required AppDatabase db,
  required Notifier notifier,
  required SettingsRepository settingsRepo,
  required DateTime nowLocal,
}) async {
  final enabledStr = await settingsRepo.get(SettingsKeys.weeklySummaryEnabled);
  if (enabledStr == 'false') {
    await notifier.cancel(kWeeklySummaryNotificationId);
    return;
  }

  final quietStartStr =
      await settingsRepo.get(SettingsKeys.remindersQuietStart) ?? '23:00';
  final quietEndStr =
      await settingsRepo.get(SettingsKeys.remindersQuietEnd) ?? '09:00';
  final quietStart = _parseTime(quietStartStr, fallbackH: 23, fallbackM: 0);
  final quietEnd = _parseTime(quietEndStr, fallbackH: 9, fallbackM: 0);

  // Lunes de la semana actual
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final daysSinceMonday = (nowLocal.weekday - DateTime.monday) % 7;
  final curMonday = today.subtract(Duration(days: daysSinceMonday));
  final curSundayEnd = curMonday.add(const Duration(days: 7));
  final prevMonday = curMonday.subtract(const Duration(days: 7));

  final curRows =
      await (db.select(db.transactions).join([
            innerJoin(
              db.categories,
              db.categories.id.equalsExp(db.transactions.categoryId),
            ),
          ])..where(
            db.transactions.deletedAt.isNull() &
                db.transactions.type.equalsValue(TxType.expense) &
                db.transactions.occurredAt.isBiggerOrEqualValue(
                  curMonday.toUtc(),
                ) &
                db.transactions.occurredAt.isSmallerThanValue(
                  curSundayEnd.toUtc(),
                ),
          ))
          .get();

  final prevRows =
      await (db.select(db.transactions).join([
            innerJoin(
              db.categories,
              db.categories.id.equalsExp(db.transactions.categoryId),
            ),
          ])..where(
            db.transactions.deletedAt.isNull() &
                db.transactions.type.equalsValue(TxType.expense) &
                db.transactions.occurredAt.isBiggerOrEqualValue(
                  prevMonday.toUtc(),
                ) &
                db.transactions.occurredAt.isSmallerThanValue(
                  curMonday.toUtc(),
                ),
          ))
          .get();

  final curItems = curRows
      .map(
        (r) => TxView(
          tx: r.readTable(db.transactions),
          category: r.readTable(db.categories),
        ),
      )
      .toList();

  final prevItems = prevRows
      .map(
        (r) => TxView(
          tx: r.readTable(db.transactions),
          category: r.readTable(db.categories),
        ),
      )
      .toList();

  final summary = calculateWeeklySummary(
    currentWeekTxs: curItems,
    previousWeekTxs: prevItems,
    weekStart: curMonday,
    weekEnd: curSundayEnd.subtract(const Duration(milliseconds: 1)),
  );

  final scheduledAt = nextSundayAt19(
    nowLocal,
    quietStart: quietStart,
    quietEnd: quietEnd,
  );

  final body = buildWeeklySummaryNotificationBody(summary);

  final reminder = PlannedReminder(
    atLocal: scheduledAt,
    notificationId: kWeeklySummaryNotificationId,
    title: 'Resumen semanal',
    body: body,
    payload: 'reports',
  );

  await notifier.schedule(reminder);
}
