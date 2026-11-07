/**
 * goal_progress.ts
 * Port of lib/features/goals/domain/goal_progress.dart
 */

export interface GoalInput {
  id: string;
  name: string;
  targetAmount: number;
  targetDate?: string | null; // YYYY-MM-DD
}

export interface GoalContributionInput {
  id: string;
  goalId: string;
  amount: number;
  date: string; // YYYY-MM-DD
}

export type GoalStatus =
  | { type: 'noDate' }
  | { type: 'onTrack' }
  | { type: 'late'; months: number };

export interface GoalProgressResult {
  saved: number;
  percent: number;
  remaining: number;
  isCompleted: boolean;
  requiredMonthlyPace: number | null;
  realDailyPace: number;
  realMonthlyPace: number;
  projectedFinishDate: string | null;
  status: GoalStatus;
}

function parseYMD(s: string): Date {
  const parts = s.split('T')[0].split('-').map(Number);
  return new Date(parts[0], parts[1] - 1, parts[2]);
}

function formatYMD(d: Date): string {
  const y = d.getFullYear().toString().padStart(4, '0');
  const m = (d.getMonth() + 1).toString().padStart(2, '0');
  const day = d.getDate().toString().padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function differenceInDays(a: Date, b: Date): number {
  return Math.round((a.getTime() - b.getTime()) / (1000 * 60 * 60 * 24));
}

export function calculateGoalProgress({
  goal,
  contributions,
  now,
}: {
  goal: GoalInput;
  contributions: GoalContributionInput[];
  now?: string | Date;
}): GoalProgressResult {
  const currentNow = now
    ? (typeof now === 'string' ? parseYMD(now) : new Date(now.getFullYear(), now.getMonth(), now.getDate()))
    : new Date();
  const today = new Date(currentNow.getFullYear(), currentNow.getMonth(), currentNow.getDate());

  const saved = (contributions ?? []).reduce((sum, c) => sum + c.amount, 0);
  const remaining = Math.max(0, goal.targetAmount - saved);
  const isCompleted = goal.targetAmount > 0 ? saved >= goal.targetAmount : true;
  const rawPercent = goal.targetAmount > 0
    ? Math.max(0, Math.min(1, saved / goal.targetAmount))
    : 1.0;
  const percent = Math.round(rawPercent * 1000) / 1000;

  const targetDateObj = goal.targetDate ? parseYMD(goal.targetDate) : null;

  let requiredMonthlyPace: number | null = null;
  if (targetDateObj) {
    if (remaining <= 0) {
      requiredMonthlyPace = 0;
    } else {
      const daysLeft = differenceInDays(targetDateObj, today);
      if (daysLeft <= 0) {
        requiredMonthlyPace = remaining;
      } else {
        const monthsLeft = Math.max(1.0, daysLeft / 30.4375);
        requiredMonthlyPace = Math.ceil(remaining / monthsLeft);
      }
    }
  }

  // Ritmo real
  const contribDates = (contributions ?? []).map((c) => parseYMD(c.date));
  let firstDate = today;
  if (contribDates.length > 0) {
    firstDate = contribDates.reduce((min, d) => (d.getTime() < min.getTime() ? d : min), contribDates[0]);
  }

  const ninetyDaysAgo = new Date(today);
  ninetyDaysAgo.setDate(today.getDate() - 90);

  const windowStart = firstDate.getTime() > ninetyDaysAgo.getTime() ? firstDate : ninetyDaysAgo;
  const rawWindowDays = differenceInDays(today, windowStart);
  const windowDays = Math.max(30, Math.min(90, rawWindowDays));

  const recentContributions = (contributions ?? []).filter((c) => {
    const d = parseYMD(c.date);
    return d.getTime() >= windowStart.getTime() && d.getTime() <= today.getTime();
  });

  const netInWindow = recentContributions.reduce((sum, c) => sum + c.amount, 0);
  const rawDailyPace = netInWindow > 0 ? netInWindow / windowDays : 0.0;
  const realDailyPace = Math.round(rawDailyPace * 100) / 100;
  const realMonthlyPace = Math.round(rawDailyPace * 30.4375);

  let projectedFinishDate: string | null = null;
  let projectedFinishDateObj: Date | null = null;

  if (remaining <= 0) {
    projectedFinishDateObj = today;
    projectedFinishDate = formatYMD(today);
  } else if (rawDailyPace > 0) {
    const daysNeeded = Math.ceil(remaining / rawDailyPace);
    projectedFinishDateObj = new Date(today);
    projectedFinishDateObj.setDate(today.getDate() + daysNeeded);
    projectedFinishDate = formatYMD(projectedFinishDateObj);
  }

  let status: GoalStatus;
  if (!targetDateObj) {
    status = { type: 'noDate' };
  } else if (remaining <= 0) {
    status = { type: 'onTrack' };
  } else if (rawDailyPace <= 0) {
    const daysDiff = differenceInDays(today, targetDateObj);
    const months = daysDiff > 0 ? Math.max(1, Math.ceil(daysDiff / 30.4375)) : 1;
    status = { type: 'late', months };
  } else {
    if (projectedFinishDateObj && projectedFinishDateObj.getTime() <= targetDateObj.getTime()) {
      status = { type: 'onTrack' };
    } else {
      const daysLate = projectedFinishDateObj
        ? differenceInDays(projectedFinishDateObj, targetDateObj)
        : 30;
      const months = Math.max(1, Math.round(daysLate / 30.4375));
      status = { type: 'late', months };
    }
  }

  return {
    saved,
    percent,
    remaining,
    isCompleted,
    requiredMonthlyPace,
    realDailyPace,
    realMonthlyPace,
    projectedFinishDate,
    status,
  };
}
