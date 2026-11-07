import { describe, it, expect } from 'vitest';
import {
  calculateCategoryMonthlyTrend,
  formatNetSavingsSubtitle,
  buildMonotoneCubicPath,
} from './reports';

describe('calculateCategoryMonthlyTrend', () => {
  const refDate = new Date('2026-10-31T23:59:59');

  it('computes 6-month spending series for top 3 categories with real data', () => {
    // Months: May (4), Jun (5), Jul (6), Aug (7), Sep (8), Oct (9)
    const txs = [
      // Comida in May, Jun, Oct
      { type: 'expense', amount: 100000, occurred_at: Math.floor(new Date('2026-05-10').getTime() / 1000), category_id: 'c1', category_name: 'Comida', color_dark: 0xffe4a067 },
      { type: 'expense', amount: 200000, occurred_at: Math.floor(new Date('2026-06-15').getTime() / 1000), category_id: 'c1', category_name: 'Comida', color_dark: 0xffe4a067 },
      { type: 'expense', amount: 300000, occurred_at: Math.floor(new Date('2026-10-20').getTime() / 1000), category_id: 'c1', category_name: 'Comida', color_dark: 0xffe4a067 },

      // Transporte in Jun, Sep
      { type: 'expense', amount: 80000, occurred_at: Math.floor(new Date('2026-06-05').getTime() / 1000), category_id: 'c2', category_name: 'Transporte', color_dark: 0xff6bbaf0 },
      { type: 'expense', amount: 120000, occurred_at: Math.floor(new Date('2026-09-12').getTime() / 1000), category_id: 'c2', category_name: 'Transporte', color_dark: 0xff6bbaf0 },

      // Servicios in Jul, Aug
      { type: 'expense', amount: 50000, occurred_at: Math.floor(new Date('2026-07-01T12:00:00').getTime() / 1000), category_id: 'c3', category_name: 'Servicios', color_dark: 0xff8fb0f8 },
      { type: 'expense', amount: 70000, occurred_at: Math.floor(new Date('2026-08-01T12:00:00').getTime() / 1000), category_id: 'c3', category_name: 'Servicios', color_dark: 0xff8fb0f8 },

      // Ocio in Oct (lower total than top 3, so shouldn't be in top 3)
      { type: 'expense', amount: 30000, occurred_at: Math.floor(new Date('2026-10-05').getTime() / 1000), category_id: 'c4', category_name: 'Ocio', color_dark: 0xffc19fe9 },

      // Income (should be ignored)
      { type: 'income', amount: 5000000, occurred_at: Math.floor(new Date('2026-10-01').getTime() / 1000), category_id: 'c_inc', category_name: 'Salario' },

      // Old transaction outside 6-month window (April 2026 - should be ignored)
      { type: 'expense', amount: 999999, occurred_at: Math.floor(new Date('2026-04-30').getTime() / 1000), category_id: 'c1', category_name: 'Comida' },
    ];

    const result = calculateCategoryMonthlyTrend({
      transactions: txs as any,
      referenceDate: refDate,
      monthsCount: 6,
    });

    expect(result.hasData).toBe(true);
    expect(result.months).toHaveLength(6);
    expect(result.series).toHaveLength(3);

    // Top 3 should be Comida (600k), Transporte (200k), Servicios (120k)
    expect(result.series[0].categoryName).toBe('Comida');
    expect(result.series[0].total).toBe(600000);
    expect(result.series[0].points).toEqual([100000, 200000, 0, 0, 0, 300000]);

    expect(result.series[1].categoryName).toBe('Transporte');
    expect(result.series[1].total).toBe(200000);
    expect(result.series[1].points).toEqual([0, 80000, 0, 0, 120000, 0]);

    expect(result.series[2].categoryName).toBe('Servicios');
    expect(result.series[2].total).toBe(120000);
    expect(result.series[2].points).toEqual([0, 0, 50000, 70000, 0, 0]);
  });

  it('returns hasData=false if there are no expense transactions in the 6 months', () => {
    const result = calculateCategoryMonthlyTrend({
      transactions: [],
      referenceDate: refDate,
      monthsCount: 6,
    });

    expect(result.hasData).toBe(false);
    expect(result.series).toHaveLength(0);
  });

  it('generates 6 months ending in chosen reference month without future months (e.g. Nov -> jun..nov)', () => {
    // Current date is in November (month 10)
    const novRef = new Date(2026, 10, 15);
    const result = calculateCategoryMonthlyTrend({
      transactions: [],
      referenceDate: novRef,
      monthsCount: 6,
    });

    const monthLabels = result.months.map((m) => m.label);
    expect(monthLabels).toEqual(['jun', 'jul', 'ago', 'sep', 'oct', 'nov']);
    expect(monthLabels).not.toContain('dic');
  });
});

describe('buildMonotoneCubicPath', () => {
  it('generates a monotone SVG path that never dips below baseline y on zero points', () => {
    // Simulation: baseline is y=120 (amount 0). Peaks go towards y=20.
    // Points: Jun (120), Jul (30), Ago (120), Sep (120), Oct (40), Nov (120)
    const points = [
      { x: 30, y: 120 },
      { x: 138, y: 30 },
      { x: 246, y: 120 },
      { x: 354, y: 120 },
      { x: 462, y: 40 },
      { x: 570, y: 120 },
    ];

    const path = buildMonotoneCubicPath(points, { baselineY: 120, topY: 20 });
    expect(path).toMatch(/^M 30/);

    // Extract all numbers after C or in path to check no Y coordinate exceeds 120 or goes under 20
    const matches = path.match(/[-+]?[0-9]*\.?[0-9]+/g);
    expect(matches).not.toBeNull();
    const nums = matches!.map(Number);
    // In "M x y C cp1x cp1y cp2x cp2y x2 y2 ...", y coords are at index 1, 3, 5, 7, 9, 11, etc.
    const yValues: number[] = [nums[1]];
    for (let i = 2; i < nums.length; i += 6) {
      yValues.push(nums[i + 1]); // cp1y
      yValues.push(nums[i + 3]); // cp2y
      yValues.push(nums[i + 5]); // end y
    }

    // Monotonicity assertion: no control point should exceed baseline (120) or peak (20)
    for (const y of yValues) {
      expect(y).toBeLessThanOrEqual(120.01);
      expect(y).toBeGreaterThanOrEqual(19.99);
    }
  });

  it('handles empty or single point lists safely', () => {
    expect(buildMonotoneCubicPath([])).toBe('');
    expect(buildMonotoneCubicPath([{ x: 10, y: 20 }])).toBe('M 10.0 20.0');
  });
});

describe('formatNetSavingsSubtitle', () => {
  it('formats positive savings percentage of income', () => {
    // Saved 2.000.000 of 6.000.000 -> 33%
    const text = formatNetSavingsSubtitle(2000000, 6000000);
    expect(text).toBe('33 % de lo que entró');
  });

  it('formats negative savings as "Gastaste Gs. X más de lo que entró"', () => {
    // Income 5.000.000, Expenses 6.500.000 -> Net -1.500.000
    const text = formatNetSavingsSubtitle(-1500000, 5000000);
    expect(text).toBe('Gastaste Gs. 1.500.000 más de lo que entró');
  });

  it('formats negative savings when there were 0 incomes', () => {
    // Net -800.000, Income 0
    const text = formatNetSavingsSubtitle(-800000, 0);
    expect(text).toBe('Gastaste Gs. 800.000 sin ingresos');
  });

  it('handles 0 savings and 0 income', () => {
    const text = formatNetSavingsSubtitle(0, 0);
    expect(text).toBe('Sin ingresos registrados');
  });
});
