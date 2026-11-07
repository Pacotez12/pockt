/**
 * reports.ts
 * Port of lib/features/reports/domain/compare.dart,
 * lib/features/reports/domain/ant_expenses.dart,
 * and lib/features/reports/domain/weekly_summary.dart.
 */

export function normalizeKeyword(text: string): string {
  let s = text.trim().toLowerCase();
  s = s.replace(/[áàäâ]/g, 'a');
  s = s.replace(/[éèëê]/g, 'e');
  s = s.replace(/[íìïî]/g, 'i');
  s = s.replace(/[óòöô]/g, 'o');
  s = s.replace(/[úùüû]/g, 'u');
  return s;
}

function daysInMonth(year: number, month: number): number {
  return new Date(year, month, 0).getDate();
}

function parseYMD(s: string): { year: number; month: number; day: number } {
  const parts = s.split('T')[0].split('-').map(Number);
  return { year: parts[0], month: parts[1], day: parts[2] };
}

// 1. Comparison
export interface ComparisonResult {
  current: number;
  previous: number;
  changePct: number | null;
}

export function compareToPreviousMonth({
  today,
  dailyExpenseByLocalDay,
}: {
  today: string | Date;
  dailyExpenseByLocalDay: Record<string, number>;
}): ComparisonResult {
  const todayYMD = typeof today === 'string' ? parseYMD(today) : {
    year: today.getFullYear(),
    month: today.getMonth() + 1,
    day: today.getDate(),
  };

  const curYear = todayYMD.year;
  const curMonth = todayYMD.month;
  const curDay = todayYMD.day;

  const prevYear = curMonth === 1 ? curYear - 1 : curYear;
  const prevMonth = curMonth === 1 ? 12 : curMonth - 1;
  const daysInPrev = daysInMonth(prevYear, prevMonth);
  const prevTargetDay = Math.min(curDay, daysInPrev);

  const normalizedMap = new Map<string, number>();
  for (const [dateStr, amount] of Object.entries(dailyExpenseByLocalDay)) {
    const ymd = parseYMD(dateStr);
    const key = `${ymd.year}-${ymd.month}-${ymd.day}`;
    normalizedMap.set(key, (normalizedMap.get(key) ?? 0) + amount);
  }

  let currentTotal = 0;
  for (let d = 1; d <= curDay; d++) {
    currentTotal += normalizedMap.get(`${curYear}-${curMonth}-${d}`) ?? 0;
  }

  let previousTotal = 0;
  for (let d = 1; d <= prevTargetDay; d++) {
    previousTotal += normalizedMap.get(`${prevYear}-${prevMonth}-${d}`) ?? 0;
  }

  let changePct: number | null = null;
  if (previousTotal > 0) {
    const raw = ((currentTotal - previousTotal) / previousTotal) * 100.0;
    changePct = Math.round(raw * 10) / 10;
  }

  return {
    current: currentTotal,
    previous: previousTotal,
    changePct,
  };
}

// 2. Ant Expenses
export interface AntExpenseTxInput {
  id: string;
  type: string;
  amount: number;
  merchant?: string | null;
  category: string;
}

export interface AntExpenseGroupResult {
  name: string;
  merchant: string | null;
  categoryName: string;
  total: number;
  count: number;
  average: number;
}

export interface AntExpensesSummaryResult {
  total: number;
  count: number;
  annualProjection: number;
  threshold: number;
  groups: AntExpenseGroupResult[];
}

const CATEGORY_NAMES: Record<string, string> = {
  c_comida: 'Comida',
  c_cafes: 'Cafés y meriendas',
  c_transp: 'Transporte',
};

