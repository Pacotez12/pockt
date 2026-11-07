import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { calculateGoalProgress } from './goal_progress';

describe('goal_progress golden test', () => {
  const filePath = path.resolve(__dirname, '../../../../shared/golden/goal_progress.json');
  const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));

  it('has at least 6 cases', () => {
    expect(data.cases.length).toBeGreaterThanOrEqual(6);
  });

  for (const c of data.cases) {
    it(c.name, () => {
      const result = calculateGoalProgress({
        goal: c.input.goal,
        contributions: c.input.contributions,
        now: c.input.now,
      });

      expect(result).toEqual(c.expected);
    });
  }
});
