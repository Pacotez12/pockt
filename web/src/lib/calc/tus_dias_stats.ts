export interface DailyDataPoint {
  date: Date;
  amount: number;
  txCount: number;
  topMerchant?: string;
  isToday?: boolean;
  isFuture?: boolean;
}

export interface DayDataWithFlags extends DailyDataPoint {
  isToday: boolean;
  isFuture: boolean;
  level?: number;
}

export interface TusDiasWindow {
  startDate: Date;
  endDate: Date;
  weeksCount: number;
  days: DayDataWithFlags[];
}

export interface TusDiasStats {
  maxExpenseDay: {
    amount: number;
    date: Date | null;
    shortDate: string;
  };
  dailyAverage: {
    amount: number;
    daysCount: number;
  };
  noExpenseDays: {
    count: number;
    totalDays: number;
    percentage: number;
  };
  currentStreak: {
    days: number;
  };
  totalSpent: number;
  startDate: Date;
}

function toStartOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function formatDateKey(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function computeTusDiasWindow({
  dataPoints,
  referenceDate = new Date(),
  minWeeks = 8,
  maxWeeks = 26,
}: {
  dataPoints: DailyDataPoint[];
  referenceDate?: Date;
  minWeeks?: number;
  maxWeeks?: number;
}): TusDiasWindow {
  const ref = toStartOfDay(referenceDate);

  // Monday = 0, ..., Sunday = 6
  const refDayOfWeek = (ref.getDay() + 6) % 7;

  // The current week's Monday
  const currentMonday = new Date(ref);
  currentMonday.setDate(ref.getDate() - refDayOfWeek);

  // The current week's Sunday (end of window)
  const endSunday = new Date(currentMonday);
  endSunday.setDate(currentMonday.getDate() + 6);

  // Map data points by YYYY-MM-DD
  const map = new Map<string, DailyDataPoint>();
  for (const dp of dataPoints) {
    const key = formatDateKey(dp.date);
    const existing = map.get(key);
    if (!existing) {
      map.set(key, { ...dp, date: toStartOfDay(dp.date) });
    } else {
      existing.amount += dp.amount;
      existing.txCount += dp.txCount;
      if (dp.topMerchant && !existing.topMerchant) {
        existing.topMerchant = dp.topMerchant;
      }
    }
  }

  // Earliest possible start Monday (maxWeeks limit)
  const maxStartMonday = new Date(currentMonday);
  maxStartMonday.setDate(currentMonday.getDate() - (maxWeeks - 1) * 7);

  // Find first expense within or before the last maxWeeks (6 months)
  let hasOlderExpenses = false;
  let earliestExpenseDate: Date | null = null;
  for (const dp of map.values()) {
    if (dp.amount > 0 && dp.date <= ref) {
      if (dp.date < maxStartMonday) {
        hasOlderExpenses = true;
      } else {
        if (!earliestExpenseDate || dp.date < earliestExpenseDate) {
          earliestExpenseDate = dp.date;
        }
      }
    }
  }

  if (hasOlderExpenses) {
    earliestExpenseDate = maxStartMonday;
  }

  let weeksCount = minWeeks;
  if (earliestExpenseDate) {
    const expDayOfWeek = (earliestExpenseDate.getDay() + 6) % 7;
    const expMonday = new Date(earliestExpenseDate);
    expMonday.setDate(earliestExpenseDate.getDate() - expDayOfWeek);

    const diffDays = Math.round((currentMonday.getTime() - expMonday.getTime()) / 86400000);
    const calculatedWeeks = Math.round(diffDays / 7) + 1;
    weeksCount = Math.max(minWeeks, Math.min(maxWeeks, calculatedWeeks));
  }

  const chosenStartMonday = new Date(currentMonday);
  chosenStartMonday.setDate(currentMonday.getDate() - (weeksCount - 1) * 7);

  const totalDays = weeksCount * 7;
  const days: DayDataWithFlags[] = [];

  for (let i = 0; i < totalDays; i++) {
    const d = new Date(chosenStartMonday);
    d.setDate(chosenStartMonday.getDate() + i);
    const key = formatDateKey(d);
    const dp = map.get(key);

    const isToday = d.getTime() === ref.getTime();
    const isFuture = d.getTime() > ref.getTime();

    days.push({
      date: d,
      amount: isFuture ? 0 : dp ? dp.amount : 0,
      txCount: isFuture ? 0 : dp ? dp.txCount : 0,
      topMerchant: isFuture ? undefined : dp?.topMerchant,
      isToday,
      isFuture,
    });
  }

  return {
    startDate: chosenStartMonday,
    endDate: endSunday,
    weeksCount,
    days,
  };
}

export function computeTusDiasStats({
  days,
  today = new Date(),
}: {
  days: DayDataWithFlags[];
  today?: Date;
}): TusDiasStats {
  const ref = toStartOfDay(today);
  const refTime = ref.getTime();

  // Only consider days up to today
  const pastAndTodayDays = days.filter((d) => !d.isFuture && toStartOfDay(d.date).getTime() <= refTime);
  const daysCount = pastAndTodayDays.length;

  // 1. Max expense day
  let maxDay: DayDataWithFlags | null = null;
  for (const d of pastAndTodayDays) {
    if (d.amount > 0) {
      if (!maxDay || d.amount > maxDay.amount) {
        maxDay = d;
      }
    }
  }

  const maxExpenseDay = {
    amount: maxDay ? maxDay.amount : 0,
    date: maxDay ? maxDay.date : null,
    shortDate: maxDay
      ? maxDay.date.toLocaleDateString('es-PY', { weekday: 'short', day: 'numeric', month: 'short' })
      : '-',
  };

  // 2. Daily average
  const totalSpent = pastAndTodayDays.reduce((sum, d) => sum + (d.amount || 0), 0);
  const dailyAverage = {
    amount: daysCount > 0 ? Math.round(totalSpent / daysCount) : 0,
    daysCount,
  };

  // 3. No expense days
  const noExpenseCount = pastAndTodayDays.filter((d) => (d.amount || 0) === 0).length;
  const noExpenseDays = {
    count: noExpenseCount,
    totalDays: daysCount,
    percentage: daysCount > 0 ? Math.round((noExpenseCount / daysCount) * 100) : 0,
  };

  // 4. Current streak of days without expenses up to today
  // Sort descending by date
  const sortedDesc = [...pastAndTodayDays].sort(
    (a, b) => toStartOfDay(b.date).getTime() - toStartOfDay(a.date).getTime()
  );

  let currentStreakDays = 0;
  for (const d of sortedDesc) {
    if ((d.amount || 0) === 0) {
      currentStreakDays++;
    } else {
      break;
    }
  }

  const startDate = days.length > 0 ? days[0].date : ref;

  return {
    maxExpenseDay,
    dailyAverage,
    noExpenseDays,
    currentStreak: { days: currentStreakDays },
    totalSpent,
    startDate,
  };
}
