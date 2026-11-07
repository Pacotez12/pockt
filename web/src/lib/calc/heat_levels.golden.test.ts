import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { heatLevels } from './heat_levels';

describe('heat_levels golden test', () => {
  const filePath = path.resolve(__dirname, '../../../../shared/golden/heat_levels.json');
  const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));

  it('has at least 6 cases', () => {
    expect(data.cases.length).toBeGreaterThanOrEqual(6);
  });

  for (const c of data.cases) {
    it(c.name, () => {
      const inputMap = new Map<number, number>();
      for (const [k, v] of Object.entries(c.input)) {
        inputMap.set(Number(k), v as number);
      }

      const result = heatLevels(inputMap);
      const resultMap: Record<string, number> = {};
      for (const [k, v] of result.entries()) {
        resultMap[k.toString()] = v;
      }

      expect(resultMap).toEqual(c.expected);
    });
  }
});
