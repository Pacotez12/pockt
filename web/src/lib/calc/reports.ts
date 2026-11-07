/**
 * reports.ts
 * Port of lib/features/reports/domain/compare.dart,
 * lib/features/reports/domain/ant_expenses.dart,
 * and lib/features/reports/domain/weekly_summary.dart.
 */

import { formatThousands } from '../format';

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

const SHORT_MONTHS_ES = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

export interface CategoryTrendTx {
  type: string;
  amount: number;
  occurred_at: number;
  category_id?: string | null;
  category_name?: string | null;
  color_dark?: number | string | null;
  color_light?: number | string | null;
}

export interface CategoryTrendSeries {
  categoryId: string;
  categoryName: string;
  colorDark?: number | string | null;
  colorLight?: number | string | null;
  points: number[];
  total: number;
}

export interface CategoryTrendResult {
  hasData: boolean;
  months: Array<{ key: string; label: string; year: number; month: number }>;
  series: CategoryTrendSeries[];
  maxAmount: number;
}

export function calculateCategoryMonthlyTrend({
  transactions,
  referenceDate = new Date(),
  monthsCount = 6,
}: {
  transactions: CategoryTrendTx[];
  referenceDate?: Date;
  monthsCount?: number;
}): CategoryTrendResult {
  const refYear = referenceDate.getFullYear();
  const refMonth = referenceDate.getMonth();

  const months: Array<{ key: string; label: string; year: number; month: number }> = [];
  const monthKeyToIndex = new Map<string, number>();

  for (let i = monthsCount - 1; i >= 0; i--) {
    const totalMonthIndex = refYear * 12 + refMonth - i;
    const y = Math.floor(totalMonthIndex / 12);
    const m = ((totalMonthIndex % 12) + 12) % 12;
    const padM = String(m + 1).padStart(2, '0');
    const key = `${y}-${padM}`;
    monthKeyToIndex.set(key, months.length);
    months.push({
      key,
      label: SHORT_MONTHS_ES[m],
      year: y,
      month: m,
    });
  }

  interface CatBucket {
    id: string;
    name: string;
    colorDark?: number | string | null;
    colorLight?: number | string | null;
    points: number[];
    total: number;
  }

  const catBuckets = new Map<string, CatBucket>();

  for (const tx of transactions) {
    if (tx.type !== 'expense') continue;
    const ms = tx.occurred_at > 1e11 ? tx.occurred_at : tx.occurred_at * 1000;
    const d = new Date(ms);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    const monthIdx = monthKeyToIndex.get(key);
    if (monthIdx === undefined) continue;

    const catId = tx.category_id || tx.category_name || 'otros';
    const catName = tx.category_name || 'Otros';

    let bucket = catBuckets.get(catId);
    if (!bucket) {
      bucket = {
        id: catId,
        name: catName,
        colorDark: tx.color_dark,
        colorLight: tx.color_light,
        points: new Array(monthsCount).fill(0),
        total: 0,
      };
      catBuckets.set(catId, bucket);
    }

    bucket.points[monthIdx] += tx.amount;
    bucket.total += tx.amount;
  }

  const sorted = Array.from(catBuckets.values())
    .filter((b) => b.total > 0)
    .sort((a, b) => b.total - a.total)
    .slice(0, 3);

  if (sorted.length === 0) {
    return {
      hasData: false,
      months,
      series: [],
      maxAmount: 0,
    };
  }

  let maxAmount = 1;
  const series: CategoryTrendSeries[] = sorted.map((s) => {
    for (const p of s.points) {
      if (p > maxAmount) maxAmount = p;
    }
    return {
      categoryId: s.id,
      categoryName: s.name,
      colorDark: s.colorDark,
      colorLight: s.colorLight,
      points: s.points,
      total: s.total,
    };
  });

  return {
    hasData: true,
    months,
    series,
    maxAmount,
  };
}

