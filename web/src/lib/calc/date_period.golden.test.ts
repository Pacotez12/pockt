import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { periodFor } from './date_period';

describe('date_period golden test', () => {
  const filePath = path.resolve(__dirname, '../../../../shared/golden/date_period.json');
  const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));

  it('has at least 6 cases', () => {
    expect(data.cases.length).toBeGreaterThanOrEqual(6);
  });

  for (const c of data.cases) {
    it(c.name, () => {
      const result = periodFor(c.input.day, {
        mode: c.input.mode,
        payDays: c.input.payDays,
        payDayRules: c.input.payDayRules,
      });

      expect(result.start).toBe(c.expected.start);
      expect(result.end).toBe(c.expected.end);
      expect(result.daysCount).toBe(c.expected.daysCount);
    });
  }
});
