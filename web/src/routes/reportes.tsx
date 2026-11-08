import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useQuery, usePowerSync } from '@powersync/react';
import { Download } from 'lucide-react';
import { formatGs, formatThousands } from '@/lib/format';
import { CountUp } from '@/components/CountUp';
import { Skeleton } from '@/components/Skeleton';
import { TusDias, type DayData } from '@/components/reports/TusDias';
import { DayDetailPanel, type DayDetailTransaction } from '@/components/reports/DayDetailPanel';
import { MovementPanel } from '@/components/movements/MovementPanel';
import {
  calculateAntExpenses,
  calculateCategoryMonthlyTrend,
  formatNetSavingsSubtitle,
  buildMonotoneCubicPath,
} from '@/lib/calc/reports';
import { toCsv, toXlsx, downloadBlob, type MovementExportRow } from '@/lib/movements/export';
import { generateReportPdf, type ReportPdfData } from '@/lib/reports/pdf';
import { useTheme } from '@/lib/theme';
import { cn } from '@/lib/utils';

interface TxRow {
  id: string;
  type: string;
  amount: number;
  occurred_at: number;
  merchant?: string | null;
  note?: string | null;
  category_id?: string | null;
  category_name?: string | null;
  color_dark?: number | string | null;
  color_light?: number | string | null;
  loan_id?: string | null;
  source?: string | null;
}

interface RecurringRow {
  id: string;
  amount: number;
  frequency: string;
  active: number;
}

const MONTH_NAMES = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'setiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

function parseHexColor(colorInt: number | string | null | undefined): string {
  if (colorInt == null) return '#E4A067';
  if (typeof colorInt === 'string' && colorInt.startsWith('#')) return colorInt;
  if (typeof colorInt === 'number') {
    const rgb = colorInt & 0x00ffffff;
    return `#${rgb.toString(16).padStart(6, '0')}`;
  }
  return '#E4A067';
}



