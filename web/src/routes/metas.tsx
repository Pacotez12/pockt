import React, { useEffect, useState, useMemo } from 'react';
import { motion, useReducedMotion } from 'motion/react';
import { useQuery } from '@powersync/react';
import { ChevronDown, Target, History } from 'lucide-react';
import { CountUp } from '@/components/CountUp';
import { Skeleton } from '@/components/Skeleton';
import { formatGs, formatThousands } from '@/lib/format';
import {
  calculateGoalProgress,
  GoalInput,
  GoalContributionInput,
  GoalProgressResult,
} from '@/lib/calc/goal_progress';

interface GoalDbRow {
  id: string;
  name: string;
  icon: string;
  target_amount: number;
  target_date?: number | null;
  created_at: number;
  archived: number;
}

interface GoalContribDbRow {
  id: string;
  goal_id: string;
  amount: number;
  date: number;
  note?: string | null;
  created_at?: number | null;
}

interface GoalCardItem {
  goal: GoalDbRow;
  progress: GoalProgressResult;
  recentContribs: GoalContribDbRow[];
}

function toYMD(timestamp: number | string | Date | null | undefined): string {
  if (!timestamp) return '';
  let d: Date;
  if (timestamp instanceof Date) {
    d = timestamp;
  } else if (typeof timestamp === 'number') {
    d = new Date(timestamp > 1e11 ? timestamp : timestamp * 1000);
  } else {
    const num = Number(timestamp);
    if (!isNaN(num) && num > 0) {
      d = new Date(num > 1e11 ? num : num * 1000);
    } else {
      d = new Date(timestamp);
    }
  }
  const y = d.getFullYear().toString().padStart(4, '0');
  const m = (d.getMonth() + 1).toString().padStart(2, '0');
  const day = d.getDate().toString().padStart(2, '0');
  return `${y}-${m}-${day}`;
}

const MONTH_NAMES_SHORT = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

function formatMonthYear(dateStr: string | null): string {
  if (!dateStr) return '';
  const [y, m] = dateStr.split('T')[0].split('-');
  const idx = Number(m) - 1;
  return `${MONTH_NAMES_SHORT[idx] || m} ${y}`;
}

function formatDateShort(timestamp: number | string | Date): string {
  const d = typeof timestamp === 'number'
    ? new Date(timestamp > 1e11 ? timestamp : timestamp * 1000)
    : new Date(timestamp);
  const day = d.getDate().toString().padStart(2, '0');
  const month = (d.getMonth() + 1).toString().padStart(2, '0');
  return `${day}/${month}`;
}

