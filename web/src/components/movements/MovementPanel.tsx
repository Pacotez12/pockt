import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { DBExecutable, createMovement, updateMovement, softDeleteMovement } from '@/lib/movements/write';
import { useReducedMotion } from 'motion/react';
import { cn } from '@/lib/utils';
import { useTheme } from '@/lib/theme';

export interface CategoryOption {
  id: string;
  name: string;
  kind: string;
  sort_order: number;
  color_dark?: number | null;
  color_light?: number | null;
  icon?: string | null;
}

export interface MovementData {
  id: string;
  type: string;
  amount: number;
  category_id?: string | null;
  merchant?: string | null;
  note?: string | null;
  occurred_at: number;
  loan_id?: string | null;
}

export interface MovementPanelProps {
  isOpen: boolean;
  movement?: MovementData | null;
  db: DBExecutable;
  categories: CategoryOption[];
  onClose: () => void;
  onSaved?: (id: string) => void;
  onDeleted?: (id: string) => void;
}

function parseHexColor(colorInt: number | null | undefined): string {
  if (colorInt == null) return '#9CA3AF';
  const rgb = colorInt & 0x00ffffff;
  return `#${rgb.toString(16).padStart(6, '0')}`;
}

function formatThousands(val: number | string): string {
  const num = typeof val === 'number' ? val : parseInt(String(val).replace(/\D/g, ''), 10);
  if (isNaN(num)) return '';
  return num.toLocaleString('es-PY');
}

