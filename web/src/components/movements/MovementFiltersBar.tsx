import React, { useState, useRef, useEffect } from 'react';
import { cn } from '@/lib/utils';

export interface FilterState {
  period?: 'this_month' | 'last_month' | 'year' | 'all' | 'custom';
  startDate?: number;
  endDate?: number;
  categoryId?: string;
  type?: 'expense' | 'income' | 'transfer';
  source?: 'manual' | 'recurring' | 'incomeSchedule' | 'capture';
  minAmount?: number;
  maxAmount?: number;
}

export interface MovementFiltersBarProps {
  search: string;
  onSearchChange: (search: string) => void;
  filters: FilterState;
  onFiltersChange: (filters: FilterState) => void;
  onClearFilters?: () => void;
  categories: Array<{ id: string; name: string }>;
  onExportCsv: () => void;
  onExportXlsx: () => void;
}

export function MovementFiltersBar({
  search,
  onSearchChange,
  filters,
  onFiltersChange,
  onClearFilters,
  categories,
  onExportCsv,
  onExportXlsx,
}: MovementFiltersBarProps) {
  const [downloadOpen, setDownloadOpen] = useState(false);
  const [categoryOpen, setCategoryOpen] = useState(false);
  const [typeOpen, setTypeOpen] = useState(false);
  const [periodOpen, setPeriodOpen] = useState(false);
  const [originOpen, setOriginOpen] = useState(false);

  const downloadRef = useRef<HTMLDivElement>(null);
  const categoryRef = useRef<HTMLDivElement>(null);
  const typeRef = useRef<HTMLDivElement>(null);
  const periodRef = useRef<HTMLDivElement>(null);
  const originRef = useRef<HTMLDivElement>(null);

  // Close menus when clicking outside
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (downloadRef.current && !downloadRef.current.contains(e.target as Node)) {
        setDownloadOpen(false);
      }
      if (categoryRef.current && !categoryRef.current.contains(e.target as Node)) {
        setCategoryOpen(false);
      }
      if (typeRef.current && !typeRef.current.contains(e.target as Node)) {
        setTypeOpen(false);
      }
      if (periodRef.current && !periodRef.current.contains(e.target as Node)) {
        setPeriodOpen(false);
      }
      if (originRef.current && !originRef.current.contains(e.target as Node)) {
        setOriginOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const hasActiveFilters =
    Boolean(search) ||
    Boolean(filters.categoryId) ||
    Boolean(filters.type) ||
    Boolean(filters.source) ||
    Boolean(filters.minAmount) ||
    Boolean(filters.maxAmount) ||
    (filters.period && filters.period !== 'this_month');

  const selectedCategoryName = categories.find((c) => c.id === filters.categoryId)?.name;

  return (
    <div className="flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between">
      {/* Search Input & Chips */}
      <div className="flex flex-wrap items-center gap-2 flex-1">
        {/* Search */}
        <div className="relative min-w-[200px] sm:min-w-[260px] flex-1 sm:flex-initial">
          <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-text-tertiary pointer-events-none">
            <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <circle cx="11" cy="11" r="7" />
              <path d="M16.5 16.5L21 21" />
            </svg>
          </span>
          <input
            type="text"
            value={search}
            onChange={(e) => onSearchChange(e.target.value)}
            placeholder="Buscar comercio o nota"
            className="w-full pl-10 pr-3.5 py-1.5 rounded-full text-[13px] bg-white/5 border border-glass-border focus:border-brand-start focus:ring-2 focus:ring-brand-start/20 outline-none text-text-primary placeholder:text-text-tertiary transition-all"
          />
        </div>

        {/* Period Chip */}
        <div className="relative" ref={periodRef}>
          <button
            type="button"
            onClick={() => setPeriodOpen(!periodOpen)}
            className={cn(
              'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[12.5px] font-semibold border transition-all cursor-pointer',
              filters.period && filters.period !== 'this_month'
                ? 'bg-brand-start/15 border-brand-start/40 text-brand-start'
                : 'bg-white/5 border-glass-border text-text-secondary hover:text-text-primary hover:bg-white/10'
            )}
          >
            <svg className="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="3" y="4" width="18" height="18" rx="2" />
              <line x1="16" y1="2" x2="16" y2="6" />
              <line x1="8" y1="2" x2="8" y2="6" />
              <line x1="3" y1="10" x2="21" y2="10" />
            </svg>
            <span>
              {filters.period === 'last_month'
                ? 'Mes pasado'
                : filters.period === 'year'
                ? 'Este año'
                : filters.period === 'all'
                ? 'Histórico'
                : filters.period === 'custom'
                ? 'Personalizado'
                : 'Este mes'}
            </span>
          </button>

          {periodOpen && (
            <div className="absolute left-0 top-10 w-44 rounded-2xl bg-sheet-surface border border-glass-border p-1.5 shadow-xl z-30 space-y-0.5">
              {[
                { id: 'this_month', label: 'Este mes' },
                { id: 'last_month', label: 'Mes pasado' },
                { id: 'year', label: 'Este año' },
                { id: 'all', label: 'Todo el historial' },
              ].map((p) => (
                <button
                  key={p.id}
                  type="button"
                  onClick={() => {
                    onFiltersChange({ ...filters, period: p.id as any });
                    setPeriodOpen(false);
                  }}
                  className={cn(
                    'w-full text-left px-2.5 py-1.5 rounded-xl text-[12.5px] font-medium transition-colors',
                    (filters.period || 'this_month') === p.id
                      ? 'bg-brand-start/15 text-brand-start font-semibold'
                      : 'text-text-secondary hover:text-text-primary hover:bg-white/5'
                  )}
                >
                  {p.label}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Category Chip */}
        <div className="relative" ref={categoryRef}>
          <button
            type="button"
            onClick={() => setCategoryOpen(!categoryOpen)}
            className={cn(
              'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[12.5px] font-semibold border transition-all cursor-pointer',
              filters.categoryId
                ? 'bg-brand-start/15 border-brand-start/40 text-brand-start'
                : 'bg-white/5 border-glass-border text-text-secondary hover:text-text-primary hover:bg-white/10'
            )}
          >
            <span>{selectedCategoryName || 'Categoría'}</span>
            <svg className="w-3 h-3 opacity-60" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M6 9l6 6 6-6" />
            </svg>
          </button>

          {categoryOpen && (
            <div className="absolute left-0 top-10 w-48 max-h-60 overflow-y-auto rounded-2xl bg-sheet-surface border border-glass-border p-1.5 shadow-xl z-30 space-y-0.5">
              <button
                type="button"
                onClick={() => {
                  onFiltersChange({ ...filters, categoryId: undefined });
                  setCategoryOpen(false);
                }}
                className={cn(
                  'w-full text-left px-2.5 py-1.5 rounded-xl text-[12.5px] font-medium transition-colors',
                  !filters.categoryId
                    ? 'bg-brand-start/15 text-brand-start font-semibold'
                    : 'text-text-secondary hover:text-text-primary hover:bg-white/5'
                )}
              >
                Todas
              </button>
              {categories.map((cat) => (
                <button
                  key={cat.id}
                  type="button"
                  onClick={() => {
                    onFiltersChange({ ...filters, categoryId: cat.id });
                    setCategoryOpen(false);
                  }}
                  className={cn(
                    'w-full text-left px-2.5 py-1.5 rounded-xl text-[12.5px] font-medium transition-colors truncate',
                    filters.categoryId === cat.id
                      ? 'bg-brand-start/15 text-brand-start font-semibold'
                      : 'text-text-secondary hover:text-text-primary hover:bg-white/5'
                  )}
                >
                  {cat.name}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Type Chip */}
        <div className="relative" ref={typeRef}>
          <button
            type="button"
            onClick={() => setTypeOpen(!typeOpen)}
            className={cn(
              'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[12.5px] font-semibold border transition-all cursor-pointer',
              filters.type
                ? 'bg-brand-start/15 border-brand-start/40 text-brand-start'
                : 'bg-white/5 border-glass-border text-text-secondary hover:text-text-primary hover:bg-white/10'
            )}
          >
            <span>
              {filters.type === 'expense'
                ? 'Gasto'
                : filters.type === 'income'
                ? 'Ingreso'
                : filters.type === 'transfer'
                ? 'Transferencia'
                : 'Tipo'}
            </span>
            <svg className="w-3 h-3 opacity-60" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M6 9l6 6 6-6" />
            </svg>
          </button>

          {typeOpen && (
            <div className="absolute left-0 top-10 w-36 rounded-2xl bg-sheet-surface border border-glass-border p-1.5 shadow-xl z-30 space-y-0.5">
              {[
                { id: undefined, label: 'Todos' },
                { id: 'expense', label: 'Gastos' },
                { id: 'income', label: 'Ingresos' },
                { id: 'transfer', label: 'Transferencias' },
              ].map((t) => (
                <button
                  key={t.label}
                  type="button"
                  onClick={() => {
                    onFiltersChange({ ...filters, type: t.id as any });
                    setTypeOpen(false);
                  }}
                  className={cn(
                    'w-full text-left px-2.5 py-1.5 rounded-xl text-[12.5px] font-medium transition-colors',
                    filters.type === t.id
                      ? 'bg-brand-start/15 text-brand-start font-semibold'
                      : 'text-text-secondary hover:text-text-primary hover:bg-white/5'
                  )}
                >
                  {t.label}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Origin Chip */}
        <div className="relative" ref={originRef}>
          <button
            type="button"
            onClick={() => setOriginOpen(!originOpen)}
            className={cn(
              'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[12.5px] font-semibold border transition-all cursor-pointer',
              filters.source
                ? 'bg-brand-start/15 border-brand-start/40 text-brand-start'
                : 'bg-white/5 border-glass-border text-text-secondary hover:text-text-primary hover:bg-white/10'
            )}
          >
            <span>
              {filters.source === 'manual'
                ? 'Manual'
                : filters.source === 'recurring'
                ? 'Recurrente'
                : filters.source === 'incomeSchedule'
                ? 'Sueldo'
                : filters.source === 'capture'
                ? 'Captura'
                : 'Origen'}
            </span>
            <svg className="w-3 h-3 opacity-60" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M6 9l6 6 6-6" />
            </svg>
          </button>

          {originOpen && (
            <div className="absolute left-0 top-10 w-36 rounded-2xl bg-sheet-surface border border-glass-border p-1.5 shadow-xl z-30 space-y-0.5">
              {[
                { id: undefined, label: 'Todos' },
                { id: 'manual', label: 'Manual' },
                { id: 'recurring', label: 'Recurrente' },
                { id: 'incomeSchedule', label: 'Sueldo' },
                { id: 'capture', label: 'Captura' },
              ].map((o) => (
                <button
                  key={o.label}
                  type="button"
                  onClick={() => {
                    onFiltersChange({ ...filters, source: o.id as any });
                    setOriginOpen(false);
                  }}
                  className={cn(
                    'w-full text-left px-2.5 py-1.5 rounded-xl text-[12.5px] font-medium transition-colors',
                    filters.source === o.id
                      ? 'bg-brand-start/15 text-brand-start font-semibold'
                      : 'text-text-secondary hover:text-text-primary hover:bg-white/5'
                  )}
                >
                  {o.label}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Clear filters button */}
        {hasActiveFilters && onClearFilters && (
          <button
            type="button"
            onClick={onClearFilters}
            className="px-2.5 py-1 rounded-full text-[12px] font-semibold text-danger hover:bg-danger/10 active:scale-95 transition-all cursor-pointer"
          >
            Limpiar
          </button>
        )}
      </div>

      {/* Download Export Dropdown Button */}
      <div className="relative" ref={downloadRef}>
        <button
          type="button"
          onClick={() => setDownloadOpen(!downloadOpen)}
          className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-[12.5px] font-semibold bg-white/5 border border-glass-border text-text-secondary hover:text-text-primary hover:bg-white/10 active:scale-95 transition-all cursor-pointer"
        >
          <svg className="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M12 4v12M7 11l5 5 5-5M5 20h14" />
          </svg>
          <span>Descargar</span>
        </button>

        {downloadOpen && (
          <div className="absolute right-0 top-10 w-48 rounded-2xl bg-sheet-surface border border-glass-border p-1.5 shadow-xl z-30 space-y-0.5">
            <button
              type="button"
              onClick={() => {
                onExportCsv();
                setDownloadOpen(false);
              }}
              className="w-full text-left px-3 py-2 rounded-xl text-[13px] font-medium text-text-primary hover:bg-white/5 flex items-center gap-2 cursor-pointer transition-colors"
            >
              <svg className="w-4 h-4 text-brand-start" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                <polyline points="14 2 14 8 20 8" />
              </svg>
              <span>Descargar CSV</span>
            </button>
            <button
              type="button"
              onClick={() => {
                onExportXlsx();
                setDownloadOpen(false);
              }}
              className="w-full text-left px-3 py-2 rounded-xl text-[13px] font-medium text-text-primary hover:bg-white/5 flex items-center gap-2 cursor-pointer transition-colors"
            >
              <svg className="w-4 h-4 text-positive" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <rect x="3" y="3" width="18" height="18" rx="2" />
                <line x1="9" y1="3" x2="9" y2="21" />
                <line x1="15" y1="3" x2="15" y2="21" />
                <line x1="3" y1="9" x2="21" y2="9" />
                <line x1="3" y1="15" x2="21" y2="15" />
              </svg>
              <span>Descargar Excel</span>
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
