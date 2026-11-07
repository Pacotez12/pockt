import { describe, it, expect } from 'vitest';
import { calculateMonthExpenses } from './calculations';

describe('calculateMonthExpenses', () => {
  it('sums only expense transactions within the specified calendar month and ignores deleted ones', () => {
    // October 2026: year 2026, month 10
    const oct1 = Math.floor(new Date(2026, 9, 1, 10, 0).getTime() / 1000);
    const oct15 = Math.floor(new Date(2026, 9, 15, 14, 30).getTime() / 1000);
    const oct31 = Math.floor(new Date(2026, 9, 31, 23, 59).getTime() / 1000);
    const sep30 = Math.floor(new Date(2026, 8, 30, 23, 59).getTime() / 1000);
    const nov1 = Math.floor(new Date(2026, 10, 1, 0, 1).getTime() / 1000);

    const testTransactions = [
      // Valid October expenses
      { type: 'expense', amount: 50000, occurred_at: oct1, deleted_at: null },
      { type: 'expense', amount: 150000, occurred_at: oct15, deleted_at: null },
      { type: 'expense', amount: 20000, occurred_at: oct31, deleted_at: null },

      // Income in October (should be excluded)
      { type: 'income', amount: 3000000, occurred_at: oct15, deleted_at: null },

      // Soft-deleted expense in October (should be excluded)
      { type: 'expense', amount: 80000, occurred_at: oct15, deleted_at: oct15 + 100 },

      // Expenses in adjacent months (should be excluded)
      { type: 'expense', amount: 40000, occurred_at: sep30, deleted_at: null },
      { type: 'expense', amount: 90000, occurred_at: nov1, deleted_at: null },
    ];

    const total = calculateMonthExpenses(testTransactions, 2026, 10);
    expect(total).toBe(220000); // 50000 + 150000 + 20000
  });

  it('returns 0 when there are no transactions in the month', () => {
    const total = calculateMonthExpenses([], 2026, 10);
    expect(total).toBe(0);
  });
});
