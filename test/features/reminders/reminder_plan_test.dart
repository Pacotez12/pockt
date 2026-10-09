import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/reminders/domain/reminder_plan.dart';

void main() {
  group('planReminders', () {
    final now = DateTime(2026, 10, 9, 10, 0); // Viernes 10:00 AM
    const quietHours = (h: 23, m: 0);
    const quietWake = (h: 9, m: 0);

    test('off no genera ningún recordatorio', () {
      final reminders = planReminders(
        nowLocal: now,
        intensity: ReminderIntensity.off,
        daysWithExpense: {},
        noSpendDays: {},
        quietStart: quietHours,
        quietEnd: quietWake,
      );

      expect(reminders, isEmpty);
    });

    test('soft genera a las 21:00 para los próximos 7 días', () {
      final reminders = planReminders(
        nowLocal: now,
        intensity: ReminderIntensity.soft,
        daysWithExpense: {},
        noSpendDays: {},
        quietStart: quietHours,
        quietEnd: quietWake,
        days: 7,
      );

      expect(reminders.length, 7);
      for (var i = 0; i < 7; i++) {
        final r = reminders[i];
        expect(r.atLocal.hour, 21);
        expect(r.atLocal.minute, 0);
        expect(r.atLocal.day, 9 + i);
        expect(kNightTexts, contains(r.body));
      }
    });

    test('normal genera a las 13:00 y 21:00 con textos diferenciados', () {
      final reminders = planReminders(
        nowLocal: now,
        intensity: ReminderIntensity.normal,
        daysWithExpense: {},
        noSpendDays: {},
        quietStart: quietHours,
        quietEnd: quietWake,
        days: 1,
      );

      expect(reminders.length, 2);
      expect(reminders[0].atLocal.hour, 13);
      expect(kMiddayTexts, contains(reminders[0].body));
      expect(reminders[1].atLocal.hour, 21);
      expect(kNightTexts, contains(reminders[1].body));
    });

    test('insistent genera cada 3 h desde las 12:00, máximo 4 por día', () {
      final reminders = planReminders(
        nowLocal: now,
        intensity: ReminderIntensity.insistent,
        daysWithExpense: {},
        noSpendDays: {},
        quietStart: quietHours,
        quietEnd: quietWake,
        days: 1,
      );

      expect(reminders.length, 4);
      expect(reminders.map((r) => r.atLocal.hour).toList(), [12, 15, 18, 21]);
      for (final r in reminders) {
        expect(kInsistentTexts, contains(r.body));
      }
    });

    test('día con gasto o noSpend no genera recordatorios ese día', () {
      final today = DateTime(2026, 10, 9);
      final tomorrow = DateTime(2026, 10, 10);

      final reminders = planReminders(
        nowLocal: now,
        intensity: ReminderIntensity.normal,
        daysWithExpense: {today},
        noSpendDays: {tomorrow},
        quietStart: quietHours,
        quietEnd: quietWake,
        days: 3, // hoy, mañana, pasado
      );

      // Hoy y mañana están excluidos, solo pasado mañana (día 11) tiene 2
      expect(reminders.length, 2);
      expect(reminders[0].atLocal.day, 11);
      expect(reminders[1].atLocal.day, 11);
    });

    test('silencio 23:00–09:00 cruzando medianoche descarta horarios en silencio', () {
      // Supongamos un horario que cayera a las 23:30 o a las 08:00
      // Con quietStart 20:00 y quietEnd 14:00:
      // Para Normal (13:00 y 21:00):
      // 13:00 está en silencio (antes de las 14:00)
      // 21:00 está en silencio (después de las 20:00)
      final reminders = planReminders(
        nowLocal: now,
        intensity: ReminderIntensity.normal,
        daysWithExpense: {},
        noSpendDays: {},
        quietStart: (h: 20, m: 0),
        quietEnd: (h: 14, m: 0),
        days: 1,
      );

      expect(reminders, isEmpty);
    });

    test('a las 21:30 con soft no planifica hoy porque ya pasó', () {
      final lateNow = DateTime(2026, 10, 9, 21, 30);

      final reminders = planReminders(
        nowLocal: lateNow,
        intensity: ReminderIntensity.soft,
        daysWithExpense: {},
        noSpendDays: {},
        quietStart: quietHours,
        quietEnd: quietWake,
        days: 2,
      );

      // Hoy a las 21:00 ya pasó; solo mañana a las 21:00
      expect(reminders.length, 1);
      expect(reminders.first.atLocal.day, 10);
      expect(reminders.first.atLocal.hour, 21);
    });

    test('notificationId es estable entre dos llamadas y único por horario', () {
      final call1 = planReminders(
        nowLocal: now,
        intensity: ReminderIntensity.normal,
        daysWithExpense: {},
        noSpendDays: {},
        quietStart: quietHours,
        quietEnd: quietWake,
        days: 2,
      );

      final call2 = planReminders(
        nowLocal: now,
        intensity: ReminderIntensity.normal,
        daysWithExpense: {},
        noSpendDays: {},
        quietStart: quietHours,
        quietEnd: quietWake,
        days: 2,
      );

      expect(call1.length, 4);
      for (var i = 0; i < call1.length; i++) {
        expect(call1[i].notificationId, call2[i].notificationId);
      }

      // Todos los IDs dentro de la lista son distintos entre sí
      final ids = call1.map((r) => r.notificationId).toSet();
      expect(ids.length, call1.length);

      // Formato yyyymmdd * 100 + index
      expect(call1[0].notificationId, 2026100900);
      expect(call1[1].notificationId, 2026100901);
      expect(call1[2].notificationId, 2026101000);
      expect(call1[3].notificationId, 2026101001);
    });
  });

  group('textos de recordatorio', () {
    test('cada grupo tiene al menos 5 textos distintos', () {
      for (final pool in [kNightTexts, kMiddayTexts, kInsistentTexts]) {
        expect(pool.toSet(), hasLength(greaterThanOrEqualTo(5)));
      }
    });
    test('el texto cambia de un día al siguiente', () {
      final a = reminderText(ReminderIntensity.soft, 0, DateTime(2026, 10, 9));
      final b = reminderText(ReminderIntensity.soft, 0, DateTime(2026, 10, 10));
      expect(a, isNot(b));
    });
    test('Normal usa el texto de mediodía en el primer horario y el de la noche en el segundo', () {
      final day = DateTime(2026, 10, 9);
      expect(kMiddayTexts, contains(reminderText(ReminderIntensity.normal, 0, day)));
      expect(kNightTexts, contains(reminderText(ReminderIntensity.normal, 1, day)));
    });
    test('Insistente usa sus propios textos', () {
      expect(kInsistentTexts,
          contains(reminderText(ReminderIntensity.insistent, 2, DateTime(2026, 10, 9))));
    });
  });
}
