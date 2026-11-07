import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { nextOccurrence, dueOccurrences } from './recurrence';

describe('recurrence golden test', () => {
  const filePath = path.resolve(__dirname, '../../../../shared/golden/recurrence.json');
  const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));

  it('has at least 6 cases', () => {
    expect(data.cases.length).toBeGreaterThanOrEqual(6);
  });

  for (const c of data.cases) {
    it(c.name, () => {
      if (c.input.type === 'dueOccurrences') {
        const result = dueOccurrences(c.input.nextDueDate, c.input.today, {
          frequency: c.input.frequency,
          dayOfMonth: c.input.dayOfMonth,
          dayOfWeek: c.input.dayOfWeek,
          monthOfYear: c.input.monthOfYear,
        });
        expect(result).toEqual(c.expected.dates);
      } else {
        const result = nextOccurrence(c.input.after, {
          frequency: c.input.frequency,
          dayOfMonth: c.input.dayOfMonth,
          dayOfWeek: c.input.dayOfWeek,
          monthOfYear: c.input.monthOfYear,
        });
        expect(result).toBe(c.expected.next);
      }
    });
  }
});
