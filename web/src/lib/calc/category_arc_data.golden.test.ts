import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { buildCategoryArcSegments } from './category_arc_data';

describe('category_arc_data golden test', () => {
  const filePath = path.resolve(__dirname, '../../../../shared/golden/category_arc_data.json');
  const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));

  it('has at least 6 cases', () => {
    expect(data.cases.length).toBeGreaterThanOrEqual(6);
  });

  for (const c of data.cases) {
    it(c.name, () => {
      const result = buildCategoryArcSegments(c.input);
      expect(result).toEqual(c.expected);
    });
  }
});