export function MetasRoute() {
  const prefersReduced = useReducedMotion();
  const [showArchived, setShowArchived] = useState(false);

  useEffect(() => {
    document.title = 'Metas · Pockt';
  }, []);

  const { data: goals, isLoading: loadingGoals } = useQuery<GoalDbRow>(
    'SELECT * FROM goals ORDER BY created_at ASC'
  );

  const { data: contributions, isLoading: loadingContribs } = useQuery<GoalContribDbRow>(
    'SELECT * FROM goal_contributions ORDER BY date DESC'
  );

  const isLoading = loadingGoals || loadingContribs;

  const { activeGoals, archivedGoals, totalSaved } = useMemo(() => {
    if (!goals) {
      return { activeGoals: [], archivedGoals: [], totalSaved: 0 };
    }

    const contribsByGoal = new Map<string, GoalContribDbRow[]>();
    for (const c of contributions ?? []) {
      const list = contribsByGoal.get(c.goal_id) ?? [];
      list.push(c);
      contribsByGoal.set(c.goal_id, list);
    }

    const now = new Date();
    const activeList: GoalCardItem[] = [];
    const archivedList: GoalCardItem[] = [];
    let savedSum = 0;

    for (const g of goals) {
      const goalContribs = contribsByGoal.get(g.id) ?? [];

      const goalInput: GoalInput = {
        id: g.id,
        name: g.name,
        targetAmount: g.target_amount,
        targetDate: g.target_date ? toYMD(g.target_date) : null,
      };

      const contribInputs: GoalContributionInput[] = goalContribs.map((c) => ({
        id: c.id,
        goalId: c.goal_id,
        amount: c.amount,
        date: toYMD(c.date),
      }));

      const progress = calculateGoalProgress({
        goal: loanOrGoalInputFallback(goalInput),
        contributions: contribInputs,
        now,
      });

      const item: GoalCardItem = {
        goal: g,
        progress,
        recentContribs: goalContribs.slice(0, 3),
      };

      if (g.archived === 1) {
        archivedList.push(item);
      } else {
        activeList.push(item);
        savedSum += progress.saved;
      }
    }

    return {
      activeGoals: activeList,
      archivedGoals: archivedList,
      totalSaved: savedSum,
    };
  }, [goals, contributions]);

  function loanOrGoalInputFallback(g: GoalInput): GoalInput {
    return {
      ...g,
      targetDate: g.targetDate || null,
    };
  }

  if (isLoading) {
    return (
      <div data-testid="metas-skeleton" className="space-y-6">
        <div className="flex items-center justify-between">
          <Skeleton className="w-36 h-8 rounded-xl" />
          <Skeleton className="w-48 h-6 rounded-full" />
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Skeleton className="h-44 rounded-2xl" />
          <Skeleton className="h-44 rounded-2xl" />
        </div>
      </div>
    );
  }

  const renderGoalCard = ({ goal, progress, recentContribs }: GoalCardItem) => {
    const percentInt = Math.round(progress.percent * 100);
    const targetDateStr = goal.target_date ? toYMD(goal.target_date) : null;

    let projectionText: React.ReactNode = null;
    if (progress.status.type === 'noDate') {
      if (progress.projectedFinishDate) {
        projectionText = <span>a tu ritmo: {formatMonthYear(progress.projectedFinishDate)}</span>;
      } else {
        projectionText = <span>sin aportes aún</span>;
      }
    } else if (progress.status.type === 'onTrack') {
      if (progress.requiredMonthlyPace != null && progress.requiredMonthlyPace > 0) {
        projectionText = (
          <span>
            necesitás Gs. {formatThousands(progress.requiredMonthlyPace)} por mes
          </span>
        );
      } else {
        projectionText = <span>a tiempo</span>;
      }
    } else if (progress.status.type === 'late') {
      projectionText = (
        <span style={{ color: 'var(--warning)' }}>
          necesitás Gs. {formatThousands(progress.requiredMonthlyPace ?? 0)} por mes
        </span>
      );
    }

    return (
      <div
        key={goal.id}
        className="p-5 rounded-2xl bg-glass-fill border border-glass-border shadow-sm flex flex-col justify-between"
      >
        <div>
          {/* Fila superior: nombre y fecha objetivo */}
          <div className="flex items-start justify-between gap-2">
            <div className="flex items-center gap-2">
              <span className="w-7 h-7 rounded-lg bg-white/5 border border-glass-border grid place-items-center text-text-secondary">
                <Target className="w-3.5 h-3.5" />
              </span>
              <h3 className="font-bold text-base text-text-primary">
                {goal.name}
              </h3>
            </div>
            <span className="text-xs text-text-tertiary">
              {targetDateStr ? formatMonthYear(targetDateStr) : 'sin fecha'}
            </span>
          </div>

          {/* Montos: Ahorrado de Objetivo */}
          <div className="mt-4 flex items-baseline gap-2">
            <span className="text-2xl sm:text-3xl font-extrabold tracking-tight text-text-primary tabular-nums">
              <CountUp value={progress.saved} formatter={formatGs} />
            </span>
            <span className="text-xs sm:text-sm font-semibold text-text-tertiary">
              de Gs. {formatThousands(goal.target_amount)}
            </span>
          </div>

          {/* Barra de progreso */}
          <div className="h-2 rounded-full bg-white/10 mt-3 overflow-hidden">
            <motion.div
              className="h-full rounded-full"
              style={{
                background: 'linear-gradient(90deg, var(--brand-start), var(--brand-end))',
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

          {/* Porcentaje y proyección */}
          <div className="flex items-center justify-between text-xs text-text-secondary mt-3">
            <span>{percentInt} %</span>
            {projectionText}
          </div>
        </div>

        {/* Aportes recientes */}
        {recentContribs.length > 0 && (
          <div className="mt-5 pt-4 border-t border-glass-border space-y-2">
            <div className="flex items-center gap-1.5 text-[11px] font-bold text-text-tertiary uppercase tracking-wider">
              <History className="w-3 h-3" />
              <span>Aportes recientes</span>
            </div>
            <div className="space-y-1.5">
              {recentContribs.map((c) => (
                <div
                  key={c.id}
                  className="flex items-center justify-between text-xs py-1"
                >
                  <span className="text-text-secondary">
                    {c.note || 'Aporte'} · {formatDateShort(c.date)}
                  </span>
                  <span className="font-semibold text-text-primary tabular-nums">
                    Gs. {formatThousands(c.amount)}
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="space-y-8 select-none">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-text-primary">
            Metas
          </h1>
          <div className="text-xs text-text-tertiary mt-1 tabular-nums">
            Ahorrado total Gs. {formatThousands(totalSaved)}
          </div>
        </div>

        {/* Aviso discreto */}
        <span className="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold text-text-tertiary bg-white/5 border border-glass-border">
          Para editar, usá la app
        </span>
      </div>

      {/* Metas activas */}
      <section className="space-y-4">
        {activeGoals.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {activeGoals.map(renderGoalCard)}
          </div>
        ) : (
          <div className="p-8 rounded-2xl bg-glass-fill border border-glass-border text-center text-sm text-text-tertiary">
            No tenés metas activas. Para crear una meta, usá la app.
          </div>
        )}
      </section>

      {/* Metas archivadas */}
      {archivedGoals.length > 0 && (
        <section className="pt-2 border-t border-glass-border">
          <button
            type="button"
            onClick={() => setShowArchived(!showArchived)}
            aria-expanded={showArchived}
            className="flex items-center justify-between w-full p-4 rounded-xl hover:bg-white/5 transition-colors cursor-pointer text-left"
          >
            <div className="flex items-center gap-2 font-bold text-sm text-text-secondary">
              <span>Archivadas ({archivedGoals.length})</span>
            </div>
            <ChevronDown
              className={`w-4 h-4 text-text-tertiary transition-transform duration-200 ${
                showArchived ? 'rotate-180' : ''
              }`}
            />
          </button>

          {showArchived && (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-3 animate-in fade-in duration-200">
              {archivedGoals.map(renderGoalCard)}
            </div>
          )}
        </section>
      )}
    </div>
  );
}
