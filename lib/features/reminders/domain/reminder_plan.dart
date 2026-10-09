/// Intensidad de los recordatorios de gastos.
enum ReminderIntensity {
  off,
  soft,
  normal,
  insistent,
}

/// Representa un recordatorio programado en una fecha y hora local determinada.
class PlannedReminder {
  final DateTime atLocal;
  final int notificationId;
  final String title;
  final String body;

  const PlannedReminder({
    required this.atLocal,
    required this.notificationId,
    required this.title,
    required this.body,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedReminder &&
          runtimeType == other.runtimeType &&
          atLocal == other.atLocal &&
          notificationId == other.notificationId &&
          title == other.title &&
          body == other.body;

  @override
  int get hashCode =>
      Object.hash(atLocal, notificationId, title, body);

  @override
  String toString() =>
      'PlannedReminder(atLocal: $atLocal, notificationId: $notificationId, title: $title, body: $body)';
}

/// Verifica si un horario determinado (hora y minuto) cae dentro del rango de silencio.
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
    // Rango dentro del mismo día (ej. 14:00 a 16:00)
    return timeVal >= startVal && timeVal < endVal;
  } else {
    // Cruza la medianoche (ej. 23:00 a 09:00)
    return timeVal >= startVal || timeVal < endVal;
  }
}

/// Planifica los recordatorios para los próximos [days] días a partir de [nowLocal].
///
/// Solo programa horarios futuros. Si un día ya tiene gastos registrados en
/// [daysWithExpense] o está marcado en [noSpendDays], no se planifica nada para ese día.
/// Los horarios que caigan dentro del rango de silencio ([quietStart]–[quietEnd]) se omiten.
/// Los [notificationId] son estables e inequívocos: `yyyymmdd * 100 + índice`.
List<PlannedReminder> planReminders({
  required DateTime nowLocal,
  required ReminderIntensity intensity,
  required Set<DateTime> daysWithExpense,
  required Set<DateTime> noSpendDays,
  required ({int h, int m}) quietStart,
  required ({int h, int m}) quietEnd,
  int days = 7,
}) {
  if (intensity == ReminderIntensity.off || days <= 0) {
    return const [];
  }

  // Definición de horarios y textos por intensidad
  final List<({int h, int m, String body})> slots;
  switch (intensity) {
    case ReminderIntensity.off:
      slots = const [];
      break;
    case ReminderIntensity.soft:
      slots = const [
        (h: 21, m: 0, body: '¿Gastaste algo hoy? Anotalo en 10 segundos.'),
      ];
      break;
    case ReminderIntensity.normal:
      slots = const [
        (h: 13, m: 0, body: '¿Cómo va el día? Anotá lo que llevás gastado.'),
        (h: 21, m: 0, body: '¿Gastaste algo hoy? Anotalo en 10 segundos.'),
      ];
      break;
    case ReminderIntensity.insistent:
      slots = const [
        (h: 12, m: 0, body: 'ANOTÁ TUS GASTOS DE HOY.'),
        (h: 15, m: 0, body: 'ANOTÁ TUS GASTOS DE HOY.'),
        (h: 18, m: 0, body: 'ANOTÁ TUS GASTOS DE HOY.'),
        (h: 21, m: 0, body: 'ANOTÁ TUS GASTOS DE HOY.'),
      ];
      break;
  }

  final normExpense =
      daysWithExpense.map((d) => (d.year, d.month, d.day)).toSet();
  final normNoSpend =
      noSpendDays.map((d) => (d.year, d.month, d.day)).toSet();

  final result = <PlannedReminder>[];

  for (var i = 0; i < days; i++) {
    final targetDay = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day + i,
    );

    final dayKey = (targetDay.year, targetDay.month, targetDay.day);
    if (normExpense.contains(dayKey) || normNoSpend.contains(dayKey)) {
      continue;
    }

    final datePrefix =
        targetDay.year * 10000 + targetDay.month * 100 + targetDay.day;

    for (var slotIdx = 0; slotIdx < slots.length; slotIdx++) {
      final slot = slots[slotIdx];
      final reminderTime = DateTime(
        targetDay.year,
        targetDay.month,
        targetDay.day,
        slot.h,
        slot.m,
      );

      // Solo horarios estrictamente futuros
      if (!reminderTime.isAfter(nowLocal)) {
        continue;
      }

      // Descartar si cae en horas de silencio
      if (_isInQuietHours(slot.h, slot.m, quietStart, quietEnd)) {
        continue;
      }

      final id = datePrefix * 100 + slotIdx;

      result.add(
        PlannedReminder(
          atLocal: reminderTime,
          notificationId: id,
          title: 'Pockt',
          body: slot.body,
        ),
      );
    }
  }

  return result;
}