export function calculateAntExpenses({
  transactions,
  threshold = 30000,
}: {
  transactions: AntExpenseTxInput[];
  threshold?: number;
}): AntExpensesSummaryResult {
  let grandTotal = 0;
  let grandCount = 0;

  interface Accumulator {
    total: number;
    count: number;
    merchantSpellings: Map<string, number>;
    fallbackCategoryName: string;
  }

  const map = new Map<string, Accumulator>();

  for (const tx of transactions) {
    if (tx.type !== 'expense' || tx.amount > threshold) {
      continue;
    }

    grandTotal += tx.amount;
    grandCount += 1;

    const rawMerchant = tx.merchant?.trim();
    const hasMerchant = rawMerchant != null && rawMerchant.length > 0;

    let groupKey: string;
    if (hasMerchant) {
      groupKey = `m_${normalizeKeyword(rawMerchant)}`;
    } else {
      groupKey = `c_${tx.category}`;
    }

    let acc = map.get(groupKey);
    if (!acc) {
      const catName = CATEGORY_NAMES[tx.category] ?? tx.category;
      acc = {
        total: 0,
        count: 0,
        merchantSpellings: new Map(),
        fallbackCategoryName: catName,
      };
      map.set(groupKey, acc);
    }

    acc.total += tx.amount;
    acc.count += 1;

    if (hasMerchant) {
      acc.merchantSpellings.set(rawMerchant, (acc.merchantSpellings.get(rawMerchant) ?? 0) + 1);
    }
  }

  const groups: AntExpenseGroupResult[] = [];
  for (const [key, acc] of map.entries()) {
    const isMerchant = key.startsWith('m_');
    let displayName: string;
    let merchant: string | null = null;

    if (isMerchant && acc.merchantSpellings.size > 0) {
      let bestSpelling = '';
      let bestCount = -1;
      for (const [s, count] of acc.merchantSpellings.entries()) {
        if (count > bestCount) {
          bestCount = count;
          bestSpelling = s;
        }
      }
      displayName = bestSpelling;
      merchant = bestSpelling;
    } else {
      displayName = acc.fallbackCategoryName;
    }

    const average = acc.count > 0 ? Math.floor(acc.total / acc.count) : 0;
    groups.push({
      name: displayName,
      merchant,
      categoryName: acc.fallbackCategoryName,
      total: acc.total,
      count: acc.count,
      average,
    });
  }

  groups.sort((a, b) => {
    const cmp = b.total - a.total;
    if (cmp !== 0) return cmp;
    return b.count - a.count;
  });

  return {
    total: grandTotal,
    count: grandCount,
    annualProjection: grandTotal * 12,
    threshold,
    groups,
  };
}

// 3. Weekly Summary
export interface WeeklySummaryTxInput {
  id: string;
  type: string;
  amount: number;
  category: string;
}

export interface WeeklySummaryResult {
  currentWeekTotal: number;
  previousWeekTotal: number;
  percentageDiff: number | null;
  topCategoryName: string | null;
  topCategoryAmount: number;
}

export function calculateWeeklySummary({
  currentWeekTxs,
  previousWeekTxs,
}: {
  currentWeekTxs: WeeklySummaryTxInput[];
  previousWeekTxs: WeeklySummaryTxInput[];
  weekStart?: string;
  weekEnd?: string;
}): WeeklySummaryResult {
  let curTotal = 0;
  const catTotals = new Map<string, number>();

  for (const item of currentWeekTxs) {
    if (item.type !== 'expense') continue;
    curTotal += item.amount;
    catTotals.set(item.category, (catTotals.get(item.category) ?? 0) + item.amount);
  }

  let prevTotal = 0;
  for (const item of previousWeekTxs) {
    if (item.type !== 'expense') continue;
    prevTotal += item.amount;
  }

  let percentageDiff: number | null = null;
  if (prevTotal > 0) {
    percentageDiff = Math.round(((curTotal - prevTotal) / prevTotal) * 100);
  } else if (curTotal > 0) {
    percentageDiff = null;
  } else {
    percentageDiff = 0;
  }

  let topCat: string | null = null;
  let topAmount = 0;
  for (const [catId, amount] of catTotals.entries()) {
    if (amount > topAmount) {
      topAmount = amount;
      topCat = CATEGORY_NAMES[catId] ?? catId;
    }
  }

  return {
    currentWeekTotal: curTotal,
    previousWeekTotal: prevTotal,
    percentageDiff,
    topCategoryName: topCat,
    topCategoryAmount: topAmount,
  };
}
