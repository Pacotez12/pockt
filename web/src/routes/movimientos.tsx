import React, { useEffect } from 'react';
import { useQuery } from '@powersync/react';
import { Skeleton } from '@/components/Skeleton';
import { formatGs } from '@/lib/format';
import { useTheme } from '@/lib/theme';

export interface MovementRow {
  id: string;
  type: string;
  amount: number;
  merchant?: string | null;
  note?: string | null;
  occurred_at: number;
  category_name?: string | null;
  category_color_dark?: number | null;
  category_color_light?: number | null;
}

function parseHexColor(colorInt: number | null | undefined): string {
  if (colorInt == null) return '#9CA3AF';
  const rgb = colorInt & 0x00ffffff;
  return `#${rgb.toString(16).padStart(6, '0')}`;
}

function formatDate(timestampInSecondsOrMs: number): string {
  const ms = timestampInSecondsOrMs > 1e11 ? timestampInSecondsOrMs : timestampInSecondsOrMs * 1000;
  const d = new Date(ms);
  return d.toLocaleDateString('es-PY', { day: 'numeric', month: 'short' });
}

export function MovimientosRoute() {
  const { resolvedTheme } = useTheme();

  useEffect(() => {
    document.title = 'Movimientos · Pockt';
  }, []);

  const { data: movements, isLoading } = useQuery<MovementRow>(
    `SELECT 
      t.id, t.type, t.amount, t.merchant, t.note, t.occurred_at,
      c.name as category_name, c.color_dark as category_color_dark, c.color_light as category_color_light
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    WHERE t.deleted_at IS NULL
    ORDER BY t.occurred_at DESC
    LIMIT 50`
  );

  return (
    <div className="space-y-6">
      {/* Page Title & Count */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-[26px] sm:text-[28px] font-extrabold tracking-tight text-text-primary">
            Movimientos
          </h1>
          <div className="text-[13px] text-text-tertiary mt-0.5">
            Últimos {movements ? movements.length : 0} movimientos (solo lectura)
          </div>
        </div>
      </div>

      {/* Main Table Card */}
      {isLoading ? (
        <div data-testid="movimientos-skeleton" className="rounded-2xl p-6 bg-glass-fill border border-glass-border space-y-4">
          <Skeleton className="h-6 w-48" />
          <Skeleton className="h-10 w-full" />
          <Skeleton className="h-10 w-full" />
          <Skeleton className="h-10 w-full" />
          <Skeleton className="h-10 w-full" />
        </div>
      ) : !movements || movements.length === 0 ? (
        <div className="rounded-2xl p-12 bg-glass-fill border border-glass-border text-center text-text-secondary text-[14px]">
          No hay movimientos registrados
        </div>
      ) : (
        <div className="rounded-2xl overflow-hidden bg-glass-fill border border-glass-border shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-[13.5px] border-collapse">
              <thead>
                <tr className="border-b border-white/5 text-[12px] font-semibold text-text-tertiary">
                  <th className="py-3 px-5 sm:px-6">Comercio / Detalle</th>
                  <th className="py-3 px-4 hidden sm:table-cell">Categoría</th>
                  <th className="py-3 px-4">Fecha</th>
                  <th className="py-3 px-5 sm:px-6 text-right">Monto</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {movements.map((tx) => {
                  const detail = tx.merchant || tx.note || 'Sin detalle';
                  const categoryName = tx.category_name || 'Sin categoría';
                  const colorInt = resolvedTheme === 'dark' ? tx.category_color_dark : tx.category_color_light;
                  const dotColor = parseHexColor(colorInt ?? tx.category_color_dark);

                  const isExpense = tx.type === 'expense';
                  const formattedAmount = isExpense
                    ? formatGs(-Math.abs(tx.amount))
                    : formatGs(Math.abs(tx.amount), { explicitSign: true });

                  return (
                    <tr
                      key={tx.id}
                      className="hover:bg-white/[0.02] transition-colors"
                    >
                      {/* Name with category dot */}
                      <td className="py-3.5 px-5 sm:px-6 font-medium text-text-primary">
                        <div className="flex items-center gap-2.5">
                          <span
                            className="w-2 h-2 rounded-full shrink-0 shadow-sm"
                            style={{ backgroundColor: dotColor }}
                            aria-hidden="true"
                          />
                          <span className="truncate max-w-[220px] sm:max-w-none">{detail}</span>
                        </div>
                      </td>

                      {/* Category */}
                      <td className="py-3.5 px-4 text-text-tertiary hidden sm:table-cell">
                        {categoryName}
                      </td>

                      {/* Date */}
                      <td className="py-3.5 px-4 text-text-tertiary whitespace-nowrap">
                        {formatDate(tx.occurred_at)}
                      </td>

                      {/* Amount with sign */}
                      <td className="py-3.5 px-5 sm:px-6 text-right font-semibold tabular-nums text-text-primary whitespace-nowrap">
                        {formattedAmount}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
