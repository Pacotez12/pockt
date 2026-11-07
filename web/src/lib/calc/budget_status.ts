/**
 * budget_status.ts
 * Port of lib/features/budgets/domain/budget_status.dart
 */

export type BudgetLevel = 'ok' | 'warning' | 'over';

export interface BudgetStatusResult {
  level: BudgetLevel;
  ratio: number;
  remaining: number;
}

export function budgetStatus(
  spent: number,
  limit: number,
  options?: {
    warningRatio?: number;
    overRatio?: number;
  },
): BudgetStatusResult {
  const warningRatio = options?.warningRatio ?? 0.8;
  const overRatio = options?.overRatio ?? 1.0;

  const rawRatio = limit > 0 ? spent / limit : (spent > 0 ? 1.0 : 0.0);
  const ratio = Math.round(rawRatio * 1000) / 1000;
  const remaining = limit - spent;

  let level: BudgetLevel;
  if (rawRatio >= overRatio) {
    level = 'over';
  } else if (rawRatio >= warningRatio) {
    level = 'warning';
  } else {
    level = 'ok';
  }

  return {
    level,
    ratio,
    remaining,
  };
}
