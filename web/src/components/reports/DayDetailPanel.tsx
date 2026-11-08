import React, { useEffect, useMemo } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { useReducedMotion } from 'motion/react';
import { Link } from 'react-router-dom';
import { ArrowUpRight } from 'lucide-react';
import { cn } from '@/lib/utils';
import { formatGs } from '@/lib/format';
import { useTheme } from '@/lib/theme';
import { useFocusTrap } from '@/lib/useFocusTrap';

export interface DayDetailTransaction {
  id: string;
  type: string;
  amount: number;
  category_id?: string | null;
  category_name?: string | null;
  category_color_dark?: number | null;
  category_color_light?: number | null;
  merchant?: string | null;
  note?: string | null;
  occurred_at: number;
  loan_id?: string | null;
  source?: string | null;
}

export interface DayDetailPanelProps {
  isOpen: boolean;
  dateKey: string | null; // "YYYY-MM-DD"
  transactions: DayDetailTransaction[];
  onClose: () => void;
  onSelectTransaction: (tx: DayDetailTransaction) => void;
}

export function formatLongDate(dateKey: string): string {
  const [y, m, d] = dateKey.split('-').map(Number);
  const dateObj = new Date(y, m - 1, d);
  const weekday = dateObj.toLocaleDateString('es-PY', { weekday: 'long' });
  const day = dateObj.getDate();
  const month = dateObj.toLocaleDateString('es-PY', { month: 'long' });
  // Solo la primera letra en mayúscula: "Martes 3 de noviembre".
  const label = `${weekday} ${day} de ${month}`;
  return label.charAt(0).toUpperCase() + label.slice(1);
}

