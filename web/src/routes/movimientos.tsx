import React, { useEffect, useState, useMemo } from 'react';
import { useQuery, usePowerSync } from '@powersync/react';
import { useSearchParams } from 'react-router-dom';
import { CountUp } from '@/components/CountUp';
import {
  MovementFiltersBar,
  FilterState,
} from '@/components/movements/MovementFiltersBar';
import {
  MovementsTable,
  MovementTableRow,
} from '@/components/movements/MovementsTable';
import {
  MovementPanel,
  CategoryOption,
} from '@/components/movements/MovementPanel';
import { buildMovementsQuery, periodTotals } from '@/lib/movements/query';
import {
  toCsv,
  toXlsx,
  downloadBlob,
  getExportFilename,
} from '@/lib/movements/export';
import { restoreMovement } from '@/lib/movements/write';

function getPeriodTimestamps(period?: string, desde?: string, hasta?: string): {
  startDate?: number;
  endDate?: number;
  allDates?: boolean;
} {
  if (desde || hasta) {
    let startDate: number | undefined;
    let endDate: number | undefined;
    if (desde) {
      const [y, m, d] = desde.split('-').map(Number);
      startDate = Math.floor(new Date(y, m - 1, d, 0, 0, 0, 0).getTime() / 1000);
    }
    if (hasta) {
      const [y, m, d] = hasta.split('-').map(Number);
      endDate = Math.floor(new Date(y, m - 1, d, 23, 59, 59, 999).getTime() / 1000);
    }
    return { startDate, endDate };
  }

  const now = new Date();
  if (period === 'last_month') {
    const start = new Date(now.getFullYear(), now.getMonth() - 1, 1, 0, 0, 0, 0);
    const end = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);
    return {
      startDate: Math.floor(start.getTime() / 1000),
      endDate: Math.floor(end.getTime() / 1000),
    };
  }
  if (period === 'year') {
    const start = new Date(now.getFullYear(), 0, 1, 0, 0, 0, 0);
    const end = new Date(now.getFullYear(), 11, 31, 23, 59, 59, 999);
    return {
      startDate: Math.floor(start.getTime() / 1000),
      endDate: Math.floor(end.getTime() / 1000),
    };
  }
  if (period === 'all') {
    return { allDates: true };
  }
  // Default: this_month
  const start = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
  const end = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
  return {
    startDate: Math.floor(start.getTime() / 1000),
    endDate: Math.floor(end.getTime() / 1000),
  };
}

