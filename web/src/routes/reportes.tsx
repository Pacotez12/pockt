import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useQuery, usePowerSync } from '@powersync/react';
import { formatGs } from '@/lib/format';
import { CountUp } from '@/components/CountUp';
import { Skeleton } from '@/components/Skeleton';
import { TusDias, type DayData } from '@/components/reports/TusDias';
import { MovementPanel } from '@/components/movements/MovementPanel';
import { calculateAntExpenses } from '@/lib/calc/reports';
import { toCsv, toXlsx, downloadBlob, type MovementExportRow } from '@/lib/movements/export';
import { generateReportPdf, type ReportPdfData } from '@/lib/reports/pdf';

interface TxRow {
  id: string;
  type: string;
  amount: number;
  occurred_at: number;
  merchant?: string | null;
  note?: string | null;
  category_id?: string | null;
  category_name?: string | null;
  color_dark?: string | null;
  color_light?: string | null;
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

export function ReportesRoute() {
  const db = usePowerSync();
  const [searchParams, setSearchParams] = useSearchParams();
  const periodParam = (searchParams.get('period') as 'mes' | 'ano' | 'custom') || 'mes';

  const [isGeneratingPdf, setIsGeneratingPdf] = useState<boolean>(false);
  const [selectedTxId, setSelectedTxId] = useState<string | null>(null);

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
    `SELECT t.id, t.type, t.amount, t.occurred_at, t.merchant, t.note,
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

  // Top categories
  const topCategories = useMemo(() => {
    const map = new Map<string, { amount: number; color?: string }>();
    for (const t of periodTxs) {
      if (t.type === 'expense') {
        const catName = t.category_name || 'Otros';
        const cur = map.get(catName) || { amount: 0, color: t.color_dark || '#E4A067' };
        cur.amount += t.amount;
        map.set(catName, cur);
      }
    }

    const arr = Array.from(map.entries())
      .map(([name, val]) => ({
        name,
        amount: val.amount,
        percentage: totalExpenses > 0 ? (val.amount / totalExpenses) * 100 : 0,
        color: val.color,
      }))
      .sort((a, b) => b.amount - a.amount);

    return arr;
  }, [periodTxs, totalExpenses]);

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
    } finally {
      setIsGeneratingPdf(false);
    }
  };

  const handleSelectDay = (day: DayData) => {
    const dayStartSec = Math.floor(
      new Date(day.date.getFullYear(), day.date.getMonth(), day.date.getDate()).getTime() / 1000
    );
    const dayEndSec = dayStartSec + 86400;
    const dayTx = txs.find((t) => t.occurred_at >= dayStartSec && t.occurred_at < dayEndSec);
    if (dayTx) {
      setSelectedTxId(dayTx.id);
    }
  };

  return (
    <div className="p-8 max-w-[1240px] mx-auto space-y-6">
      {/* Header with Title and Period Segmented Control */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-[26px] font-extrabold text-white tracking-tight">Reportes</h1>
          <div className="text-[13px] text-white/50 mt-0.5">
            {periodLabel} · Balance y análisis de gastos
          </div>
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          <div className="seg w-[280px]">
            <button
              type="button"
              className={periodParam === 'mes' ? 'on' : ''}
              onClick={() => handlePeriodChange('mes')}
            >
              Mes
            </button>
            <button
              type="button"
              className={periodParam === 'ano' ? 'on' : ''}
              onClick={() => handlePeriodChange('ano')}
            >
              Año
            </button>
            <button
              type="button"
              className={periodParam === 'custom' ? 'on' : ''}
              onClick={() => handlePeriodChange('custom')}
            >
              Personalizado
            </button>
          </div>
        </div>
      </div>

      {/* 4 KPIs Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3.5">
        {/* KPI 1: Gastado */}
        <div className="card p-5 bg-black border border-white/10 rounded-2xl">
          <div className="text-xs font-semibold text-white/50 uppercase tracking-wider">
            Gastado en {periodLabel}
          </div>
          <div className="text-2xl lg:text-[28px] font-extrabold text-white mt-2">
            {isLoading ? <Skeleton className="h-8 w-32" /> : <CountUp value={totalExpenses} />}
          </div>
          <div className="text-xs text-white/40 mt-1">
            {periodParam === 'ano'
              ? `promedio ${formatGs(Math.round(totalExpenses / 12))} por mes`
              : `${periodTxs.filter((t) => t.type === 'expense').length} movimientos`}
          </div>
        </div>

        {/* KPI 2: Ahorro neto */}
        <div className="card p-5 bg-black border border-white/10 rounded-2xl">
          <div className="text-xs font-semibold text-white/50 uppercase tracking-wider">
            Ahorro neto
          </div>
          <div
            className={`text-2xl lg:text-[28px] font-extrabold mt-2 ${
              netSavings >= 0 ? 'text-[#30D158]' : 'text-[#FF453A]'
            }`}
          >
            {isLoading ? <Skeleton className="h-8 w-32" /> : <CountUp value={netSavings} />}
          </div>
          <div className="text-xs text-white/40 mt-1">
            {totalIncome > 0
              ? `${Math.max(0, Math.round((netSavings / totalIncome) * 100))} % de lo que entró`
              : 'Sin ingresos registrados'}
          </div>
        </div>

        {/* KPI 3: Mes más caro */}
        <div className="card p-5 bg-black border border-white/10 rounded-2xl">
          <div className="text-xs font-semibold text-white/50 uppercase tracking-wider">
            Mes más caro
          </div>
          <div className="text-2xl lg:text-[28px] font-extrabold text-white mt-2">
            {isLoading ? <Skeleton className="h-8 w-32" /> : highestMonth.name}
          </div>
          <div className="text-xs text-white/40 mt-1">
            {highestMonth.amount > 0 ? formatGs(highestMonth.amount) : 'Sin gastos registrados'}
          </div>
        </div>

        {/* KPI 4: Suscripciones al año */}
        <div className="card p-5 bg-black border border-white/10 rounded-2xl">
          <div className="text-xs font-semibold text-white/50 uppercase tracking-wider">
            Suscripciones al año
          </div>
          <div className="text-2xl lg:text-[28px] font-extrabold text-white mt-2">
            {isLoading ? (
              <Skeleton className="h-8 w-32" />
            ) : (
              <CountUp value={annualSubscriptions.amount} />
            )}
          </div>
          <div className="text-xs text-white/40 mt-1">
            {annualSubscriptions.count}{' '}
            {annualSubscriptions.count === 1 ? 'recurrente activo' : 'recurrentes activos'}
          </div>
        </div>
      </div>

      {/* Row 2: Tendencia por categoría (1.6fr) & Dónde gastás más (1fr) */}
      <div className="grid grid-cols-1 lg:grid-cols-[1.6fr_1fr] gap-3.5">
        {/* Tendencia por categoría */}
        <div className="card p-5 bg-black border border-white/10 rounded-2xl flex flex-col min-h-[300px]">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-base font-bold text-white">Tendencia por categoría</h2>
            <span className="text-xs text-white/40">{periodLabel}</span>
          </div>

          {isLoading ? (
            <Skeleton className="h-48 w-full mt-auto" />
          ) : topCategories.length === 0 ? (
            <div className="flex-1 flex items-center justify-center text-white/40 text-sm">
              Sin gastos en este período
            </div>
          ) : (
            <div className="flex-1 flex flex-col justify-between">
              <svg
                viewBox="0 0 640 180"
                className="w-full h-44 overflow-visible"
                fill="none"
                strokeWidth="2.5"
                strokeLinecap="round"
              >
                {topCategories.slice(0, 3).map((cat, idx) => {
                  const strokeColors = ['#E4A067', '#C19FE9', '#6BBAF0'];
                  const color = strokeColors[idx % strokeColors.length];
                  const yBase = 120 + idx * 25;
                  const d = `M 10 ${yBase} C 90 ${yBase - 20}, 160 ${yBase - 35}, 240 ${yBase - 15} S 400 ${yBase - 40}, 500 ${yBase - 25} S 580 ${yBase - 30}, 630 ${yBase - 10}`;
                  return (
                    <g key={cat.name}>
                      <path d={d} stroke={color} strokeWidth="2.5" opacity="0.85" />
                    </g>
                  );
                })}
              </svg>

              <div className="flex flex-wrap gap-4 pt-3 border-t border-white/5 text-xs text-white/60">
                {topCategories.slice(0, 3).map((cat, idx) => {
                  const dotColors = ['#E4A067', '#C19FE9', '#6BBAF0'];
                  return (
                    <div key={cat.name} className="flex items-center gap-1.5">
                      <span
                        className="w-2.5 h-2.5 rounded-full inline-block"
                        style={{ backgroundColor: dotColors[idx % dotColors.length] }}
                      />
                      <span>{cat.name}</span>
                      <span className="text-white/40 font-mono">
                        ({cat.percentage.toFixed(0)}%)
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        {/* Dónde gastás más (Ranking de comercios) */}
        <div className="card p-5 bg-black border border-white/10 rounded-2xl flex flex-col min-h-[300px]">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-base font-bold text-white">Dónde gastás más</h2>
            <span className="text-xs text-white/40">ranking</span>
          </div>

          {isLoading ? (
            <div className="space-y-4 my-auto">
              <Skeleton className="h-8 w-full" />
              <Skeleton className="h-8 w-full" />
              <Skeleton className="h-8 w-full" />
            </div>
          ) : topMerchants.length === 0 ? (
            <div className="flex-1 flex items-center justify-center text-white/40 text-sm">
              Sin comercios en este período
            </div>
          ) : (
            <div className="space-y-3.5 flex-1">
              {topMerchants.map((m, idx) => {
                const barColors = ['#E4A067', '#6BBAF0', '#8FB0F8', '#C19FE9', '#FF8A3D'];
                const barColor = barColors[idx % barColors.length];
                return (
                  <div key={m.name} className="text-xs">
                    <div className="flex justify-between items-center text-white mb-1">
                      <span className="font-medium truncate max-w-[180px]">{m.name}</span>
                      <span className="font-mono text-white/80">{formatGs(m.amount)}</span>
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
        <div className="card p-5 bg-black border border-white/10 rounded-2xl">
          <div className="flex justify-between items-start mb-2">
            <div>
              <h2 className="text-base font-bold text-white">Gastos hormiga</h2>
              <div className="text-xs text-white/50 mt-0.5">
                {antExpenses.count} compras pequeñas sumaron {formatGs(antExpenses.total)} (
                {antExpenses.percentageOfExpenses.toFixed(1)}% del total gastado).
              </div>
            </div>
          </div>

          {antExpenses.topMerchants.length > 0 && (
            <div className="flex flex-wrap gap-2 mt-3 pt-3 border-t border-white/5 text-xs">
              <span className="text-white/40">Frecuentes:</span>
              {antExpenses.topMerchants.map((tm) => (
                <span
                  key={tm.name}
                  className="bg-white/5 border border-white/10 px-2.5 py-0.5 rounded-full text-white/80 font-mono text-[11.5px]"
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
          <h2 className="text-lg font-bold text-white">Tus días</h2>
          <span className="text-xs text-white/40">actividad diaria</span>
        </div>
        <TusDias
          days={tusDiasData}
          periodLabel={`Gastado en últimos 6 meses`}
          totalAmount={totalExpenses}
          onSelectDay={handleSelectDay}
        />
      </div>

      {/* Row 5: Descargas (CSV, Excel, PDF) */}
      <div className="card p-5 bg-black border border-white/10 rounded-2xl">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-3">
          <div>
            <h2 className="text-base font-bold text-white">Descargas</h2>
            <div className="text-xs text-white/40">del período elegido ({periodLabel})</div>
          </div>

          {isGeneratingPdf && (
            <div className="flex items-center gap-2 text-xs text-white/70 bg-white/5 px-3 py-1.5 rounded-full border border-white/10">
              <span className="w-3.5 h-3.5 border-2 border-white/20 border-t-[#FF8A3D] rounded-full animate-spin inline-block" />
              <span>Generando PDF</span>
            </div>
          )}
        </div>

        <div className="flex flex-wrap items-center gap-2.5 pt-1">
          <button
            type="button"
            className="chip hover:bg-white/10 transition-colors"
            onClick={handleDownloadCsv}
            disabled={periodTxs.length === 0}
          >
            <svg className="ic w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={1.8}
                d="M7 3h7l5 5v13H7z M14 3v5h5"
              />
            </svg>
            <span>Movimientos · CSV</span>
          </button>

          <button
            type="button"
            className="chip hover:bg-white/10 transition-colors"
            onClick={handleDownloadExcel}
            disabled={periodTxs.length === 0}
          >
            <svg className="ic w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={1.8}
                d="M7 3h7l5 5v13H7z M14 3v5h5"
              />
            </svg>
            <span>Movimientos · Excel</span>
          </button>

          <button
            type="button"
            className="chip hover:bg-white/10 transition-colors"
            onClick={handleDownloadPdf}
            disabled={isGeneratingPdf}
          >
            <svg className="ic w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={1.8}
                d="M7 3h7l5 5v13H7z M14 3v5h5"
              />
            </svg>
            <span>Resumen · PDF</span>
          </button>
        </div>
      </div>

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
            icon: c.icon,
            color_dark: c.color_dark,
            color_light: c.color_light,
          }))}
          onClose={() => setSelectedTxId(null)}
          onSaved={() => setSelectedTxId(null)}
          onDeleted={() => setSelectedTxId(null)}
        />
      )}
    </div>
  );
}
