import React, { useState, useEffect } from 'react';
import { Skeleton } from '@/components/Skeleton';
import { formatGs } from '@/lib/format';
import { useTheme } from '@/lib/theme';
import { cn } from '@/lib/utils';

export interface MovementTableRow {
  id: string;
  type: string;
  amount: number;
  merchant?: string | null;
  note?: string | null;
  occurred_at: number;
  source?: string | null;
  loan_id?: string | null;
  category_id?: string | null;
  category_name?: string | null;
  category_color_dark?: number | null;
  category_color_light?: number | null;
}

export interface MovementsTableProps {
  movements: MovementTableRow[];
  isLoading?: boolean;
  selectedId?: string | null;
  highlightId?: string | null;
  onSelectMovement: (row: MovementTableRow) => void;
  onOpenCreate?: () => void;
}

function parseHexColor(colorInt: number | null | undefined): string {
  if (colorInt == null) return '#9CA3AF';
  const rgb = colorInt & 0x00ffffff;
  return `#${rgb.toString(16).padStart(6, '0')}`;
}

function formatDayHeader(dateKey: string): string {
  const [year, month, day] = dateKey.split('-').map(Number);
  const d = new Date(year, month - 1, day);
  const today = new Date();
  const yesterday = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1);

  const isToday =
    today.getFullYear() === d.getFullYear() &&
    today.getMonth() === d.getMonth() &&
    today.getDate() === d.getDate();

  const isYesterday =
    yesterday.getFullYear() === d.getFullYear() &&
    yesterday.getMonth() === d.getMonth() &&
    yesterday.getDate() === d.getDate();

  const formatted = d.toLocaleDateString('es-PY', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
  });

  if (isToday) return `Hoy · ${formatted}`;
  if (isYesterday) return `Ayer · ${formatted}`;
  return formatted;
}