export function MovimientosRoute() {
  const db = usePowerSync();
  const [searchParams, setSearchParams] = useSearchParams();

  // Read URL search params
  const search = searchParams.get('q') || '';
  const desde = searchParams.get('desde') || undefined;
  const hasta = searchParams.get('hasta') || undefined;
  const period = (searchParams.get('period') as any) || (desde || hasta ? 'custom' : 'this_month');
  const categoryId = searchParams.get('cat') || undefined;
  const type = (searchParams.get('tipo') as any) || undefined;
  const source = (searchParams.get('origen') as any) || undefined;
  const minAmount = searchParams.get('min')
    ? parseInt(searchParams.get('min')!, 10)
    : undefined;
  const maxAmount = searchParams.get('max')
    ? parseInt(searchParams.get('max')!, 10)
    : undefined;
  const isCreateParam = searchParams.get('crear') === '1';

  // Panel state
  const [isPanelOpen, setIsPanelOpen] = useState(isCreateParam);
  const [editingMovement, setEditingMovement] = useState<MovementTableRow | null>(null);
  const [highlightId, setHighlightId] = useState<string | null>(null);

  // Undo delete notification state
  const [deletedMovementId, setDeletedMovementId] = useState<string | null>(null);
  const [undoToastVisible, setUndoToastVisible] = useState(false);

  useEffect(() => {
    document.title = 'Movimientos · Pockt';
  }, []);

  // Update filters in URL
  const updateUrlFilters = (updater: (prev: URLSearchParams) => void) => {
    const next = new URLSearchParams(searchParams);
    updater(next);
    setSearchParams(next, { replace: true });
  };

  const handleSearchChange = (newSearch: string) => {
    updateUrlFilters((params) => {
      if (newSearch) {
        params.set('q', newSearch);
      } else {
        params.delete('q');
      }
    });
  };

  const currentFilters: FilterState = useMemo(
    () => ({
      period,
      categoryId,
      type,
      source,
      minAmount,
      maxAmount,
    }),
    [period, categoryId, type, source, minAmount, maxAmount]
  );

  const handleFiltersChange = (newFilters: FilterState) => {
    updateUrlFilters((params) => {
      if (newFilters.period && newFilters.period !== 'this_month') {
        params.set('period', newFilters.period);
      } else {
        params.delete('period');
      }

      if (newFilters.categoryId) {
        params.set('cat', newFilters.categoryId);
      } else {
        params.delete('cat');
      }

      if (newFilters.type) {
        params.set('tipo', newFilters.type);
      } else {
        params.delete('tipo');
      }

      if (newFilters.source) {
        params.set('origen', newFilters.source);
      } else {
        params.delete('origen');
      }

      if (newFilters.minAmount !== undefined) {
        params.set('min', String(newFilters.minAmount));
      } else {
        params.delete('min');
      }

      if (newFilters.maxAmount !== undefined) {
        params.set('max', String(newFilters.maxAmount));
      } else {
        params.delete('max');
      }
    });
  };

  const handleClearFilters = () => {
    setSearchParams(new URLSearchParams(), { replace: true });
  };

  // Build query
  const dateRange = getPeriodTimestamps(period, desde, hasta);
  const queryConfig = useMemo(() => {
    return buildMovementsQuery({
      startDate: dateRange.startDate,
      endDate: dateRange.endDate,
      allDates: dateRange.allDates,
      categoryId,
      type,
      source,
      minAmount,
      maxAmount,
      search,
    });
  }, [
    dateRange.startDate,
    dateRange.endDate,
    dateRange.allDates,
    categoryId,
    type,
    source,
    minAmount,
    maxAmount,
    search,
  ]);

  const { data: movements, isLoading } = useQuery<MovementTableRow>(
    queryConfig.sql,
    queryConfig.params
  );

  // Categories for select & filters
  const { data: rawCategories } = useQuery<CategoryOption>(
    `SELECT id, name, kind, sort_order, color_dark, color_light, icon
     FROM categories
     WHERE archived = 0
     ORDER BY sort_order ASC`
  );
  const categories = rawCategories || [];

  // Totals of the active period
  const totals = useMemo(() => {
    return periodTotals(movements || []);
  }, [movements]);

  // Open create panel listener from TopNav or URL
  useEffect(() => {
    const handleOpenCreateEvent = () => {
      setEditingMovement(null);
      setIsPanelOpen(true);
    };
    window.addEventListener('pockt:open-create-movement', handleOpenCreateEvent);
    return () =>
      window.removeEventListener('pockt:open-create-movement', handleOpenCreateEvent);
  }, []);

  useEffect(() => {
    if (isCreateParam) {
      setEditingMovement(null);
      setIsPanelOpen(true);
      // clean param from url
      updateUrlFilters((p) => p.delete('crear'));
    }
  }, [isCreateParam]);

  // Keyboard shortcut 'n' / 'N' to open panel
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'n' || e.key === 'N') {
        const target = e.target as HTMLElement | null;
        const tag = target && target.tagName ? target.tagName.toLowerCase() : '';
        if (tag === 'input' || tag === 'textarea' || tag === 'select' || target?.isContentEditable) {
          return;
        }
        e.preventDefault();
        setEditingMovement(null);
        setIsPanelOpen(true);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  // Export handlers
  const handleExportCsv = () => {
    const csvContent = toCsv((movements as any) || []);
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    downloadBlob(blob, getExportFilename('csv'));
  };

  const handleExportXlsx = async () => {
    const xlsxBuffer = await toXlsx((movements as any) || []);
    const blob = new Blob([xlsxBuffer as any], {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    });
    downloadBlob(blob, getExportFilename('xlsx'));
  };

  // Row selection handler
  const handleSelectMovement = (row: MovementTableRow) => {
    setEditingMovement(row);
    setIsPanelOpen(true);
  };

  // Saved / Deleted callbacks
  const handleSaved = (id: string) => {
    setHighlightId(id);
    setTimeout(() => setHighlightId(null), 3000);
  };

  const handleDeleted = (id: string) => {
    setDeletedMovementId(id);
    setUndoToastVisible(true);
    setTimeout(() => {
      setUndoToastVisible(false);
    }, 5000);
  };

  const handleUndo = async () => {
    if (!deletedMovementId) return;
    try {
      await restoreMovement(db, deletedMovementId);
      setUndoToastVisible(false);
      setDeletedMovementId(null);
    } catch (e) {
      console.error('Error al deshacer borrado:', e);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header & Resumen */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
        <div>
          <h1 className="text-[26px] sm:text-[28px] font-extrabold tracking-tight text-text-primary">
            Movimientos
          </h1>
          <div className="text-[13px] text-text-tertiary mt-0.5 flex flex-wrap items-center gap-1.5 tabular-nums">
            <span>{totals.count} movimientos</span>
            <span>·</span>
            <span>
              salieron <CountUp value={totals.spent} />
            </span>
            <span>·</span>
            <span className="text-positive font-semibold">
              entraron <CountUp value={totals.earned} />
            </span>
          </div>
        </div>
      </div>

      {/* Search & Filter Bar */}
      <MovementFiltersBar
        search={search}
        onSearchChange={handleSearchChange}
        filters={currentFilters}
        onFiltersChange={handleFiltersChange}
        onClearFilters={handleClearFilters}
        categories={categories}
        onExportCsv={handleExportCsv}
        onExportXlsx={handleExportXlsx}
      />

      {/* Main Table */}
      <MovementsTable
        movements={movements || []}
        isLoading={isLoading}
        selectedId={editingMovement?.id}
        highlightId={highlightId}
        onSelectMovement={handleSelectMovement}
        onOpenCreate={() => {
          setEditingMovement(null);
          setIsPanelOpen(true);
        }}
      />

      {/* Lateral Panel (Drawer) for Create / Edit */}
      <MovementPanel
        isOpen={isPanelOpen}
        movement={editingMovement}
        db={db}
        categories={categories}
        onClose={() => {
          setIsPanelOpen(false);
          setEditingMovement(null);
        }}
        onSaved={handleSaved}
        onDeleted={handleDeleted}
      />

      {/* Undo Toast Notification */}
      {undoToastVisible && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 px-4 py-3 rounded-2xl bg-sheet-surface/95 border border-glass-border shadow-2xl backdrop-blur-md flex items-center gap-3.5 animate-in fade-in slide-in-from-bottom-3 duration-200">
          <div className="text-[13px] text-text-primary">
            <span>Movimiento borrado. Se borra también del teléfono.</span>
          </div>
          <button
            type="button"
            onClick={handleUndo}
            className="px-3 py-1 rounded-xl bg-brand-start/20 border border-brand-start/40 text-brand-start font-bold text-[12.5px] hover:bg-brand-start/30 active:scale-95 transition-all cursor-pointer"
          >
            Deshacer
          </button>
        </div>
      )}
    </div>
  );
}
