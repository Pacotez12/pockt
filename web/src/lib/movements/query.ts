export interface MovementFilters {
  startDate?: number; // Unix seconds
  endDate?: number;   // Unix seconds
  categoryIds?: string[];
  categoryId?: string;
  type?: 'expense' | 'income' | 'transfer';
  minAmount?: number;
  maxAmount?: number;
  source?: 'manual' | 'recurring' | 'incomeSchedule' | 'capture';
  search?: string;
  /** Explicitly bypass date defaults if needed */
  allDates?: boolean;
}

export interface MovementQueryResult {
  sql: string;
  params: any[];
}

export function getCurrentMonthRange(now = new Date()): { start: number; end: number } {
  const start = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
  const end = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
  return {
    start: Math.floor(start.getTime() / 1000),
    end: Math.floor(end.getTime() / 1000),
  };
}

export function buildMovementsQuery(filters: MovementFilters = {}): MovementQueryResult {
  const whereClauses: string[] = ['t.deleted_at IS NULL'];
  const params: any[] = [];

  let effectiveStartDate = filters.startDate;
  let effectiveEndDate = filters.endDate;

  // By default, if neither startDate nor endDate is specified (and not allDates), filter by current month
  if (effectiveStartDate === undefined && effectiveEndDate === undefined && !filters.allDates) {
    // Only apply default if caller didn't pass explicit null/undefined to see other filters in isolation
    // But when starting fresh with default filters, use current month
    if (
      filters.categoryId === undefined &&
      filters.categoryIds === undefined &&
      filters.type === undefined &&
      filters.minAmount === undefined &&
      filters.maxAmount === undefined &&
      filters.source === undefined &&
      filters.search === undefined
    ) {
      const monthRange = getCurrentMonthRange();
      effectiveStartDate = monthRange.start;
      effectiveEndDate = monthRange.end;
    }
  }

  if (effectiveStartDate !== undefined) {
    whereClauses.push('t.occurred_at >= ?');
    params.push(effectiveStartDate);
  }

  if (effectiveEndDate !== undefined) {
    whereClauses.push('t.occurred_at <= ?');
    params.push(effectiveEndDate);
  }

  if (filters.categoryIds && filters.categoryIds.length > 0) {
    const placeholders = filters.categoryIds.map(() => '?').join(', ');
    whereClauses.push(`t.category_id IN (${placeholders})`);
    params.push(...filters.categoryIds);
  } else if (filters.categoryId) {
    whereClauses.push('t.category_id = ?');
    params.push(filters.categoryId);
  }

  if (filters.type) {
    whereClauses.push('t.type = ?');
    params.push(filters.type);
  }

  if (filters.minAmount !== undefined) {
    whereClauses.push('t.amount >= ?');
    params.push(filters.minAmount);
  }

  if (filters.maxAmount !== undefined) {
    whereClauses.push('t.amount <= ?');
    params.push(filters.maxAmount);
  }

  if (filters.source) {
    whereClauses.push('t.source = ?');
    params.push(filters.source);
  }

  if (filters.search && filters.search.trim().length > 0) {
    const searchVal = `%${filters.search.trim().toLowerCase()}%`;
    whereClauses.push('(LOWER(t.merchant) LIKE ? OR LOWER(t.note) LIKE ?)');
    params.push(searchVal, searchVal);
  }

  const whereString = whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';

  const sql = `SELECT 
  t.id, t.type, t.amount, t.currency, t.category_id, t.merchant, t.note,
  t.occurred_at, t.created_at, t.updated_at, t.source, t.recurring_rule_id,
  t.suggestion_id, t.loan_id, t.is_extra, t.event_id,
  c.name as category_name, c.color_dark as category_color_dark, c.color_light as category_color_light,
  c.icon as category_icon
FROM transactions t
LEFT JOIN categories c ON t.category_id = c.id
${whereString}
ORDER BY t.occurred_at DESC`;

  return { sql, params };
}

export function periodTotals(rows: Array<{ type: string; amount: number }>): {
  count: number;
  spent: number;
  earned: number;
} {
  let spent = 0;
  let earned = 0;

  for (const row of rows) {
    if (row.type === 'expense') {
      spent += Math.abs(row.amount);
    } else if (row.type === 'income') {
      earned += Math.abs(row.amount);
    }
  }

  return {
    count: rows.length,
    spent,
    earned,
  };
}
