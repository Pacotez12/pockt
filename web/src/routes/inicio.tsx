import React, { useEffect } from 'react';
import { motion, useReducedMotion } from 'motion/react';
import { useQuery } from '@powersync/react';
import { Skeleton } from '@/components/Skeleton';
import { CountUp } from '@/components/CountUp';
import { AuroraShader } from '@/components/AuroraShader';
import { formatMonthYear, calculateMonthExpenses } from '@/lib/calculations';
import type { TransactionRow } from '@/lib/powersync/schema';

export function InicioRoute() {
  const prefersReduced = useReducedMotion();

  useEffect(() => {
    document.title = 'Inicio · Pockt';
  }, []);

  const now = new Date();
  const { monthName, year, title } = formatMonthYear(now);

  // Month bounds in seconds
  const startOfMonth = Math.floor(new Date(year, now.getMonth(), 1, 0, 0, 0, 0).getTime() / 1000);
  const endOfMonth = Math.floor(new Date(year, now.getMonth() + 1, 1, 0, 0, 0, 0).getTime() / 1000);

  const { data: transactions, isLoading } = useQuery<TransactionRow>(
    'SELECT * FROM transactions WHERE type = ? AND deleted_at IS NULL AND occurred_at >= ? AND occurred_at < ?',
    ['expense', startOfMonth, endOfMonth]
  );

  const totalSpent = calculateMonthExpenses(transactions || [], year, now.getMonth() + 1);

  return (
    <div className="space-y-6 relative">
      {/* Subtle AuroraShader behind Inicio */}
      <AuroraShader opacity={0.22} interactive={false} />

      {/* Header */}
      <div>
        <h1 className="text-[26px] sm:text-[28px] font-extrabold tracking-tight text-text-primary">
          {title}
        </h1>
      </div>

      {/* Main KPI Card */}
      {isLoading ? (
        <div data-testid="inicio-skeleton" className="max-w-[420px] w-full">
          <Skeleton className="h-[140px] w-full rounded-2xl" />
        </div>
      ) : (
        <motion.div
          initial={prefersReduced ? false : { opacity: 0, y: 14, scale: 0.98 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={
            prefersReduced
              ? { duration: 0 }
              : { type: 'spring', stiffness: 280, damping: 24 }
          }
          className="max-w-[420px] w-full rounded-2xl p-5 sm:p-6 bg-glass-fill border border-glass-border shadow-sm backdrop-blur-md"
        >
          <div className="text-[12.5px] font-medium text-text-secondary">
            Gastado en {monthName}
          </div>
          <div className="text-[32px] sm:text-[36px] font-extrabold tracking-tight text-text-primary mt-2 tabular-nums">
            <CountUp value={totalSpent} />
          </div>
        </motion.div>
      )}
    </div>
  );
}
