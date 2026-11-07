/**
 * recurrence.ts
 * Port of lib/features/recurring/domain/recurrence.dart
 */

export type RecurrenceFrequency = 'monthly' | 'weekly' | 'yearly';

export interface RecurrenceOptions {
  frequency: RecurrenceFrequency;
  dayOfMonth?: number;
  dayOfWeek?: number; // 1 = Monday .. 7 = Sunday
  monthOfYear?: number; // 1 = Jan .. 12 = Dec
}

function parseYMD(s: string): { year: number; month: number; day: number } {
  const parts = s.split('T')[0].split('-').map(Number);
  return { year: parts[0], month: parts[1], day: parts[2] };
}

function formatYMD(d: { year: number; month: number; day: number } | Date): string {
  if (d instanceof Date) {
    const y = d.getFullYear().toString().padStart(4, '0');
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${day}`;
  }
  return `${d.year.toString().padStart(4, '0')}-${d.month.toString().padStart(2, '0')}-${d.day.toString().padStart(2, '0')}`;
}

function daysInMonth(year: number, month: number): number {
  return new Date(year, month, 0).getDate();
}

/**
 * Returns ISO day of week: 1 = Monday, 7 = Sunday
 */
function getIsoDayOfWeek(d: Date): number {
  const dow = d.getDay(); // 0 is Sunday, 1 is Monday ... 6 is Saturday
  return dow === 0 ? 7 : dow;
}

export function nextOccurrence(
  afterInput: string | Date,
  options: RecurrenceOptions,
): string {
  const afterYMD = typeof afterInput === 'string' ? parseYMD(afterInput) : {
    year: afterInput.getFullYear(),
    month: afterInput.getMonth() + 1,
    day: afterInput.getDate(),
  };

  const afterDate = new Date(afterYMD.year, afterYMD.month - 1, afterYMD.day);

  switch (options.frequency) {
    case 'weekly': {
      const currentWeekday = getIsoDayOfWeek(afterDate);
      const targetWeekday = options.dayOfWeek ?? currentWeekday;
      let delta = targetWeekday - currentWeekday;
      if (delta <= 0) {
        delta += 7;
      }
      const candidate = new Date(afterDate);
      candidate.setDate(candidate.getDate() + delta);
      return formatYMD(candidate);
    }

    case 'monthly': {
      const targetDay = options.dayOfMonth ?? afterYMD.day;

      // Check current month first
      const curDays = daysInMonth(afterYMD.year, afterYMD.month);
      const curClamped = Math.max(1, Math.min(targetDay, curDays));
      const curCandidate = new Date(afterYMD.year, afterYMD.month - 1, curClamped);
      if (curCandidate.getTime() > afterDate.getTime()) {
        return formatYMD(curCandidate);
      }

      // Advance month by month
      let y = afterYMD.year;
      let m = afterYMD.month + 1;
      while (true) {
        if (m > 12) {
          y++;
          m = 1;
        }
        const dim = daysInMonth(y, m);
        const clamped = Math.max(1, Math.min(targetDay, dim));
        const candidate = new Date(y, m - 1, clamped);
        if (candidate.getTime() > afterDate.getTime()) {
          return formatYMD(candidate);
        }
        m++;
      }
    }

    case 'yearly': {
      const targetMonth = options.monthOfYear ?? afterYMD.month;
      const targetDay = options.dayOfMonth ?? afterYMD.day;

      // Check current year first
      const curDays = daysInMonth(afterYMD.year, targetMonth);
      const curClamped = Math.max(1, Math.min(targetDay, curDays));
      const curCandidate = new Date(afterYMD.year, targetMonth - 1, curClamped);
      if (curCandidate.getTime() > afterDate.getTime()) {
        return formatYMD(curCandidate);
      }

      // Advance year by year
      let y = afterYMD.year + 1;
      while (true) {
        const dim = daysInMonth(y, targetMonth);
        const clamped = Math.max(1, Math.min(targetDay, dim));
        const candidate = new Date(y, targetMonth - 1, clamped);
        if (candidate.getTime() > afterDate.getTime()) {
          return formatYMD(candidate);
        }
        y++;
      }
    }
  }
}

export function dueOccurrences(
  nextDueDateInput: string | Date,
  todayInput: string | Date,
  options: RecurrenceOptions,
): string[] {
  const dueYMD = typeof nextDueDateInput === 'string' ? parseYMD(nextDueDateInput) : {
    year: nextDueDateInput.getFullYear(),
    month: nextDueDateInput.getMonth() + 1,
    day: nextDueDateInput.getDate(),
  };

  const todayYMD = typeof todayInput === 'string' ? parseYMD(todayInput) : {
    year: todayInput.getFullYear(),
    month: todayInput.getMonth() + 1,
    day: todayInput.getDate(),
  };

  const dueDate = new Date(dueYMD.year, dueYMD.month - 1, dueYMD.day);
  const todayDate = new Date(todayYMD.year, todayYMD.month - 1, todayYMD.day);

  if (dueDate.getTime() > todayDate.getTime()) {
    return [];
  }

  const occurrences: string[] = [];
  let current = dueDate;

  while (current.getTime() <= todayDate.getTime()) {
    occurrences.push(formatYMD(current));
    const nextStr = nextOccurrence(current, options);
    const parts = nextStr.split('-').map(Number);
    current = new Date(parts[0], parts[1] - 1, parts[2]);
  }

  return occurrences;
}
