import { describe, it, expect } from 'vitest';
import { buildMovementsQuery, periodTotals } from './query';

describe('buildMovementsQuery', () => {
  it('builds default query with deleted_at IS NULL, calendar month range, join categories, ordered by occurred_at desc', () => {
    const { sql, params } = buildMovementsQuery({
      startDate: 1727740800, // 2024-10-01 00:00:00
      endDate: 1730419199,   // 2024-10-31 23:59:59
    });

    expect(sql).toContain('FROM transactions t');
    expect(sql).toContain('LEFT JOIN categories c ON t.category_id = c.id');
    expect(sql).toContain('t.deleted_at IS NULL');
    expect(sql).toContain('t.occurred_at >= ?');
    expect(sql).toContain('t.occurred_at <= ?');
    expect(sql).toContain('ORDER BY t.occurred_at DESC');
    expect(params).toEqual([1727740800, 1730419199]);
  });

  it('filters by categoryId', () => {
    const { sql, params } = buildMovementsQuery({
      categoryId: 'cat-food',
    });

    expect(sql).toContain('t.category_id = ?');
    expect(params).toContain('cat-food');
  });

  it('filters by multiple categoryIds', () => {
    const { sql, params } = buildMovementsQuery({
      categoryIds: ['cat-food', 'cat-fun'],
    });

    expect(sql).toContain('t.category_id IN (?, ?)');
    expect(params).toContain('cat-food');
    expect(params).toContain('cat-fun');
  });

  it('filters by type (expense, income, transfer)', () => {
    const { sql, params } = buildMovementsQuery({
      type: 'expense',
    });

    expect(sql).toContain('t.type = ?');
    expect(params).toContain('expense');
  });

  it('filters by min and max amount', () => {
    const { sql, params } = buildMovementsQuery({
      minAmount: 10000,
      maxAmount: 500000,
    });

    expect(sql).toContain('t.amount >= ?');
    expect(sql).toContain('t.amount <= ?');
    expect(params).toContain(10000);
    expect(params).toContain(500000);
  });

  it('filters by source (manual, recurring, incomeSchedule, capture)', () => {
    const { sql, params } = buildMovementsQuery({
      source: 'recurring',
    });

    expect(sql).toContain('t.source = ?');
    expect(params).toContain('recurring');
  });

  it('filters by text search in merchant or note (case and accent insensitive)', () => {
    const { sql, params } = buildMovementsQuery({
      search: 'super',
    });

    expect(sql).toContain('(LOWER(t.merchant) LIKE ? OR LOWER(t.note) LIKE ?)');
    expect(params).toContain('%super%');
  });

  it('combines multiple filters correctly', () => {
    const { sql, params } = buildMovementsQuery({
      startDate: 1700000000,
      endDate: 1700500000,
      type: 'expense',
      categoryId: 'cat-1',
      minAmount: 5000,
      source: 'manual',
      search: 'compra',
    });

    expect(sql).toContain('t.deleted_at IS NULL');
    expect(sql).toContain('t.occurred_at >= ?');
    expect(sql).toContain('t.occurred_at <= ?');
    expect(sql).toContain('t.type = ?');
    expect(sql).toContain('t.category_id = ?');
    expect(sql).toContain('t.amount >= ?');
    expect(sql).toContain('t.source = ?');
    expect(sql).toContain('(LOWER(t.merchant) LIKE ? OR LOWER(t.note) LIKE ?)');
    expect(params).toEqual([
      1700000000,
      1700500000,
      'cat-1',
      'expense',
      5000,
      'manual',
      '%compra%',
      '%compra%',
    ]);
  });
});

describe('periodTotals', () => {
  it('calculates count, spent, and earned correctly, excluding transfers from totals', () => {
    const rows = [
      { type: 'expense', amount: 184000 },
      { type: 'expense', amount: 28500 },
      { type: 'income', amount: 3000000 },
      { type: 'transfer', amount: 500000 },
    ];

    const totals = periodTotals(rows);

    expect(totals).toEqual({
      count: 4,
      spent: 212500,
      earned: 3000000,
    });
  });

  it('returns zeroes for empty rows', () => {
    expect(periodTotals([])).toEqual({
      count: 0,
      spent: 0,
      earned: 0,
    });
  });
});
