import { describe, it, expect } from 'vitest';
import {
  computeTusDiasWindow,
  computeTusDiasStats,
  type DailyDataPoint,
} from './tus_dias_stats';

describe('tus_dias_stats', () => {
  describe('computeTusDiasWindow', () => {
    it('ventana con datos desde octubre arranca en esa semana', () => {
      // Reference date: Wednesday 16 Dec 2026
      const refDate = new Date(2026, 11, 16); // 16 Dec 2026

      // First expense on Monday 12 Oct 2026
      const octExpenseDate = new Date(2026, 9, 12); // 12 Oct 2026 (Monday)
      const dataPoints: DailyDataPoint[] = [
        { date: octExpenseDate, amount: 150000, txCount: 2, topMerchant: 'Superseis' },
        { date: new Date(2026, 10, 5), amount: 80000, txCount: 1 },
      ];

      const window = computeTusDiasWindow({
        dataPoints,
        referenceDate: refDate,
      });

      // Oct 12 to Dec 20 is 10 weeks (> min 8 weeks)
      // First day in window should be Monday Oct 12, 2026
      const firstDay = window.days[0];
      expect(firstDay.date.getFullYear()).toBe(2026);
      expect(firstDay.date.getMonth()).toBe(9); // Oct
      expect(firstDay.date.getDate()).toBe(12);
      expect(firstDay.date.getDay()).toBe(1); // Monday
      expect(window.weeksCount).toBe(10);
    });

    it('con datos de más de 6 meses, la ventana es de 6 meses (26 semanas)', () => {
      // Reference date: 15 Dec 2026
      const refDate = new Date(2026, 11, 15);

      // Data starting 1 year ago (Jan 2026)
      const oldExpenseDate = new Date(2026, 0, 10);
      const dataPoints: DailyDataPoint[] = [
        { date: oldExpenseDate, amount: 200000, txCount: 1 },
        { date: new Date(2026, 11, 1), amount: 50000, txCount: 1 },
      ];

      const window = computeTusDiasWindow({
        dataPoints,
        referenceDate: refDate,
      });

      // Max window is 26 weeks
      expect(window.weeksCount).toBe(26);
      expect(window.days.length).toBe(26 * 7);
    });

    it('garantiza mínimo 8 semanas si los datos tienen menos tiempo o no hay gastos', () => {
      const refDate = new Date(2026, 11, 15);
      const dataPoints: DailyDataPoint[] = [
        // Only 1 expense yesterday
        { date: new Date(2026, 11, 14), amount: 10000, txCount: 1 },
      ];

      const window = computeTusDiasWindow({
        dataPoints,
        referenceDate: refDate,
      });

      expect(window.weeksCount).toBe(8);
      expect(window.days.length).toBe(56);
    });

    it('marca días futuros y hoy correctamente', () => {
      // refDate is Wednesday 11 Nov 2026
      const refDate = new Date(2026, 10, 11);
      const window = computeTusDiasWindow({
        dataPoints: [{ date: new Date(2026, 9, 1), amount: 50000, txCount: 1 }],
        referenceDate: refDate,
      });

      const todayDay = window.days.find((d) => d.isToday);
      expect(todayDay).toBeDefined();
      expect(todayDay?.date.getDate()).toBe(11);
      expect(todayDay?.isFuture).toBe(false);

      const futureDays = window.days.filter((d) => d.isFuture);
      // Remainder of current week (Thu 12, Fri 13, Sat 14, Sun 15) are future
      expect(futureDays.length).toBe(4);
      futureDays.forEach((fd) => {
        expect(fd.date.getTime()).toBeGreaterThan(todayDay!.date.getTime());
      });
    });
  });

  describe('computeTusDiasStats', () => {
    it('calcula los cuatro datos con gastos normales', () => {
      const today = new Date(2026, 10, 10); // 10 Nov 2026
      const days = [
        // 5 days: Day 0 (expensive), Day 1 (0), Day 2 (50k), Day 3 (0), Day 4 (today, 0)
        { date: new Date(2026, 10, 6), amount: 1480000, txCount: 3, isToday: false, isFuture: false },
        { date: new Date(2026, 10, 7), amount: 0, txCount: 0, isToday: false, isFuture: false },
        { date: new Date(2026, 10, 8), amount: 50000, txCount: 1, isToday: false, isFuture: false },
        { date: new Date(2026, 10, 9), amount: 0, txCount: 0, isToday: false, isFuture: false },
        { date: new Date(2026, 10, 10), amount: 0, txCount: 0, isToday: true, isFuture: false },
        // 2 future days in week
        { date: new Date(2026, 10, 11), amount: 0, txCount: 0, isToday: false, isFuture: true },
        { date: new Date(2026, 10, 12), amount: 0, txCount: 0, isToday: false, isFuture: true },
      ];

      const stats = computeTusDiasStats({ days, today });

      // 1. Día más caro
      expect(stats.maxExpenseDay.amount).toBe(1480000);
      expect(stats.maxExpenseDay.date).toEqual(new Date(2026, 10, 6));
      expect(stats.maxExpenseDay.shortDate).toMatch(/6/);

      // 2. Promedio por día (total / 5 días hasta hoy = 1530000 / 5 = 306000)
      expect(stats.dailyAverage.daysCount).toBe(5);
      expect(stats.dailyAverage.amount).toBe(306000);

      // 3. Días sin gastos (3 de 5 = 60%)
      expect(stats.noExpenseDays.count).toBe(3);
      expect(stats.noExpenseDays.totalDays).toBe(5);
      expect(stats.noExpenseDays.percentage).toBe(60);

      // 4. Racha actual (Day 4 is 0, Day 3 is 0, Day 2 has 50k -> streak is 2)
      expect(stats.currentStreak.days).toBe(2);
    });

    it('maneja caso sin gastos (todos en 0)', () => {
      const today = new Date(2026, 10, 10);
      const days = [
        { date: new Date(2026, 10, 8), amount: 0, txCount: 0, isToday: false, isFuture: false },
        { date: new Date(2026, 10, 9), amount: 0, txCount: 0, isToday: false, isFuture: false },
        { date: new Date(2026, 10, 10), amount: 0, txCount: 0, isToday: true, isFuture: false },
      ];

      const stats = computeTusDiasStats({ days, today });

      expect(stats.maxExpenseDay.amount).toBe(0);
      expect(stats.maxExpenseDay.date).toBeNull();
      expect(stats.maxExpenseDay.shortDate).toBe('-');

      expect(stats.dailyAverage.amount).toBe(0);
      expect(stats.dailyAverage.daysCount).toBe(3);

      expect(stats.noExpenseDays.count).toBe(3);
      expect(stats.noExpenseDays.percentage).toBe(100);

      expect(stats.currentStreak.days).toBe(3);
    });

    it('maneja racha 0 cuando hoy tuvo gastos', () => {
      const today = new Date(2026, 10, 10);
      const days = [
        { date: new Date(2026, 10, 8), amount: 0, txCount: 0, isToday: false, isFuture: false },
        { date: new Date(2026, 10, 9), amount: 0, txCount: 0, isToday: false, isFuture: false },
        { date: new Date(2026, 10, 10), amount: 150000, txCount: 1, isToday: true, isFuture: false },
      ];

      const stats = computeTusDiasStats({ days, today });

      // Streak is 0 because today had an expense
      expect(stats.currentStreak.days).toBe(0);
    });
  });
});