export function ReportesRoute() {
  const db = usePowerSync();
  const { resolvedTheme } = useTheme();
  const [searchParams, setSearchParams] = useSearchParams();
  const periodParam = (searchParams.get('period') as 'mes' | 'ano' | 'custom') || 'mes';

  const [isGeneratingPdf, setIsGeneratingPdf] = useState<boolean>(false);
  const [selectedTxId, setSelectedTxId] = useState<string | null>(null);
  const [selectedDay, setSelectedDay] = useState<DayData | null>(null);

  useEffect(() => {
    document.title = 'Reportes · Pockt';
  }, []);

  const now = useMemo(() => new Date(), []);
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth();

  const selectedYear = parseInt(searchParams.get('year') || String(currentYear), 10);
  const selectedMonth = parseInt(searchParams.get('month') || String(currentMonth + 1), 10) - 1;

  const customFrom = searchParams.get('from') || '';
  const customTo = searchParams.get('to') || '';

  const { startSec, endSec, periodLabel } = useMemo(() => {
    if (periodParam === 'ano') {
      const start = new Date(selectedYear, 0, 1, 0, 0, 0);
      const end = new Date(selectedYear, 11, 31, 23, 59, 59);
      return {
        startSec: Math.floor(start.getTime() / 1000),
        endSec: Math.floor(end.getTime() / 1000) + 1,
        periodLabel: `${selectedYear}`,
      };
    }

    if (periodParam === 'custom' && customFrom && customTo) {
      const start = new Date(`${customFrom}T00:00:00`);
      const end = new Date(`${customTo}T23:59:59`);
      return {
        startSec: Math.floor(start.getTime() / 1000),
        endSec: Math.floor(end.getTime() / 1000) + 1,
        periodLabel: `${customFrom} a ${customTo}`,
      };
    }

    // Default: 'mes'
    const start = new Date(selectedYear, selectedMonth, 1, 0, 0, 0);
    const end = new Date(selectedYear, selectedMonth + 1, 0, 23, 59, 59);
    const mName = MONTH_NAMES[selectedMonth] || 'este mes';
    return {
      startSec: Math.floor(start.getTime() / 1000),
      endSec: Math.floor(end.getTime() / 1000) + 1,
      periodLabel: `${mName} ${selectedYear}`,
    };
  }, [periodParam, selectedYear, selectedMonth, customFrom, customTo]);

  // Query transactions: span either 182 days or the selected range, whichever starts earlier
  const sixMonthsAgoSec = useMemo(
    () => Math.floor((Date.now() - 182 * 86400 * 1000) / 1000),
    []
  );
  const queryStartSec = useMemo(
    () => Math.min(startSec, sixMonthsAgoSec),
    [startSec, sixMonthsAgoSec]
  );

  const { data: rawTxs, isLoading: loadingTxs } = useQuery<TxRow>(
    `SELECT t.id, t.type, t.amount, t.occurred_at, t.merchant, t.note, t.loan_id, t.source,
            t.category_id, c.name as category_name, c.color_dark, c.color_light
     FROM transactions t
     LEFT JOIN categories c ON t.category_id = c.id
     WHERE t.deleted_at IS NULL AND t.occurred_at >= ? AND t.occurred_at <= ?
     ORDER BY t.occurred_at DESC`,
    [queryStartSec, endSec]
  );

  const { data: rawRecurring, isLoading: loadingRecurring } = useQuery<RecurringRow>(
    `SELECT id, amount, frequency, active FROM recurring_rules WHERE deleted_at IS NULL AND active = 1`
  );

  const { data: allCategories } = useQuery<{
    id: string;
    name: string;
    kind: string;
    sort_order: number;
    color_dark?: number;
    color_light?: number;
    icon?: string;
  }>('SELECT * FROM categories ORDER BY sort_order ASC');

  const txs = useMemo(() => rawTxs || [], [rawTxs]);
  const recurring = useMemo(() => rawRecurring || [], [rawRecurring]);
  const isLoading = loadingTxs || loadingRecurring;

  // Filter transactions belonging to the currently selected period
  const periodTxs = useMemo(() => {
    return txs.filter((t) => t.occurred_at >= startSec && t.occurred_at < endSec);
  }, [txs, startSec, endSec]);

  // Compute KPIs
  const { totalExpenses, totalIncome, netSavings } = useMemo(() => {
    let exp = 0;
    let inc = 0;
    for (const t of periodTxs) {
      if (t.type === 'expense') exp += t.amount;
      else if (t.type === 'income') inc += t.amount;
    }
    return {
      totalExpenses: exp,
      totalIncome: inc,
      netSavings: inc - exp,
    };
  }, [periodTxs]);

  // Highest month calculation (for year or overall)
  const highestMonth = useMemo(() => {
    const monthlyExpenses: Record<number, number> = {};
    for (const t of txs) {
      if (t.type === 'expense') {
        const d = new Date(t.occurred_at * 1000);
        if (d.getFullYear() === selectedYear) {
          const m = d.getMonth();
          monthlyExpenses[m] = (monthlyExpenses[m] || 0) + t.amount;
        }
      }
    }

    let maxMonth = -1;
    let maxAmount = 0;
    for (const [mStr, amt] of Object.entries(monthlyExpenses)) {
      const m = parseInt(mStr, 10);
      if (amt > maxAmount) {
        maxAmount = amt;
        maxMonth = m;
      }
    }

    if (maxMonth >= 0) {
      const capitalized =
        MONTH_NAMES[maxMonth].charAt(0).toUpperCase() + MONTH_NAMES[maxMonth].slice(1);
      return {
        name: capitalized,
        amount: maxAmount,
      };
    }
    return {
      name: 'Sin datos',
      amount: 0,
    };
  }, [txs, selectedYear]);

  // Annual subscriptions from recurring rules
  const annualSubscriptions = useMemo(() => {
    let sum = 0;
    let count = 0;
    for (const r of recurring) {
      if (r.active) {
        count++;
        switch (r.frequency) {
          case 'weekly':
            sum += r.amount * 52;
            break;
          case 'biweekly':
            sum += r.amount * 26;
            break;
          case 'monthly':
            sum += r.amount * 12;
            break;
          case 'yearly':
            sum += r.amount;
            break;
          default:
            sum += r.amount * 12;
            break;
        }
      }
    }
    return { amount: sum, count };
  }, [recurring]);

  // Top categories for period
  const topCategories = useMemo(() => {
    const map = new Map<string, { amount: number; color?: number | string | null }>();
    for (const t of periodTxs) {
      if (t.type === 'expense') {
        const catName = t.category_name || 'Otros';
        const color = resolvedTheme === 'dark' ? t.color_dark : t.color_light;
        const cur = map.get(catName) || { amount: 0, color: color ?? t.color_dark };
        cur.amount += t.amount;
        map.set(catName, cur);
      }
    }

    const arr = Array.from(map.entries())
      .map(([name, val]) => ({
        name,
        amount: val.amount,
        percentage: totalExpenses > 0 ? (val.amount / totalExpenses) * 100 : 0,
        color: parseHexColor(val.color),
      }))
      .sort((a, b) => b.amount - a.amount);

    return arr;
  }, [periodTxs, totalExpenses, resolvedTheme]);

  // Reference date for the 6-month trend: finishes on the period's chosen month
  const trendRefDate = useMemo(() => {
    if (periodParam === 'mes') {
      return new Date(selectedYear, selectedMonth, 1);
    }
    if (periodParam === 'ano') {
      const m = selectedYear === currentYear ? currentMonth : 11;
      return new Date(selectedYear, m, 1);
    }
    return new Date((endSec - 1) * 1000);
  }, [periodParam, selectedYear, selectedMonth, currentYear, currentMonth, endSec]);

  // Real Category Trend: spending per month of top 3 categories in last 6 months
  const categoryTrend = useMemo(() => {
    return calculateCategoryMonthlyTrend({
      transactions: txs,
      referenceDate: trendRefDate,
      monthsCount: 6,
    });
  }, [txs, trendRefDate]);

  // Top merchants
  const topMerchants = useMemo(() => {
    const map = new Map<string, number>();
    for (const t of periodTxs) {
      if (t.type === 'expense') {
        const m = t.merchant?.trim() || t.category_name || 'Varios';
        map.set(m, (map.get(m) || 0) + t.amount);
      }
    }

    const arr = Array.from(map.entries())
      .map(([name, amount]) => ({
        name,
        amount,
        percentage: totalExpenses > 0 ? (amount / totalExpenses) * 100 : 0,
      }))
      .sort((a, b) => b.amount - a.amount);

    return arr.slice(0, 5);
  }, [periodTxs, totalExpenses]);

  // Ant expenses
  const antExpenses = useMemo(() => {
    const expenseList = periodTxs.map((t) => ({
      id: t.id,
      type: t.type,
      amount: t.amount,
      merchant: t.merchant || undefined,
      category: t.category_id || 'c_varios',
    }));

    const result = calculateAntExpenses({
      transactions: expenseList,
      threshold: 35000,
    });

    const percentageOfExpenses =
      totalExpenses > 0 ? (result.total / totalExpenses) * 100 : 0;

    const topMerchants = result.groups.map((g) => ({
      name: g.name,
      amount: g.total,
    }));

    return {
      total: result.total,
      count: result.count,
      percentageOfExpenses,
      topMerchants,
    };
  }, [periodTxs, totalExpenses]);

  // Tus días dataset: 182 days (26 weeks x 7 days)
  const tusDiasData = useMemo<DayData[]>(() => {
    const days: DayData[] = [];
    const endDate = new Date(endSec * 1000);
    const baseDate = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate());
    const startDate = new Date(baseDate);
    startDate.setDate(baseDate.getDate() - 181);

    const txByDay = new Map<string, { total: number; count: number; merchants: Map<string, number> }>();
    for (const t of txs) {
      if (t.type === 'expense') {
        const d = new Date(t.occurred_at * 1000);
        const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
        const cur = txByDay.get(key) || { total: 0, count: 0, merchants: new Map() };
        cur.total += t.amount;
        cur.count += 1;
        if (t.merchant) {
          cur.merchants.set(t.merchant, (cur.merchants.get(t.merchant) || 0) + t.amount);
        }
        txByDay.set(key, cur);
      }
    }

    for (let i = 0; i < 182; i++) {
      const d = new Date(startDate);
      d.setDate(startDate.getDate() + i);
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
      const entry = txByDay.get(key);

      let topMerchant: string | undefined;
      if (entry && entry.merchants.size > 0) {
        let maxM = '';
        let maxVal = 0;
        for (const [mName, mVal] of entry.merchants.entries()) {
          if (mVal > maxVal) {
            maxVal = mVal;
            maxM = mName;
          }
        }
        topMerchant = maxM;
      }

      days.push({
        date: d,
        amount: entry ? entry.total : 0,
        txCount: entry ? entry.count : 0,
        topMerchant,
      });
    }

    return days;
  }, [txs, endSec]);

  // Total spent across the 182 days displayed in Tus días
  const tusDiasTotal = useMemo(() => {
    return tusDiasData.reduce((acc, d) => acc + (d.amount || 0), 0);
  }, [tusDiasData]);

  // Handlers for switching period
  const handlePeriodChange = (newPeriod: 'mes' | 'ano' | 'custom') => {
    const params = new URLSearchParams(searchParams);
    params.set('period', newPeriod);
    setSearchParams(params);
  };

  // Export handlers
  const getExportRows = useCallback((): MovementExportRow[] => {
    return periodTxs.map((t) => ({
      type: t.type,
      amount: t.amount,
      occurred_at: t.occurred_at,
      category_name: t.category_name,
      note: t.note,
      merchant: t.merchant,
    }));
  }, [periodTxs]);

  const handleDownloadCsv = () => {
    const rows = getExportRows();
    const csvContent = toCsv(rows);
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    downloadBlob(blob, `pockt-reporte-${periodLabel.replace(/\s+/g, '-').toLowerCase()}.csv`);
  };

  const handleDownloadExcel = async () => {
    const rows = getExportRows();
    const xlsxBytes = await toXlsx(rows);
    const blob = new Blob([xlsxBytes as BlobPart], {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    });
    downloadBlob(blob, `pockt-reporte-${periodLabel.replace(/\s+/g, '-').toLowerCase()}.xlsx`);
  };

  const handleDownloadPdf = async () => {
    setIsGeneratingPdf(true);
    try {
      const pdfData: ReportPdfData = {
        periodLabel,
        totalExpenses,
        totalIncome,
        netSavings,
        highestMonth,
        annualSubscriptions,
        topCategories,
        topMerchants,
        antExpenses: {
          total: antExpenses.total,
          count: antExpenses.count,
          percentageOfExpenses: antExpenses.percentageOfExpenses,
          topMerchants: antExpenses.topMerchants,
        },
      };
      const blob = await generateReportPdf(pdfData);
      downloadBlob(blob, `pockt-resumen-${periodLabel.replace(/\s+/g, '-').toLowerCase()}.pdf`);
    } catch (err) {
      console.error('Error generating PDF:', err);
    } finally {
      setIsGeneratingPdf(false);
    }
  };

  const handleSelectDay = (day: DayData) => {
    setSelectedDay(day);
  };

  const selectedDayKey = useMemo(() => {
    if (!selectedDay) return null;
    const y = selectedDay.date.getFullYear();
    const m = String(selectedDay.date.getMonth() + 1).padStart(2, '0');
    const d = String(selectedDay.date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }, [selectedDay]);

  const selectedDayTransactions = useMemo<DayDetailTransaction[]>(() => {
    if (!selectedDay) return [];
    const day = selectedDay.date;
    const dayStartSec = Math.floor(
      new Date(day.getFullYear(), day.getMonth(), day.getDate(), 0, 0, 0).getTime() / 1000
    );
    const dayEndSec = dayStartSec + 86400;
    return txs
      .filter((t) => {
        const ms = t.occurred_at > 1e11 ? t.occurred_at : t.occurred_at * 1000;
        const sec = Math.floor(ms / 1000);
        return sec >= dayStartSec && sec < dayEndSec;
      })
      .map((t) => ({
        id: t.id,
        type: t.type,
        amount: t.amount,
        category_id: t.category_id,
        category_name: t.category_name,
        category_color_dark: typeof t.color_dark === 'number' ? t.color_dark : null,
        category_color_light: typeof t.color_light === 'number' ? t.color_light : null,
        merchant: t.merchant,
        note: t.note,
        occurred_at: t.occurred_at,
        loan_id: t.loan_id,
        source: t.source,
      }));
  }, [selectedDay, txs]);

  return (
    <div className="space-y-6 select-none">
      {/* Header with Title and Period Segmented Control */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-text-primary tracking-tight">
            Reportes
          </h1>
          <div className="text-xs sm:text-[13px] text-text-tertiary mt-1">
            {periodLabel} · Balance y análisis de gastos
          </div>
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          <div className="seg inline-flex p-1 rounded-xl bg-glass-fill border border-glass-border">
            {(['mes', 'ano', 'custom'] as const).map((mode) => {
              const labels = { mes: 'Mes', ano: 'Año', custom: 'Personalizado' };
              const isActive = periodParam === mode;
              return (
                <button
                  key={mode}
                  type="button"
                  className={cn(
                    'px-3.5 min-h-[40px] py-2 rounded-lg text-xs font-semibold transition-all cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-brand-start flex items-center justify-center',
                    isActive
                      ? 'on bg-white/10 text-text-primary shadow-sm'
                      : 'text-text-tertiary hover:text-text-primary hover:bg-white/5'
                  )}
                  onClick={() => handlePeriodChange(mode)}
                >
                  {labels[mode]}
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {/* 4 KPIs Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3.5">
        {/* KPI 1: Gastado */}
        <div className="card p-5 bg-glass-fill border border-glass-border rounded-2xl shadow-sm">
          <div className="text-xs font-semibold text-text-tertiary uppercase tracking-wider">
            Gastado en {periodLabel}
          </div>
          <div className="text-2xl lg:text-[28px] font-extrabold text-text-primary tabular-nums mt-2">
            {isLoading ? <Skeleton className="h-8 w-32" /> : <CountUp value={totalExpenses} />}
          </div>
          <div className="text-xs text-text-tertiary mt-1">
            {periodParam === 'ano'
              ? `promedio ${formatGs(Math.round(totalExpenses / 12))} por mes`
              : `${periodTxs.filter((t) => t.type === 'expense').length} movimientos`}
          </div>
        </div>

        {/* KPI 2: Ahorro neto */}
        <div className="card p-5 bg-glass-fill border border-glass-border rounded-2xl shadow-sm">
          <div className="text-xs font-semibold text-text-tertiary uppercase tracking-wider">
            Ahorro neto
          </div>
          <div
            className={cn(
              'text-2xl lg:text-[28px] font-extrabold tabular-nums mt-2',
              netSavings >= 0 ? 'text-positive' : 'text-danger'
            )}
          >
            {isLoading ? <Skeleton className="h-8 w-32" /> : <CountUp value={netSavings} />}
          </div>
          <div className="text-xs text-text-tertiary mt-1">
            {formatNetSavingsSubtitle(netSavings, totalIncome)}
          </div>
        </div>

        {/* KPI 3: Mes más caro */}
        <div className="card p-5 bg-glass-fill border border-glass-border rounded-2xl shadow-sm">
          <div className="text-xs font-semibold text-text-tertiary uppercase tracking-wider">
            Mes más caro
          </div>
          <div className="text-2xl lg:text-[28px] font-extrabold text-text-primary mt-2">
            {isLoading ? <Skeleton className="h-8 w-32" /> : highestMonth.name}
          </div>
          <div className="text-xs text-text-tertiary mt-1">
            {highestMonth.amount > 0 ? formatGs(highestMonth.amount) : 'Sin gastos registrados'}
          </div>
        </div>

        {/* KPI 4: Suscripciones al año */}
        <div className="card p-5 bg-glass-fill border border-glass-border rounded-2xl shadow-sm">
          <div className="text-xs font-semibold text-text-tertiary uppercase tracking-wider">
            Suscripciones al año
          </div>
          <div className="text-2xl lg:text-[28px] font-extrabold text-text-primary tabular-nums mt-2">
            {isLoading ? (
              <Skeleton className="h-8 w-32" />
            ) : (
              <CountUp value={annualSubscriptions.amount} />
            )}
          </div>
          <div className="text-xs text-text-tertiary mt-1">
            {annualSubscriptions.count}{' '}
            {annualSubscriptions.count === 1 ? 'recurrente activo' : 'recurrentes activos'}
          </div>
        </div>
      </div>

      {/* Row 2: Tendencia por categoría (1.6fr) & Dónde gastás más (1fr) */}
      <div className="grid grid-cols-1 lg:grid-cols-[1.6fr_1fr] gap-3.5">
        {/* Tendencia por categoría con datos reales */}
        <div className="card p-5 bg-glass-fill border border-glass-border rounded-2xl shadow-sm flex flex-col min-h-[300px]">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-base font-bold text-text-primary">Tendencia por categoría</h2>
            <span className="text-xs text-text-tertiary">últimos 6 meses</span>
          </div>

          {isLoading ? (
            <Skeleton className="h-48 w-full mt-auto" />
          ) : !categoryTrend.hasData || categoryTrend.series.length === 0 ? (
            <div className="flex-1 flex items-center justify-center text-text-tertiary text-xs">
              Sin gastos suficientes en los últimos 6 meses para mostrar la tendencia.
            </div>
          ) : (
            <div className="flex-1 flex flex-col justify-between">
              {/* SVG Curve Chart */}
              <div className="w-full">
                <svg
                  viewBox="0 0 600 160"
                  className="w-full h-44 overflow-visible"
                  fill="none"
                  strokeWidth="2.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  {/* Horizontal gridlines */}
                  <line x1={30} y1={20} x2={570} y2={20} stroke="rgba(255,255,255,0.06)" strokeDasharray="3 3" />
                  <line x1={30} y1={70} x2={570} y2={70} stroke="rgba(255,255,255,0.06)" strokeDasharray="3 3" />
                  <line x1={30} y1={120} x2={570} y2={120} stroke="rgba(255,255,255,0.08)" />

                  {/* Series curves and dots */}
                  {categoryTrend.series.map((s) => {
                    const color = parseHexColor(
                      resolvedTheme === 'dark' ? s.colorDark : s.colorLight
                    );

                    const padX = 30;
                    const padY = 20;
                    const plotW = 540;
                    const plotH = 100;
                    const stepX = plotW / (categoryTrend.months.length - 1);

                    const points = s.points.map((val, pIdx) => {
                      const x = padX + pIdx * stepX;
                      const y = padY + plotH - (val / categoryTrend.maxAmount) * plotH;
                      return { x, y };
                    });

                    const d = buildMonotoneCubicPath(points, { baselineY: 120, topY: 20 });

                    return (
                      <g key={s.categoryId}>
                        <path
                          d={d}
                          stroke={color}
                          strokeWidth="2.5"
                          opacity={0.9}
                          className="transition-all duration-300"
                        />
                        {points.map((p, pIdx) => (
                          <circle
                            key={pIdx}
                            cx={p.x}
                            cy={p.y}
                            r={3.5}
                            fill={color}
                            className="transition-transform hover:scale-125"
                          />
                        ))}
                      </g>
                    );
                  })}

                  {/* Month labels at bottom */}
                  {categoryTrend.months.map((m, mIdx) => {
                    const padX = 30;
                    const plotW = 540;
                    const stepX = plotW / (categoryTrend.months.length - 1);
                    const x = padX + mIdx * stepX;
                    return (
                      <text
                        key={m.key}
                        x={x}
                        y={145}
                        textAnchor="middle"
                        className="text-[11px] fill-text-tertiary select-none"
                      >
                        {m.label}
                      </text>
                    );
                  })}
                </svg>
              </div>

              {/* Legend with real category names and totals */}
              <div className="flex flex-wrap gap-4 pt-3 border-t border-glass-border text-xs text-text-secondary mt-2">
                {categoryTrend.series.map((s) => {
                  const color = parseHexColor(
                    resolvedTheme === 'dark' ? s.colorDark : s.colorLight
                  );
                  return (
                    <div key={s.categoryId} className="flex items-center gap-1.5">
                      <span
                        className="w-2.5 h-2.5 rounded-full inline-block shrink-0 shadow-sm"
                        style={{ backgroundColor: color }}
                      />
                      <span className="font-medium text-text-primary">{s.categoryName}</span>
                      <span className="text-text-tertiary tabular-nums">
                        ({formatGs(s.total)})
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        {/* Dónde gastás más (Ranking de comercios) */}
        <div className="card p-5 bg-glass-fill border border-glass-border rounded-2xl shadow-sm flex flex-col min-h-[300px]">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-base font-bold text-text-primary">Dónde gastás más</h2>
            <span className="text-xs text-text-tertiary">ranking</span>
          </div>

          {isLoading ? (
            <div className="space-y-4 my-auto">
              <Skeleton className="h-8 w-full" />
              <Skeleton className="h-8 w-full" />
              <Skeleton className="h-8 w-full" />
            </div>
          ) : topMerchants.length === 0 ? (
            <div className="flex-1 flex items-center justify-center text-text-tertiary text-xs">
              Sin comercios en este período
            </div>
          ) : (
            <div className="space-y-3.5 flex-1">
              {topMerchants.map((m, idx) => {
                const barColors = ['#E4A067', '#6BBAF0', '#8FB0F8', '#C19FE9', '#FF8A3D'];
                const barColor = barColors[idx % barColors.length];
                return (
                  <div key={m.name} className="text-xs">
                    <div className="flex justify-between items-center text-text-primary mb-1">
                      <span className="font-medium truncate max-w-[180px]">{m.name}</span>
                      <span className="text-text-secondary tabular-nums">{formatGs(m.amount)}</span>
                    </div>
                    <div className="h-1.5 w-full bg-white/10 rounded-full overflow-hidden">
                      <div
                        className="h-full rounded-full transition-all duration-300"
                        style={{
                          width: `${Math.max(4, m.percentage)}%`,
                          backgroundColor: barColor,
                        }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* Row 3: Gastos hormiga */}
      {antExpenses.count > 0 && (
        <div className="card p-5 bg-glass-fill border border-glass-border rounded-2xl shadow-sm">
          <div className="flex justify-between items-start mb-2">
            <div>
              <h2 className="text-base font-bold text-text-primary">Gastos hormiga</h2>
              <div className="text-xs text-text-tertiary mt-0.5">
                {antExpenses.count} compras pequeñas sumaron {formatGs(antExpenses.total)} (
                {antExpenses.percentageOfExpenses.toFixed(1)}% del total gastado).
              </div>
            </div>
          </div>

          {antExpenses.topMerchants.length > 0 && (
            <div className="flex flex-wrap gap-2 mt-3 pt-3 border-t border-glass-border text-xs">
              <span className="text-text-tertiary">Frecuentes:</span>
              {antExpenses.topMerchants.map((tm) => (
                <span
                  key={tm.name}
                  className="bg-white/5 border border-glass-border px-2.5 py-0.5 rounded-full text-text-secondary tabular-nums text-[11.5px]"
                >
                  {tm.name} ({formatGs(tm.amount)})
                </span>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Row 4: Tus días (Heat Map 2D / 3D) */}
      <div className="space-y-2">
        <div className="flex justify-between items-center">
          <h2 className="text-lg font-bold text-text-primary">Tus días</h2>
          <span className="text-xs text-text-tertiary">actividad diaria</span>
        </div>
        <TusDias
          days={tusDiasData}
          periodLabel={`Gastado en últimos 6 meses`}
          totalAmount={tusDiasTotal}
          onSelectDay={handleSelectDay}
        />
      </div>

      {/* Row 5: Descargas (CSV, Excel, PDF) */}
      <div className="card p-5 bg-glass-fill border border-glass-border rounded-2xl shadow-sm">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-3">
          <div>
            <h2 className="text-base font-bold text-text-primary">Descargas</h2>
            <div className="text-xs text-text-tertiary">del período elegido ({periodLabel})</div>
          </div>

          {isGeneratingPdf && (
            <div className="flex items-center gap-2 text-xs text-text-secondary bg-white/5 px-3 py-1.5 rounded-full border border-glass-border">
              <span className="w-3.5 h-3.5 border-2 border-white/20 border-t-brand-start rounded-full animate-spin inline-block" />
              <span>Generando PDF</span>
            </div>
          )}
        </div>

        <div className="flex flex-wrap items-center gap-2.5 pt-1">
          <button
            type="button"
            className="inline-flex items-center gap-2 px-3.5 min-h-[40px] py-2 rounded-full text-xs font-semibold bg-glass-fill border border-glass-border text-text-secondary hover:text-text-primary hover:bg-white/10 active:scale-95 transition-all cursor-pointer focus-visible:ring-2 focus-visible:ring-brand-start focus-visible:outline-none disabled:opacity-40 disabled:cursor-not-allowed"
            onClick={handleDownloadCsv}
            disabled={periodTxs.length === 0}
          >
            <Download className="w-3.5 h-3.5" />
            <span>Movimientos · CSV</span>
          </button>

          <button
            type="button"
            className="inline-flex items-center gap-2 px-3.5 min-h-[40px] py-2 rounded-full text-xs font-semibold bg-glass-fill border border-glass-border text-text-secondary hover:text-text-primary hover:bg-white/10 active:scale-95 transition-all cursor-pointer focus-visible:ring-2 focus-visible:ring-brand-start focus-visible:outline-none disabled:opacity-40 disabled:cursor-not-allowed"
            onClick={handleDownloadExcel}
            disabled={periodTxs.length === 0}
          >
            <Download className="w-3.5 h-3.5" />
            <span>Movimientos · Excel</span>
          </button>

          <button
            type="button"
            className="inline-flex items-center gap-2 px-3.5 min-h-[40px] py-2 rounded-full text-xs font-semibold bg-glass-fill border border-glass-border text-text-secondary hover:text-text-primary hover:bg-white/10 active:scale-95 transition-all cursor-pointer focus-visible:ring-2 focus-visible:ring-brand-start focus-visible:outline-none disabled:opacity-40 disabled:cursor-not-allowed"
            onClick={handleDownloadPdf}
            disabled={isGeneratingPdf}
          >
            <Download className="w-3.5 h-3.5" />
            <span>Resumen · PDF</span>
          </button>
        </div>
      </div>

      {/* Day Detail Panel */}
      <DayDetailPanel
        isOpen={selectedDay !== null}
        dateKey={selectedDayKey}
        transactions={selectedDayTransactions}
        onClose={() => setSelectedDay(null)}
        onSelectTransaction={(tx) => setSelectedTxId(tx.id)}
      />

      {/* Movement Edit/Detail Panel if selected */}
      {selectedTxId && (
        <MovementPanel
          isOpen={true}
          movement={
            (() => {
              const tx = txs.find((t) => t.id === selectedTxId);
              return tx
                ? {
                    id: tx.id,
                    type: tx.type,
                    amount: tx.amount,
                    category_id: tx.category_id,
                    merchant: tx.merchant,
                    note: tx.note,
                    occurred_at: tx.occurred_at,
                    loan_id: tx.loan_id,
                  }
                : null;
            })()
          }
          db={db}
          categories={(allCategories ?? []).map((c) => ({
            id: c.id,
            name: c.name,
            kind: c.kind ?? 'expense',
            sort_order: c.sort_order ?? 0,
            icon: c.icon ?? undefined,
            color_dark: typeof c.color_dark === 'number' ? c.color_dark : null,
            color_light: typeof c.color_light === 'number' ? c.color_light : null,
          }))}
          onClose={() => setSelectedTxId(null)}
          onSaved={() => setSelectedTxId(null)}
          onDeleted={() => setSelectedTxId(null)}
        />
      )}
    </div>
  );
}