export function formatNetSavingsSubtitle(netSavings: number, totalIncome: number): string {
  if (netSavings < 0) {
    if (totalIncome > 0) {
      return `Gastaste Gs. ${formatThousands(Math.abs(netSavings))} más de lo que entró`;
    }
    return `Gastaste Gs. ${formatThousands(Math.abs(netSavings))} sin ingresos`;
  }
  if (totalIncome > 0) {
    const pct = Math.round((netSavings / totalIncome) * 100);
    return `${pct} % de lo que entró`;
  }
  return 'Sin ingresos registrados';
}

export interface Point2D {
  x: number;
  y: number;
}

export interface MonotoneCubicOptions {
  baselineY?: number;
  topY?: number;
}

export function buildMonotoneCubicPath(
  points: Point2D[],
  options?: MonotoneCubicOptions
): string {
  const n = points.length;
  if (n === 0) return '';
  if (n === 1) return `M ${points[0].x.toFixed(1)} ${points[0].y.toFixed(1)}`;
  if (n === 2) {
    return `M ${points[0].x.toFixed(1)} ${points[0].y.toFixed(1)} L ${points[1].x.toFixed(1)} ${points[1].y.toFixed(1)}`;
  }

  const { baselineY, topY } = options || {};

  // Step 1: calculate secants (slopes) between consecutive points
  const dx: number[] = [];
  const dy: number[] = [];
  const s: number[] = [];
  for (let i = 0; i < n - 1; i++) {
    const dX = points[i + 1].x - points[i].x;
    const dY = points[i + 1].y - points[i].y;
    dx.push(dX);
    dy.push(dY);
    s.push(dX === 0 ? 0 : dY / dX);
  }

  // Step 2: initial tangents (slopes) at each point
  const m: number[] = new Array(n).fill(0);
  m[0] = s[0];
  m[n - 1] = s[n - 2];
  for (let i = 1; i < n - 1; i++) {
    if (s[i - 1] * s[i] <= 0) {
      m[i] = 0; // Local extremum: flat tangent
    } else {
      // Harmonic mean (Fritsch-Butland / Steffen)
      m[i] = (2 * s[i - 1] * s[i]) / (s[i - 1] + s[i]);
    }
  }

  // Step 3: Fritsch-Carlson constraint adjustment
  for (let i = 0; i < n - 1; i++) {
    if (s[i] === 0) {
      m[i] = 0;
      m[i + 1] = 0;
    } else {
      const alpha = m[i] / s[i];
      const beta = m[i + 1] / s[i];
      if (alpha < 0) m[i] = 0;
      if (beta < 0) m[i + 1] = 0;
      const hyp = alpha * alpha + beta * beta;
      if (hyp > 9) {
        const tau = 3 / Math.sqrt(hyp);
        m[i] = tau * alpha * s[i];
        m[i + 1] = tau * beta * s[i];
      }
    }
  }

  // Step 4: generate cubic Bezier control points and path
  let path = `M ${points[0].x.toFixed(1)} ${points[0].y.toFixed(1)}`;
  for (let i = 0; i < n - 1; i++) {
    const p1 = points[i];
    const p2 = points[i + 1];
    const segDx = dx[i];

    let cp1x = p1.x + segDx / 3;
    let cp1y = p1.y + (m[i] * segDx) / 3;
    let cp2x = p2.x - segDx / 3;
    let cp2y = p2.y - (m[i + 1] * segDx) / 3;

    // Strict boundary clamping if provided
    if (baselineY != null) {
      cp1y = Math.min(cp1y, baselineY);
      cp2y = Math.min(cp2y, baselineY);
    }
    if (topY != null) {
      cp1y = Math.max(cp1y, topY);
      cp2y = Math.max(cp2y, topY);
    }

    path += ` C ${cp1x.toFixed(1)} ${cp1y.toFixed(1)}, ${cp2x.toFixed(1)} ${cp2y.toFixed(1)}, ${p2.x.toFixed(1)} ${p2.y.toFixed(1)}`;
  }

  return path;
}
