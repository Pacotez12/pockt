import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { calculateLoanProgress } from './loan_progress';

describe('loan_progress golden test', () => {
  const filePath = path.resolve(__dirname, '../../../../shared/golden/loan_progress.json');
  const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));

  it('has at least 6 cases', () => {
    expect(data.cases.length).toBeGreaterThanOrEqual(6);
  });

  for (const c of data.cases) {
    it(c.name, () => {
      const result = calculateLoanProgress({
        loan: c.input.loan,
        schedule: c.input.schedule,
        payments: c.input.payments,
        now: c.input.now,
      });

      expect(result).toEqual(c.expected);
    });
  }
});
