import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import {
  compareToPreviousMonth,
  calculateAntExpenses,
  calculateWeeklySummary,
} from './reports';

describe('reports golden test', () => {
  const filePath = path.resolve(__dirname, '../../../../shared/golden/reports.json');
  const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));

  it('has at least 6 cases', () => {
    expect(data.cases.length).toBeGreaterThanOrEqual(6);
  });

  for (const c of data.cases) {
    it(c.name, () => {
      if (c.type === 'comparison') {
        const result = compareToPreviousMonth({
          today: c.input.today,
          dailyExpenseByLocalDay: c.input.dailyExpenseByLocalDay,
        });
        expect(result).toEqual(c.expected);
      } else if (c.type === 'ant_expenses') {
        const result = calculateAntExpenses({
          transactions: c.input.transactions,
          threshold: c.input.threshold,
        });
        expect(result).toEqual(c.expected);
      } else if (c.type === 'weekly_summary') {
        const result = calculateWeeklySummary({
          currentWeekTxs: c.input.currentWeekTxs,
          previousWeekTxs: c.input.previousWeekTxs,
          weekStart: c.input.weekStart,
          weekEnd: c.input.weekEnd,
        });
        expect(result).toEqual(c.expected);
      }
    });
  }
});
