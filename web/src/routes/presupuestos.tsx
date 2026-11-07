import React, { useEffect, useMemo } from 'react';
import { motion, useReducedMotion } from 'motion/react';
import { useQuery } from '@powersync/react';
import { PieChart, AlertTriangle, Info } from 'lucide-react';
import { CountUp } from '@/components/CountUp';
import { Skeleton } from '@/components/Skeleton';
import { formatGs, formatThousands } from '@/lib/format';
import { periodFor } from '@/lib/calc/date_period';
import { budgetStatus, BudgetStatusResult } from '@/lib/calc/budget_status';

interface BudgetDbRow {
  id: string;
  category_id: string;
  monthly_limit: number;
}

interface CategoryDbRow {
  id: string;
  name: string;
  icon?: string | null;
  color_dark: number;
  color_light: number;
  sort_order: number;
}

interface TxDbRow {
  id: string;
  category_id: string;
  type: string;
  amount: number;
  occurred_at: number;
  deleted_at?: number | null;
}

interface BudgetCardItem {
  budget: BudgetDbRow;
  category: CategoryDbRow;
  spent: number;
  status: BudgetStatusResult;
  effectiveColor: string;
}

const MONTH_NAMES = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

function intToHexColor(colorInt: number): string {
  // Drift/Flutter stores colors as 0xAARRGGBB
  const hex = (colorInt & 0xffffff).toString(16).padStart(6, '0');
  return `#${hex}`;
}