function toLocalDatetimeInput(secondsOrMs: number): string {
  const ms = secondsOrMs > 1e11 ? secondsOrMs : secondsOrMs * 1000;
  const d = new Date(ms);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function MovementPanel({
  isOpen,
  movement,
  db,
  categories,
  onClose,
  onSaved,
  onDeleted,
}: MovementPanelProps) {
  const prefersReducedMotion = useReducedMotion();
  const { resolvedTheme } = useTheme();

  const isEditing = !!movement;
  const isLoan = !!movement?.loan_id;

  const [type, setType] = useState<'expense' | 'income' | 'transfer'>('expense');
  const [amountStr, setAmountStr] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [merchant, setMerchant] = useState('');
  const [note, setNote] = useState('');
  const [occurredAtStr, setOccurredAtStr] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [isDirty, setIsDirty] = useState(false);

  // Filter categories by type
  const availableCategories = categories
    .filter((cat) => {
      if (type === 'transfer') return true;
      return cat.kind === type;
    })
    .sort((a, b) => a.sort_order - b.sort_order);

  // Initialize or reset form state
  useEffect(() => {
    if (!isOpen) {
      setConfirmDelete(false);
      setErrorMsg(null);
      setIsDirty(false);
      return;
    }

    if (movement) {
      setType((movement.type as any) || 'expense');
      setAmountStr(formatThousands(movement.amount));
      setCategoryId(movement.category_id || '');
      setMerchant(movement.merchant || '');
      setNote(movement.note || '');
      setOccurredAtStr(toLocalDatetimeInput(movement.occurred_at));
    } else {
      setType('expense');
      setAmountStr('');
      setMerchant('');
      setNote('');
      setOccurredAtStr(toLocalDatetimeInput(Date.now()));
      // Default to first expense category if available
      const firstExp = categories.find((c) => c.kind === 'expense');
      setCategoryId(firstExp ? firstExp.id : categories[0]?.id || '');
    }
    setConfirmDelete(false);
    setErrorMsg(null);
    setIsDirty(false);
  }, [isOpen, movement, categories]);

  // Keep category in sync with type changes if previous category isn't compatible
  const handleTypeChange = (newType: 'expense' | 'income' | 'transfer') => {
    setType(newType);
    setIsDirty(true);
    const validCats = categories.filter((c) => (newType === 'transfer' ? true : c.kind === newType));
    if (!validCats.some((c) => c.id === categoryId)) {
      setCategoryId(validCats[0]?.id || '');
    }
  };

  const handleAmountChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const raw = e.target.value.replace(/\D/g, '');
    setIsDirty(true);
    if (!raw) {
      setAmountStr('');
      return;
    }
    const num = parseInt(raw, 10);
    setAmountStr(num.toLocaleString('es-PY'));
    if (errorMsg) setErrorMsg(null);
  };

  const handleClose = () => {
    if (isDirty) {
      const confirmDiscard = window.confirm('Hay cambios sin guardar. ¿Descartar?');
      if (!confirmDiscard) return;
    }
    onClose();
  };

  // Keyboard Escape listener
  useEffect(() => {
    if (!isOpen) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        handleClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, isDirty]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (isLoan) return;

    const rawAmount = parseInt(amountStr.replace(/\D/g, ''), 10);
    if (isNaN(rawAmount) || rawAmount <= 0) {
      setErrorMsg('Ingresá un monto válido en guaraníes.');
      return;
    }

    if (!categoryId) {
      setErrorMsg('Seleccioná una categoría.');
      return;
    }

    setIsSubmitting(true);
    setErrorMsg(null);

    try {
      const occurredDate = occurredAtStr ? new Date(occurredAtStr) : new Date();

      if (isEditing && movement) {
        await updateMovement(db, movement.id, {
          type,
          amount: rawAmount,
          categoryId,
          occurredAt: occurredDate,
          merchant,
          note,
        });
        onSaved?.(movement.id);
      } else {
        const newId = await createMovement(db, {
          type,
          amount: rawAmount,
          categoryId,
          occurredAt: occurredDate,
          merchant,
          note,
        });
        onSaved?.(newId);
      }
      onClose();
    } catch (err: any) {
      setErrorMsg(err.message || 'Error al guardar el movimiento');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async () => {
    if (!movement || isLoan) return;
    setIsSubmitting(true);
    try {
      await softDeleteMovement(db, movement.id);
      onDeleted?.(movement.id);
      onClose();
    } catch (err: any) {
      setErrorMsg(err.message || 'Error al borrar');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Backdrop on mobile */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={handleClose}
            className="fixed inset-0 bg-black/40 backdrop-blur-xs z-40 sm:hidden"
            aria-hidden="true"
          />

          <motion.aside
            role="dialog"
            aria-modal="true"
            aria-labelledby="panel-title"
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
              'w-[calc(100vw-24px)] sm:w-[420px]',
              'rounded-3xl p-6 flex flex-col',
              'bg-[#141416]/95 dark:bg-[#141416]/95 backdrop-blur-xl',
              'border border-glass-border shadow-2xl overflow-y-auto'
            )}
          >
            {/* Header */}
            <div className="flex items-center justify-between pb-3 border-b border-white/5">
              <h2 id="panel-title" className="text-[17px] font-bold text-text-primary tracking-tight">
                {isEditing ? 'Editar movimiento' : 'Cargar movimiento'}
              </h2>
              <button
                type="button"
                onClick={handleClose}
                aria-label="Cerrar panel"
                className="w-8 h-8 rounded-full grid place-items-center bg-glass-fill border border-glass-border text-text-tertiary hover:text-text-primary active:scale-95 transition-all cursor-pointer"
              >
                <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                  <path d="M18 6L6 18M6 6l12 12" />
                </svg>
              </button>
            </div>

            {/* Notice if tied to a loan */}
            {isLoan && (
              <div className="mt-4 p-3 rounded-2xl bg-amber-500/10 border border-amber-500/30 text-amber-300 text-[13px] flex items-start gap-2.5">
                <svg className="w-4 h-4 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                  <circle cx="12" cy="12" r="10" />
                  <line x1="12" y1="8" x2="12" y2="12" />
                  <line x1="12" y1="16" x2="12.01" y2="16" />
                </svg>
                <div>
                  <div className="font-semibold">Movimiento de préstamo</div>
                  <div className="text-[12px] opacity-90 mt-0.5">
                    Editalo desde la app, afecta al préstamo. En la web se muestra en modo solo lectura.
                  </div>
                </div>
              </div>
            )}

            {/* Form */}
            <form onSubmit={handleSubmit} className="flex-1 flex flex-col justify-between mt-4 space-y-4">
              <div className="space-y-4">
                {/* Type Segmented Control */}
                <div>
                  <label className="block text-[12px] font-semibold text-text-secondary mb-1.5">
                    Tipo
                  </label>
                  <div className="flex bg-white/5 p-1 rounded-xl border border-glass-border">
                    <button
                      type="button"
                      disabled={isLoan}
                      onClick={() => handleTypeChange('expense')}
                      className={cn(
                        'flex-1 py-1.5 rounded-lg text-[13px] font-semibold transition-all',
                        type === 'expense'
                          ? 'bg-white/15 text-white shadow-sm'
                          : 'text-text-tertiary hover:text-text-secondary'
                      )}
                    >
                      Gasto
                    </button>
                    <button
                      type="button"
                      disabled={isLoan}
                      onClick={() => handleTypeChange('income')}
                      className={cn(
                        'flex-1 py-1.5 rounded-lg text-[13px] font-semibold transition-all',
                        type === 'income'
                          ? 'bg-positive/20 text-positive shadow-sm'
                          : 'text-text-tertiary hover:text-text-secondary'
                      )}
                    >
                      Ingreso
                    </button>
                    <button
                      type="button"
                      disabled={isLoan}
                      onClick={() => handleTypeChange('transfer')}
                      className={cn(
                        'flex-1 py-1.5 rounded-lg text-[13px] font-semibold transition-all',
                        type === 'transfer'
                          ? 'bg-brand-start/20 text-brand-start shadow-sm'
                          : 'text-text-tertiary hover:text-text-secondary'
                      )}
                    >
                      Transferencia
                    </button>
                  </div>
                </div>

                {/* Amount Field */}
                <div>
                  <label htmlFor="tx-amount" className="block text-[12.5px] font-semibold text-text-secondary mb-1">
                    Monto
                  </label>
                  <div className="relative">
                    <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-text-tertiary font-bold text-[14px]">
                      Gs.
                    </span>
                    <input
                      id="tx-amount"
                      type="text"
                      inputMode="numeric"
                      disabled={isLoan}
                      value={amountStr}
                      onChange={handleAmountChange}
                      placeholder="0"
                      className={cn(
                        'w-full pl-11 pr-4 py-2.5 rounded-xl text-[15px] font-bold tabular-nums',
                        'bg-white/5 border border-glass-border focus:border-brand-start focus:ring-2 focus:ring-brand-start/20 outline-none transition-all',
                        isLoan && 'opacity-60 cursor-not-allowed'
                      )}
                    />
                  </div>
                  <p className="text-[11.5px] text-text-tertiary mt-1">
                    Sin decimales, ej. 45.000
                  </p>
                </div>

                {/* Category Field */}
                <div>
                  <label htmlFor="tx-category" className="block text-[12.5px] font-semibold text-text-secondary mb-1">
                    Categoría
                  </label>
                  <div className="relative">
                    <select
                      id="tx-category"
                      disabled={isLoan}
                      value={categoryId}
                      onChange={(e) => {
                        setCategoryId(e.target.value);
                        setIsDirty(true);
                      }}
                      className={cn(
                        'w-full px-3.5 py-2.5 rounded-xl text-[13.5px] bg-[#1a1a1e] border border-glass-border',
                        'focus:border-brand-start focus:ring-2 focus:ring-brand-start/20 outline-none transition-all appearance-none text-text-primary',
                        isLoan && 'opacity-60 cursor-not-allowed'
                      )}
                    >
                      {availableCategories.map((cat) => (
                        <option key={cat.id} value={cat.id} className="bg-[#1a1a1e] text-white">
                          {cat.name}
                        </option>
                      ))}
                    </select>
                    <div className="pointer-events-none absolute right-3.5 top-1/2 -translate-y-1/2 text-text-tertiary">
                      <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M6 9l6 6 6-6" />
                      </svg>
                    </div>
                  </div>
                </div>

                {/* Date & Time Field */}
                <div>
                  <label htmlFor="tx-date" className="block text-[12.5px] font-semibold text-text-secondary mb-1">
                    Fecha y hora
                  </label>
                  <input
                    id="tx-date"
                    type="datetime-local"
                    disabled={isLoan}
                    value={occurredAtStr}
                    onChange={(e) => {
                      setOccurredAtStr(e.target.value);
                      setIsDirty(true);
                    }}
                    className={cn(
                      'w-full px-3.5 py-2.5 rounded-xl text-[13.5px] bg-white/5 border border-glass-border',
                      'focus:border-brand-start focus:ring-2 focus:ring-brand-start/20 outline-none transition-all text-text-primary',
                      isLoan && 'opacity-60 cursor-not-allowed'
                    )}
                  />
                  <p className="text-[11.5px] text-text-tertiary mt-1">
                    Por defecto, ahora
                  </p>
                </div>

                {/* Merchant (Comercio) Field */}
                <div>
                  <label htmlFor="tx-merchant" className="block text-[12.5px] font-semibold text-text-secondary mb-1">
                    Comercio <span className="text-text-tertiary font-normal">(opcional)</span>
                  </label>
                  <input
                    id="tx-merchant"
                    type="text"
                    disabled={isLoan}
                    value={merchant}
                    onChange={(e) => {
                      setMerchant(e.target.value);
                      setIsDirty(true);
                    }}
                    placeholder="Ej. Superseis, Bolt, Netflix"
                    className={cn(
                      'w-full px-3.5 py-2.5 rounded-xl text-[13.5px] bg-white/5 border border-glass-border',
                      'focus:border-brand-start focus:ring-2 focus:ring-brand-start/20 outline-none transition-all text-text-primary',
                      isLoan && 'opacity-60 cursor-not-allowed'
                    )}
                  />
                </div>

                {/* Note Field */}
                <div>
                  <label htmlFor="tx-note" className="block text-[12.5px] font-semibold text-text-secondary mb-1">
                    Nota <span className="text-text-tertiary font-normal">(opcional)</span>
                  </label>
                  <input
                    id="tx-note"
                    type="text"
                    disabled={isLoan}
                    value={note}
                    onChange={(e) => {
                      setNote(e.target.value);
                      setIsDirty(true);
                    }}
                    placeholder="Ej. Compra para el asado"
                    className={cn(
                      'w-full px-3.5 py-2.5 rounded-xl text-[13.5px] bg-white/5 border border-glass-border',
                      'focus:border-brand-start focus:ring-2 focus:ring-brand-start/20 outline-none transition-all text-text-primary',
                      isLoan && 'opacity-60 cursor-not-allowed'
                    )}
                  />
                </div>

                {/* Error Banner */}
                {errorMsg && (
                  <div className="p-3 rounded-xl bg-danger/10 border border-danger/30 text-danger text-[12.5px] flex items-center gap-2">
                    <svg className="w-4 h-4 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <circle cx="12" cy="12" r="10" />
                      <line x1="12" y1="8" x2="12" y2="12" />
                      <line x1="12" y1="16" x2="12.01" y2="16" />
                    </svg>
                    <span>{errorMsg}</span>
                  </div>
                )}
              </div>

              {/* Bottom Actions */}
              {!isLoan && (
                <div className="pt-4 border-t border-white/5">
                  {confirmDelete ? (
                    <div className="p-3 rounded-2xl bg-danger/10 border border-danger/30 space-y-2">
                      <div className="text-[12.5px] text-danger font-medium">
                        ¿Borrar este movimiento? Se borra también del teléfono.
                      </div>
                      <div className="flex gap-2">
                        <button
                          type="button"
                          onClick={handleDelete}
                          disabled={isSubmitting}
                          className="flex-1 py-1.5 rounded-xl bg-danger text-white text-[12.5px] font-bold hover:bg-danger/90 active:scale-95 transition-all cursor-pointer"
                        >
                          Confirmar borrar
                        </button>
                        <button
                          type="button"
                          onClick={() => setConfirmDelete(false)}
                          className="px-3 py-1.5 rounded-xl bg-white/10 text-text-secondary text-[12.5px] font-semibold hover:bg-white/15 transition-all cursor-pointer"
                        >
                          No, cancelar
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div className="flex items-center gap-2.5">
                      {isEditing && (
                        <button
                          type="button"
                          onClick={() => setConfirmDelete(true)}
                          className="px-3.5 py-2.5 rounded-xl border border-danger/30 text-danger text-[13px] font-semibold hover:bg-danger/10 active:scale-95 transition-all cursor-pointer"
                        >
                          Borrar
                        </button>
                      )}
                      <div className="flex-1" />
                      <button
                        type="button"
                        onClick={handleClose}
                        className="px-4 py-2.5 rounded-xl border border-glass-border text-text-secondary text-[13px] font-semibold hover:bg-white/5 active:scale-95 transition-all cursor-pointer"
                      >
                        Cancelar
                      </button>
                      <button
                        type="submit"
                        disabled={isSubmitting}
                        className={cn(
                          'flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl font-bold text-[13px] text-white shadow-sm active:scale-95 transition-transform cursor-pointer',
                          isSubmitting && 'opacity-70 cursor-wait'
                        )}
                        style={{
                          background: 'linear-gradient(90deg, var(--brand-start), var(--brand-end))',
                        }}
                      >
                        {isSubmitting ? (
                          <>
                            <span className="w-3.5 h-3.5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                            <span>Guardando…</span>
                          </>
                        ) : (
                          <span>Guardar</span>
                        )}
                      </button>
                    </div>
                  )}
                </div>
              )}
            </form>
          </motion.aside>
        </>
      )}
    </AnimatePresence>
  );
}
