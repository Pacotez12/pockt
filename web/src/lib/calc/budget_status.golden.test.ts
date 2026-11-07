import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { budgetStatus } from './budget_status';

describe('budget_status golden test', () => {
  const filePath = path.resolve(__dirname, '../../../../shared/golden/budget_status.json');
  const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));

  it('has at least 6 cases', () => {
    expect(data.cases.length).toBeGreaterThanOrEqual(6);
  });

  for (const c of data.cases) {
    it(c.name, () => {
      const result = budgetStatus(c.input.spent, c.input.limit, {
        warningRatio: c.input.warningRatio,
        overRatio: c.input.overRatio,
      });

      expect(result).toEqual(c.expected);
    });
  }
});
