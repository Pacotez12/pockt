/**
 * date_period.ts
 * Port of lib/core/time/date_period.dart, lib/features/income/domain/pay_days.dart,
 * and lib/features/income/domain/py_holidays.dart.
 */

export type MonthStartMode = 'calendar' | 'payday';
export type PayDayRule = 'previous' | 'next' | 'either';

export interface DatePeriodResult {
  start: string; // YYYY-MM-DD
  end: string;   // YYYY-MM-DD
  daysCount: number;
}

export interface PeriodForOptions {
  mode?: MonthStartMode | string;
  payDays?: number[];
  payDayRules?: (PayDayRule | string)[];
}

/**
 * Calculates Easter Sunday for a Gregorian year using the Meeus/Jones/Butcher algorithm.
 */
export function easterSunday(year: number): { month: number; day: number } {
  const a = year % 19;
  const b = Math.floor(year / 100);
  const c = year % 100;
  const d = Math.floor(b / 4);
  const e = b % 4;
  const f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4);
  const k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31);
  const day = ((h + l - 7 * m + 114) % 31) + 1;
  return { month, day };
}

/**
 * Checks if a given date is a national holiday in Paraguay.
 */
export function isPyHoliday(year: number, month: number, day: number): boolean {
  // Feriados fijos
  if (month === 1 && day === 1) return true;
  if (month === 3 && day === 1) return true;
  if (month === 5 && (day === 1 || day === 14 || day === 15)) return true;
  if (month === 6 && day === 12) return true;
  if (month === 8 && day === 15) return true;
  if (month === 9 && day === 29) return true;
  if (month === 12 && (day === 8 || day === 25)) return true;

  // Feriados móviles: Jueves y Viernes Santo
  const easter = easterSunday(year);
  // easter is in UTC/local calendar day
  const easterDate = new Date(year, easter.month - 1, easter.day);
  const viernesDate = new Date(easterDate);
  viernesDate.setDate(easterDate.getDate() - 2);
  const juevesDate = new Date(easterDate);
  juevesDate.setDate(easterDate.getDate() - 3);

  if (month === viernesDate.getMonth() + 1 && day === viernesDate.getDate()) return true;
  if (month === juevesDate.getMonth() + 1 && day === juevesDate.getDate()) return true;

  return false;
}

/**
 * Checks if a date is a business day (Monday-Friday and not a holiday).
 */
export function isBusinessDay(date: Date): boolean {
  const dow = date.getDay(); // 0 is Sunday, 6 is Saturday
  if (dow === 0 || dow === 6) {
    return false;
  }
  return !isPyHoliday(date.getFullYear(), date.getMonth() + 1, date.getDate());
}