function formatTimeOnly(secondsOrMs: number): string {
  const ms = secondsOrMs > 1e11 ? secondsOrMs : secondsOrMs * 1000;
  const d = new Date(ms);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function parseHexColor(colorInt: number | string | null | undefined): string {
  if (colorInt == null) return '#9CA3AF';
  if (typeof colorInt === 'string' && colorInt.startsWith('#')) return colorInt;
  const num = typeof colorInt === 'number' ? colorInt : parseInt(String(colorInt), 10);
  if (isNaN(num)) return '#9CA3AF';
  const rgb = num & 0x00ffffff;
  return `#${rgb.toString(16).padStart(6, '0')}`;
}

export function DayDetailPanel({
  isOpen,
  dateKey,
  transactions,
  onClose,
  onSelectTransaction,
}: DayDetailPanelProps) {
  const prefersReducedMotion = useReducedMotion();
  const { resolvedTheme } = useTheme();

  const panelRef = useFocusTrap<HTMLElement>(isOpen, onClose);

  const { totalSpent, totalEarned } = useMemo(() => {
    let spent = 0;
    let earned = 0;
    for (const tx of transactions) {
      if (tx.type === 'expense') {
        spent += Math.abs(tx.amount);
      } else if (tx.type === 'income') {
        earned += Math.abs(tx.amount);
      }
    }
    return { totalSpent: spent, totalEarned: earned };
  }, [transactions]);

  const formattedDate = dateKey ? formatLongDate(dateKey) : '';

  return (
    <AnimatePresence>
      {isOpen && dateKey && (
        <>
          {/* Backdrop (closes on click on mobile & desktop) */}
          <motion.div
            data-testid="day-detail-backdrop"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 bg-black/40 backdrop-blur-xs z-40"
            aria-hidden="true"
          />

          {/* Sliding Panel */}
          <motion.aside
            ref={panelRef}
            role="dialog"
            aria-modal="true"
            aria-labelledby="day-panel-title"
            initial={
              prefersReducedMotion
                ? { opacity: 0 }
                : { x: '100%', opacity: 0 }
            }
            animate={
              prefersReducedMotion
                ? { opacity: 1 }
                : { x: 0, opacity: 1 }
            }
            exit={
              prefersReducedMotion
                ? { opacity: 0 }
                : { x: '100%', opacity: 0 }
            }
            transition={{
              type: 'spring',
              stiffness: 300,
              damping: 28,
              mass: 0.8,
            }}
            className={cn(
              'fixed top-[72px] right-3 sm:right-6 bottom-4 z-50',
              'w-[calc(100vw-24px)] sm:w-[440px]',
              'rounded-3xl p-6 flex flex-col',
              'bg-sheet-surface/95 dark:bg-sheet-surface/95 backdrop-blur-xl',
              'border border-glass-border shadow-2xl overflow-hidden'
            )}
          >
            {/* Header */}
            <div className="flex items-start justify-between pb-4 border-b border-white/5">
              <div className="min-w-0 pr-3">
                <h2
                  id="day-panel-title"
                  className="text-[17px] font-bold text-text-primary tracking-tight truncate"
                >
                  {formattedDate}
                </h2>
                <div className="flex items-center gap-3 text-[12.5px] font-medium tabular-nums mt-1 flex-wrap">
                  {totalSpent > 0 && (
                    <span className="text-text-secondary whitespace-nowrap">
                      Salieron:{' '}
                      <span className="font-semibold text-text-primary whitespace-nowrap">
                        {formatGs(-totalSpent)}
                      </span>
                    </span>
                  )}
                  {totalEarned > 0 && (
                    <span className="text-text-secondary whitespace-nowrap">
                      Entraron:{' '}
                      <span className="font-semibold text-positive whitespace-nowrap">
                        {formatGs(totalEarned, { explicitSign: true })}
                      </span>
                    </span>
                  )}
                </div>
              </div>

              <button
                type="button"
                onClick={onClose}
                aria-label="Cerrar panel"
                className="w-10 h-10 min-w-[40px] min-h-[40px] rounded-full grid place-items-center bg-glass-fill border border-glass-border text-text-tertiary hover:text-text-primary active:scale-95 transition-all cursor-pointer shrink-0"
              >
                <svg
                  className="w-4 h-4"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                >
                  <path d="M18 6L6 18M6 6l12 12" />
                </svg>
              </button>
            </div>

            {/* Link to Movimientos filtered by this day */}
            <div className="py-2.5 flex items-center justify-between border-b border-white/5 text-[12.5px]">
              <span className="text-text-tertiary">
                {transactions.length === 1
                  ? '1 movimiento'
                  : `${transactions.length} movimientos`}
              </span>
              <Link
                to={`/movimientos?desde=${dateKey}&hasta=${dateKey}`}
                className="min-h-[40px] inline-flex items-center gap-1 font-semibold text-brand-primary hover:underline group"
              >
                Ver en Movimientos
                <ArrowUpRight className="w-3.5 h-3.5 group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-transform" />
              </Link>
            </div>

            {/* Movements list or empty state */}
            <div className="flex-1 overflow-y-auto divide-y divide-white/5 py-2">
              {transactions.length === 0 ? (
                <div className="py-16 text-center text-text-tertiary text-[13.5px]">
                  Sin movimientos este día
                </div>
              ) : (
                transactions.map((tx) => {
                  const detail = tx.merchant || tx.note || 'Sin detalle';
                  const categoryName = tx.category_name || 'Sin categoría';
                  const colorInt =
                    resolvedTheme === 'dark'
                      ? tx.category_color_dark
                      : tx.category_color_light;
                  const dotColor = parseHexColor(
                    colorInt ?? tx.category_color_dark
                  );

                  const isExpense = tx.type === 'expense';
                  const formattedAmount = isExpense
                    ? formatGs(-Math.abs(tx.amount))
                    : formatGs(Math.abs(tx.amount), { explicitSign: true });

                  return (
                    <div
                      key={tx.id}
                      role="button"
                      tabIndex={0}
                      onClick={() => onSelectTransaction(tx)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                          e.preventDefault();
                          onSelectTransaction(tx);
                        }
                      }}
                      className={cn(
                        'flex items-center justify-between gap-3 py-3 px-2 rounded-xl cursor-pointer transition-all outline-none',
                        'hover:bg-white/[0.04] focus-visible:bg-white/[0.06] active:scale-[0.99]'
                      )}
                    >
                      {/* Category dot + Merchant/note */}
                      <div className="flex items-center gap-2.5 min-w-0 flex-1">
                        <span
                          className="w-2.5 h-2.5 rounded-full shrink-0 shadow-sm"
                          style={{ backgroundColor: dotColor }}
                          aria-hidden="true"
                        />
                        <div className="min-w-0 flex-1 truncate">
                          <div className="flex items-center gap-1.5">
                            <span className="font-medium text-text-primary text-[13.5px] truncate">
                              {detail}
                            </span>
                            {tx.loan_id && (
                              <span className="px-1.5 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider bg-amber-500/15 text-amber-300 border border-amber-500/30 shrink-0">
                                Préstamo
                              </span>
                            )}
                          </div>
                          <div className="flex items-center gap-2 text-[11.5px] text-text-tertiary mt-0.5">
                            <span className="truncate">{categoryName}</span>
                            <span>·</span>
                            <span className="tabular-nums shrink-0">
                              {formatTimeOnly(tx.occurred_at)}
                            </span>
                          </div>
                        </div>
                      </div>

                      {/* Amount with sign and color */}
                      <div
                        className={cn(
                          'text-right font-bold tabular-nums whitespace-nowrap text-[13.5px] shrink-0',
                          isExpense ? 'text-text-primary' : 'text-positive'
                        )}
                      >
                        {formattedAmount}
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          </motion.aside>
        </>
      )}
    </AnimatePresence>
  );
}