export function PresupuestosRoute() {
  const prefersReduced = useReducedMotion();

  useEffect(() => {
    document.title = 'Presupuestos · Pockt';
  }, []);

  const now = useMemo(() => new Date(), []);
  const currentPeriod = useMemo(() => {
    return periodFor(now, { mode: 'calendar' });
  }, [now]);

  const periodRange = useMemo(() => {
    const startUnix = Math.floor(new Date(`${currentPeriod.start}T00:00:00`).getTime() / 1000);
    const endUnix = Math.floor(new Date(`${currentPeriod.end}T23:59:59`).getTime() / 1000);
    return { startUnix, endUnix };
  }, [currentPeriod]);

  const monthYearLabel = useMemo(() => {
    return `${MONTH_NAMES[now.getMonth()]} ${now.getFullYear()}`;
  }, [now]);

  const { data: budgets, isLoading: loadingBudgets } = useQuery<BudgetDbRow>(
    'SELECT * FROM budgets'
  );

  const { data: categories, isLoading: loadingCategories } = useQuery<CategoryDbRow>(
    'SELECT id, name, icon, color_dark, color_light, sort_order FROM categories WHERE archived = 0 ORDER BY sort_order ASC'
  );

  const { data: transactions, isLoading: loadingTxs } = useQuery<TxDbRow>(
    `SELECT id, category_id, type, amount, occurred_at, deleted_at
     FROM transactions
     WHERE deleted_at IS NULL AND occurred_at >= ? AND occurred_at <= ?`,
    [periodRange.startUnix, periodRange.endUnix]
  );

  const isLoading = loadingBudgets || loadingCategories || loadingTxs;

  const { items, totalSpent, totalLimit, totalRemaining } = useMemo(() => {
    if (!budgets || !categories) {
      return { items: [], totalSpent: 0, totalLimit: 0, totalRemaining: 0 };
    }

    const catMap = new Map<string, CategoryDbRow>();
    for (const c of categories) {
      catMap.set(c.id, c);
    }

    const spentByCat = new Map<string, number>();
    for (const tx of transactions ?? []) {
      if (tx.type !== 'expense') continue;
      const cur = spentByCat.get(tx.category_id) ?? 0;
      spentByCat.set(tx.category_id, cur + tx.amount);
    }

    let sumSpent = 0;
    let sumLimit = 0;

    const budgetItems: BudgetCardItem[] = [];

    for (const b of budgets) {
      const cat = catMap.get(b.category_id);
      if (!cat) continue;

      const spent = spentByCat.get(b.category_id) ?? 0;
      const status = budgetStatus(spent, b.monthly_limit);

      let effectiveColor = intToHexColor(cat.color_dark);
      if (status.level === 'over') {
        effectiveColor = 'var(--danger)';
      } else if (status.level === 'warning') {
        effectiveColor = 'var(--warning)';
      }

      budgetItems.push({
        budget: b,
        category: cat,
        spent,
        status,
        effectiveColor,
      });

      sumSpent += spent;
      sumLimit += b.monthly_limit;
    }

    budgetItems.sort((a, b) => a.category.sort_order - b.category.sort_order);

    return {
      items: budgetItems,
      totalSpent: sumSpent,
      totalLimit: sumLimit,
      totalRemaining: sumLimit - sumSpent,
    };
  }, [budgets, categories, transactions]);

  if (isLoading) {
    return (
      <div data-testid="presupuestos-skeleton" className="space-y-6">
        <div className="flex items-center justify-between">
          <Skeleton className="w-48 h-8 rounded-xl" />
          <Skeleton className="w-36 h-6 rounded-full" />
        </div>
        <Skeleton className="h-28 rounded-2xl" />
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Skeleton className="h-32 rounded-2xl" />
          <Skeleton className="h-32 rounded-2xl" />
        </div>
      </div>
    );
  }

  const overallRatio = totalLimit > 0 ? totalSpent / totalLimit : 0;
  const overallPercent = Math.round(overallRatio * 100);

  return (
    <div className="space-y-8 select-none">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-text-primary">
            Presupuestos
          </h1>
          <p className="text-xs text-text-tertiary mt-1">
            {monthYearLabel}
          </p>
        </div>

        {/* Aviso discreto */}
        <span className="inline-flex items-center gap-1.5 text-xs text-text-tertiary">
          <Info className="w-3.5 h-3.5 shrink-0" />
          <span>Para editar, usá la app</span>
        </span>
      </div>

      {/* KPI Resumen General */}
      {items.length > 0 && (
        <div className="p-5 rounded-2xl bg-glass-fill border border-glass-border">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-xs font-semibold text-text-secondary">
              <PieChart className="w-4 h-4 text-brand-start" />
              <span>Total presupuestado</span>
            </div>
            <span className="text-xs text-text-tertiary">
              {totalRemaining >= 0
                ? `quedan Gs. ${formatThousands(totalRemaining)}`
                : `excedido por Gs. ${formatThousands(Math.abs(totalRemaining))}`}
            </span>
          </div>

          <div className="text-2xl sm:text-3xl font-extrabold tracking-tight text-text-primary tabular-nums mt-2">
            <CountUp value={totalSpent} formatter={formatGs} />
            <span className="text-sm font-semibold text-text-tertiary ml-2">
              de Gs. {formatThousands(totalLimit)}
            </span>
          </div>

          <div className="h-2 rounded-full bg-white/10 mt-3 overflow-hidden">
            <motion.div
              className="h-full rounded-full"
              style={{
                backgroundColor: totalRemaining < 0 ? 'var(--danger)' : 'var(--brand-start)',
              }}
              initial={false}
              animate={{ width: `${Math.min(100, Math.max(0, overallPercent))}%` }}
              transition={
                prefersReduced
                  ? { duration: 0 }
                  : { type: 'spring', stiffness: 220, damping: 28 }
              }
            />
          </div>
        </div>
      )}

      {/* Lista de presupuestos por categoría */}
      <section className="space-y-4">
        {items.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {items.map(({ budget, category, spent, status, effectiveColor }) => {
              const percentInt = Math.round(status.ratio * 100);

              let statusText: React.ReactNode = null;
              if (status.level === 'over') {
                statusText = (
                  <span className="text-xs font-bold" style={{ color: 'var(--danger)' }}>
                    excedido por Gs. {formatThousands(Math.abs(status.remaining))}
                  </span>
                );
              } else if (status.level === 'warning') {
                statusText = (
                  <span className="text-xs font-bold" style={{ color: 'var(--warning)' }}>
                    {percentInt} % usado
                  </span>
                );
              } else {
                statusText = (
                  <span className="text-xs text-text-tertiary">
                    quedan Gs. {formatThousands(status.remaining)}
                  </span>
                );
              }

              return (
                <div
                  key={budget.id}
                  className="p-5 rounded-2xl bg-glass-fill border border-glass-border shadow-sm flex flex-col justify-between"
                >
                  <div>
                    {/* Fila superior: categoría y estado */}
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex items-center gap-2">
                        <span
                          className="w-3 h-3 rounded-full inline-block shrink-0 shadow-sm"
                          style={{ backgroundColor: effectiveColor }}
                        />
                        <h3 className="font-bold text-base text-text-primary">
                          {category.name}
                        </h3>
                      </div>
                      {statusText}
                    </div>

                    {/* Montos */}
                    <div className="mt-3 flex items-baseline gap-2">
                      <span className="text-xl sm:text-2xl font-extrabold tracking-tight text-text-primary tabular-nums">
                        <CountUp value={spent} formatter={formatGs} />
                      </span>
                      <span className="text-xs font-semibold text-text-tertiary">
                        de Gs. {formatThousands(budget.monthly_limit)}
                      </span>
                    </div>

                    {/* Barra de progreso con resorte */}
                    <div className="h-2 rounded-full bg-white/10 mt-3 overflow-hidden">
                      <motion.div
                        className="h-full rounded-full"
                        style={{
                          backgroundColor: effectiveColor,
                        }}
                        initial={false}
                        animate={{ width: `${Math.min(100, Math.max(0, percentInt))}%` }}
                        transition={
                          prefersReduced
                            ? { duration: 0 }
                            : { type: 'spring', stiffness: 220, damping: 28 }
                        }
                      />
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <div className="p-8 rounded-2xl bg-glass-fill border border-glass-border text-center text-sm text-text-tertiary">
            No tenés presupuestos configurados para este período. Para crear uno, usá la app.
          </div>
        )}
      </section>
    </div>
  );
}