function formatTimeOnly(timestampInSecondsOrMs: number): string {
  const ms = timestampInSecondsOrMs > 1e11 ? timestampInSecondsOrMs : timestampInSecondsOrMs * 1000;
  const d = new Date(ms);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function mapSourceToLabel(source?: string | null): string {
  switch (source) {
    case 'manual':
      return 'Manual';
    case 'recurring':
      return 'Recurrente';
    case 'incomeSchedule':
      return 'Sueldo';
    case 'capture':
      return 'Captura';
    default:
      return source || 'Manual';
  }
}

export function MovementsTable({
  movements,
  isLoading,
  selectedId,
  highlightId,
  onSelectMovement,
  onOpenCreate,
}: MovementsTableProps) {
  const { resolvedTheme } = useTheme();
  const [currentPage, setCurrentPage] = useState(1);
  const pageSize = 100;

  useEffect(() => {
    setCurrentPage(1);
  }, [movements]);

  if (isLoading) {
    return (
      <div
        data-testid="movimientos-skeleton"
        className="rounded-3xl p-6 bg-glass-fill border border-glass-border space-y-4"
      >
        <div className="flex justify-between items-center">
          <Skeleton className="h-6 w-48" />
          <Skeleton className="h-6 w-24" />
        </div>
        <Skeleton className="h-12 w-full" />
        <Skeleton className="h-12 w-full" />
        <Skeleton className="h-12 w-full" />
        <Skeleton className="h-12 w-full" />
        <Skeleton className="h-12 w-full" />
      </div>
    );
  }

  if (!movements || movements.length === 0) {
    return (
      <div className="rounded-3xl p-16 bg-glass-fill border border-glass-border text-center flex flex-col items-center justify-center">
        <div className="w-12 h-12 rounded-2xl bg-white/5 border border-glass-border grid place-items-center text-text-tertiary mb-3">
          <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
            <rect x="4" y="4" width="16" height="16" rx="2" />
            <line x1="8" y1="9" x2="16" y2="9" />
            <line x1="8" y1="13" x2="14" y2="13" />
            <line x1="8" y1="17" x2="10" y2="17" />
          </svg>
        </div>
        <h3 className="text-[16px] font-bold text-text-primary">No hay movimientos registrados</h3>
        <p className="text-[13px] text-text-tertiary mt-1 max-w-sm">
          No se encontraron movimientos con los filtros aplicados o aún no tenés movimientos cargados.
        </p>
        {onOpenCreate && (
          <button
            type="button"
            onClick={onOpenCreate}
            className="mt-5 px-4 py-2 rounded-xl font-bold text-[13px] text-white shadow-sm active:scale-95 transition-transform"
            style={{
              background: 'linear-gradient(90deg, var(--brand-start), var(--brand-end))',
            }}
          >
            Cargá el primero
          </button>
        )}
      </div>
    );
  }

  // Slicing for pagination (>100 items)
  const totalPages = Math.ceil(movements.length / pageSize);
  const pagedMovements = movements.slice(
    (currentPage - 1) * pageSize,
    currentPage * pageSize
  );

  // Group paged movements by date key (YYYY-MM-DD)
  const groups: Array<{
    dateKey: string;
    items: MovementTableRow[];
    daySpent: number;
    dayEarned: number;
  }> = [];

  for (const m of pagedMovements) {
    const ms = m.occurred_at > 1e11 ? m.occurred_at : m.occurred_at * 1000;
    const d = new Date(ms);
    const pad = (n: number) => String(n).padStart(2, '0');
    const dateKey = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

    let lastGroup = groups[groups.length - 1];
    if (!lastGroup || lastGroup.dateKey !== dateKey) {
      lastGroup = { dateKey, items: [], daySpent: 0, dayEarned: 0 };
      groups.push(lastGroup);
    }
    lastGroup.items.push(m);
    if (m.type === 'expense') {
      lastGroup.daySpent += Math.abs(m.amount);
    } else if (m.type === 'income') {
      lastGroup.dayEarned += Math.abs(m.amount);
    }
  }

  return (
    <div className="space-y-4">
      <div className="rounded-3xl overflow-hidden bg-glass-fill border border-glass-border shadow-sm">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-[13.5px] border-collapse block sm:table sm:table-fixed">
            <thead className="hidden sm:table-header-group">
              <tr className="border-b border-white/5 text-[12px] font-semibold text-text-tertiary">
                <th className="py-3 px-6">Descripción</th>
                <th className="py-3 px-4 w-36">Categoría</th>
                <th className="py-3 px-4 w-24">Fecha</th>
                <th className="py-3 px-4 hidden md:table-cell md:w-24">Origen</th>
                <th className="py-3 px-6 text-right w-36 shrink-0">Monto</th>
              </tr>
            </thead>
            <tbody className="block sm:table-row-group">
              {groups.map((group) => (
                <React.Fragment key={group.dateKey}>
                  {/* Day header with day subtotal */}
                  <tr className="bg-white/[0.03] border-t border-b border-white/5 text-[12px] font-semibold text-text-tertiary block sm:table-row">
                    <td colSpan={5} className="py-2 px-3.5 sm:px-6 block sm:table-cell">
                      <div className="flex items-center justify-between flex-wrap gap-y-1 gap-x-3">
                        <span>{formatDayHeader(group.dateKey)}</span>
                        <div className="flex gap-3 text-[11.5px] font-medium tabular-nums flex-wrap">
                          {group.daySpent > 0 && (
                            <span>Salieron: {formatGs(-group.daySpent)}</span>
                          )}
                          {group.dayEarned > 0 && (
                            <span className="text-positive">
                              Entraron: {formatGs(group.dayEarned, { explicitSign: true })}
                            </span>
                          )}
                        </div>
                      </div>
                    </td>
                  </tr>

                  {/* Transactions of this day */}
                  {group.items.map((tx) => {
                    const detail = tx.merchant || tx.note || 'Sin detalle';
                    const categoryName = tx.category_name || 'Sin categoría';
                    const colorInt =
                      resolvedTheme === 'dark'
                        ? tx.category_color_dark
                        : tx.category_color_light;
                    const dotColor = parseHexColor(colorInt ?? tx.category_color_dark);

                    const isExpense = tx.type === 'expense';
                    const formattedAmount = isExpense
                      ? formatGs(-Math.abs(tx.amount))
                      : formatGs(Math.abs(tx.amount), { explicitSign: true });

                    const isSelected = selectedId === tx.id;
                    const isHighlighted = highlightId === tx.id;

                    return (
                      <tr
                        key={tx.id}
                        tabIndex={0}
                        onClick={() => onSelectMovement(tx)}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter') {
                            e.preventDefault();
                            onSelectMovement(tx);
                          }
                        }}
                        className={cn(
                          'cursor-pointer border-b border-white/5 transition-all outline-none',
                          'hover:bg-white/[0.04] focus-visible:bg-white/[0.06]',
                          'flex items-center justify-between gap-3 py-3 px-3.5 sm:table-row sm:py-0 sm:px-0',
                          isSelected && 'bg-brand-start/10',
                          isHighlighted && 'animate-pulse bg-brand-start/20'
                        )}
                      >
                        {/* Name & detail with category dot */}
                        <td className="p-0 sm:py-3 sm:px-6 font-medium text-text-primary min-w-0 flex-1 flex items-center gap-2.5 sm:table-cell">
                          <span
                            className="w-2.5 h-2.5 rounded-full shrink-0 shadow-sm"
                            style={{ backgroundColor: dotColor }}
                            aria-hidden="true"
                          />
                          <div className="min-w-0 flex-1 truncate">
                            <span className="block truncate">{detail}</span>
                            {tx.merchant && tx.note && (
                              <span className="block text-[11.5px] text-text-tertiary truncate">
                                {tx.note}
                              </span>
                            )}
                            <span className="block text-[11.5px] text-text-tertiary sm:hidden truncate">
                              {categoryName}
                            </span>
                          </div>
                          {tx.loan_id && (
                            <span className="ml-1.5 px-2 py-0.5 rounded-full text-[10.5px] font-bold uppercase tracking-wider bg-amber-500/15 text-amber-300 border border-amber-500/30 shrink-0">
                              Préstamo
                            </span>
                          )}
                        </td>

                        {/* Category */}
                        <td className="py-3 px-4 text-text-tertiary hidden sm:table-cell">
                          {categoryName}
                        </td>

                        {/* Time */}
                        <td className="py-3 px-4 text-text-tertiary whitespace-nowrap text-[13px] tabular-nums hidden sm:table-cell">
                          {formatTimeOnly(tx.occurred_at)}
                        </td>

                        {/* Origin */}
                        <td className="py-3 px-4 text-text-tertiary hidden md:table-cell text-[12.5px]">
                          <span className="px-2 py-0.5 rounded-md bg-white/5 border border-white/5">
                            {mapSourceToLabel(tx.source)}
                          </span>
                        </td>

                        {/* Amount */}
                        <td
                          className={cn(
                            'p-0 sm:py-3 sm:px-6 text-right font-bold tabular-nums whitespace-nowrap shrink-0 sm:table-cell sm:w-36',
                            isExpense ? 'text-text-primary' : 'text-positive'
                          )}
                        >
                          {formattedAmount}
                        </td>
                      </tr>
                    );
                  })}
                </React.Fragment>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Pagination controls if more than pageSize */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between px-2 text-[13px] text-text-tertiary">
          <div>
            Mostrando {(currentPage - 1) * pageSize + 1}–
            {Math.min(currentPage * pageSize, movements.length)} de {movements.length}
          </div>
          <div className="flex gap-2">
            <button
              type="button"
              disabled={currentPage <= 1}
              onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
              className="px-3 py-1.5 rounded-xl border border-glass-border bg-glass-fill disabled:opacity-40 disabled:cursor-not-allowed hover:bg-white/5 active:scale-95 transition-all"
            >
              Anterior
            </button>
            <span className="py-1.5 px-2 font-medium">
              {currentPage} / {totalPages}
            </span>
            <button
              type="button"
              disabled={currentPage >= totalPages}
              onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
              className="px-3 py-1.5 rounded-xl border border-glass-border bg-glass-fill disabled:opacity-40 disabled:cursor-not-allowed hover:bg-white/5 active:scale-95 transition-all"
            >
              Siguiente
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