function findPreviousBusinessDay(date: Date): Date {
  const d = new Date(date);
  d.setDate(d.getDate() - 1);
  while (!isBusinessDay(d)) {
    d.setDate(d.getDate() - 1);
  }
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function findNextBusinessDay(date: Date): Date {
  const d = new Date(date);
  d.setDate(d.getDate() + 1);
  while (!isBusinessDay(d)) {
    d.setDate(d.getDate() + 1);
  }
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

interface PayWindow {
  earliest: Date;
  latest: Date;
}

function resolvePayWindow(target: Date, rule: PayDayRule): PayWindow {
  const clean = new Date(target.getFullYear(), target.getMonth(), target.getDate());
  if (isBusinessDay(clean)) {
    return { earliest: clean, latest: clean };
  }

  const prev = findPreviousBusinessDay(clean);
  const next = findNextBusinessDay(clean);

  switch (rule) {
    case 'previous':
      return { earliest: prev, latest: prev };
    case 'next':
      return { earliest: next, latest: next };
    case 'either':
    default:
      return { earliest: prev, latest: next };
  }
}

function payWindowsInMonth(
  year: number,
  month: number,
  payDays: number[],
  rules: PayDayRule[],
): PayWindow[] {
  const daysInMonth = new Date(year, month, 0).getDate();
  const windows: PayWindow[] = [];

  for (let i = 0; i < payDays.length; i++) {
    const rawDay = payDays[i];
    const rule = rules[i] ?? (rawDay === -1 ? 'previous' : 'either');
    let targetDay: number;
    if (rawDay === -1) {
      targetDay = daysInMonth;
    } else {
      targetDay = Math.min(rawDay, daysInMonth);
    }
    const targetDate = new Date(year, month - 1, targetDay);
    windows.push(resolvePayWindow(targetDate, rule));
  }

  windows.sort((a, b) => a.earliest.getTime() - b.earliest.getTime());
  return windows;
}

function endOfMonthPayDay(
  year: number,
  month: number,
  payDays: number[],
  rules: PayDayRule[],
): Date {
  const windows = payWindowsInMonth(year, month, payDays, rules);
  if (windows.length === 0) {
    const lastDay = new Date(year, month, 0).getDate();
    return new Date(year, month - 1, lastDay);
  }
  return windows[windows.length - 1].earliest;
}

function formatDate(d: Date): string {
  const y = d.getFullYear().toString().padStart(4, '0');
  const m = (d.getMonth() + 1).toString().padStart(2, '0');
  const day = d.getDate().toString().padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function parseISODate(s: string): Date {
  const [y, m, d] = s.split('-').map(Number);
  return new Date(y, m - 1, d);
}

/**
 * Determines the DatePeriod for a given date according to mode and income schedule.
 */
export function periodFor(
  dayInput: string | Date,
  options?: PeriodForOptions,
): DatePeriodResult {
  const day = typeof dayInput === 'string' ? parseISODate(dayInput) : new Date(dayInput.getFullYear(), dayInput.getMonth(), dayInput.getDate());
  const mode = options?.mode === 'payday' ? 'payday' : 'calendar';

  if (mode === 'calendar') {
    const start = new Date(day.getFullYear(), day.getMonth(), 1);
    const end = new Date(day.getFullYear(), day.getMonth() + 1, 0);
    const daysCount = Math.round((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;
    return {
      start: formatDate(start),
      end: formatDate(end),
      daysCount,
    };
  }

  const effectivePayDays = options?.payDays ?? [];
  if (effectivePayDays.length === 0) {
    const start = new Date(day.getFullYear(), day.getMonth(), 1);
    const end = new Date(day.getFullYear(), day.getMonth() + 1, 0);
    const daysCount = Math.round((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;
    return {
      start: formatDate(start),
      end: formatDate(end),
      daysCount,
    };
  }

  const effectiveRules: PayDayRule[] = (options?.payDayRules ?? []).map((r, i) => {
    if (r === 'previous' || r === 'next' || r === 'either') return r as PayDayRule;
    const raw = effectivePayDays[i];
    return raw === -1 ? 'previous' : 'either';
  });

  while (effectiveRules.length < effectivePayDays.length) {
    const raw = effectivePayDays[effectiveRules.length];
    effectiveRules.push(raw === -1 ? 'previous' : 'either');
  }

  const pCurrent = endOfMonthPayDay(
    day.getFullYear(),
    day.getMonth() + 1,
    effectivePayDays,
    effectiveRules,
  );

  let start: Date;
  let end: Date;

  if (day.getTime() < pCurrent.getTime()) {
    const prevMonth = day.getMonth() === 0 ? 12 : day.getMonth();
    const prevYear = day.getMonth() === 0 ? day.getFullYear() - 1 : day.getFullYear();
    start = endOfMonthPayDay(prevYear, prevMonth, effectivePayDays, effectiveRules);
    end = new Date(pCurrent);
    end.setDate(end.getDate() - 1);
  } else {
    const nextMonth = day.getMonth() === 11 ? 1 : day.getMonth() + 2;
    const nextYear = day.getMonth() === 11 ? day.getFullYear() + 1 : day.getFullYear();
    const pNext = endOfMonthPayDay(nextYear, nextMonth, effectivePayDays, effectiveRules);
    start = pCurrent;
    end = new Date(pNext);
    end.setDate(end.getDate() - 1);
  }

  const daysCount = Math.round((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;

  return {
    start: formatDate(start),
    end: formatDate(end),
    daysCount,
  };
}
