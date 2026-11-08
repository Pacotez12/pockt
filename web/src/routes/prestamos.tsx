import React, { useEffect, useState, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { motion, useReducedMotion } from 'motion/react';
import { useQuery } from '@powersync/react';
import { ChevronDown, ChevronRight, ArrowUpRight, ArrowDownLeft, Info } from 'lucide-react';
import { CountUp } from '@/components/CountUp';
import { Skeleton } from '@/components/Skeleton';
import { formatGs, formatThousands } from '@/lib/format';
import {
  calculateLoanProgress,
  effectiveSchedule,
  LoanInput,
  LoanInstallmentInput,
  LoanPaymentInput,
  LoanProgressResult,
} from '@/lib/calc/loan_progress';

interface LoanDbRow {
  id: string;
  direction: 'owe' | 'lent';
  kind: string;
  name: string;
  counterparty?: string | null;
  total_amount: number;
  installment_amount?: number | null;
  installments_total?: number | null;
  due_day?: number | null;
  start_date: number;
  closed_at?: number | null;
  reminder_days?: number | null;
  paid_before_count?: number | null;
}

interface InstallmentDbRow {
  id: string;
  loan_id: string;
  number: number;
  due_date: number;
  amount: number;
}

interface TxDbRow {
  id: string;
  loan_id?: string | null;
  type: string;
  amount: number;
  occurred_at: number;
  is_extra?: number | null;
  deleted_at?: number | null;
}

interface LoanCardItem {
  loan: LoanDbRow;
  progress: LoanProgressResult;
  nextAmount: number | null;
  totalCount: number | null;
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

function formatDateShort(dateStr: string | null): string {
  if (!dateStr) return '';
  const [y, m, d] = dateStr.split('T')[0].split('-');
  return `${d}/${m}`;
}

export function PrestamosRoute() {
  const prefersReduced = useReducedMotion();
  const [showClosed, setShowClosed] = useState(false);

  useEffect(() => {
    document.title = 'Préstamos · Pockt';
  }, []);

  const { data: loans, isLoading: loadingLoans } = useQuery<LoanDbRow>(
    'SELECT * FROM loans ORDER BY due_day ASC, start_date ASC'
  );

  const { data: installments, isLoading: loadingInstallments } = useQuery<InstallmentDbRow>(
    'SELECT * FROM loan_installments ORDER BY number ASC'
  );

  const { data: payments, isLoading: loadingPayments } = useQuery<TxDbRow>(
    'SELECT id, loan_id, type, amount, occurred_at, is_extra, deleted_at FROM transactions WHERE loan_id IS NOT NULL AND deleted_at IS NULL'
  );

  const isLoading = loadingLoans || loadingInstallments || loadingPayments;

  const { activeOwe, activeLent, closedLoans, totalOwe, totalLent } = useMemo(() => {
    if (!loans) {
      return { activeOwe: [], activeLent: [], closedLoans: [], totalOwe: 0, totalLent: 0 };
    }

    const instMap = new Map<string, InstallmentDbRow[]>();
    for (const inst of installments ?? []) {
      const list = instMap.get(inst.loan_id) ?? [];
      list.push(inst);
      instMap.set(inst.loan_id, list);
    }

    const payMap = new Map<string, TxDbRow[]>();
    for (const pay of payments ?? []) {
      if (!pay.loan_id) continue;
      const list = payMap.get(pay.loan_id) ?? [];
      list.push(pay);
      payMap.set(pay.loan_id, list);
    }

    const now = new Date();
    const activeOweList: LoanCardItem[] = [];
    const activeLentList: LoanCardItem[] = [];
    const closedList: LoanCardItem[] = [];

    let oweSum = 0;
    let lentSum = 0;

    for (const loan of loans) {
      const loanInsts = instMap.get(loan.id) ?? [];
      const loanPays = payMap.get(loan.id) ?? [];

      const scheduleInputs: LoanInstallmentInput[] = loanInsts.map((i) => ({
        id: i.id,
        loanId: i.loan_id,
        number: i.number,
        dueDate: toYMD(i.due_date),
        amount: i.amount,
      }));

      const paymentInputs: LoanPaymentInput[] = loanPays.map((p) => ({
        id: p.id,
        type: p.type,
        amount: p.amount,
        occurredAt: toYMD(p.occurred_at),
        isExtra: p.is_extra === 1,
        deletedAt: p.deleted_at ? toYMD(p.deleted_at) : null,
      }));

      const loanInput: LoanInput = {
        id: loan.id,
        name: loan.name,
        kind: loan.kind,
        direction: loan.direction,
        totalAmount: loan.total_amount,
        installmentAmount: loan.installment_amount,
        installmentsTotal: loan.installments_total,
        dueDay: loan.due_day,
        startDate: toYMD(loan.start_date),
        paidBeforeCount: loan.paid_before_count ?? 0,
        closedAt: loan.closed_at ? toYMD(loan.closed_at) : null,
      };

      const progress = calculateLoanProgress({
        loan: loanInput,
        schedule: scheduleInputs,
        payments: paymentInputs,
        now,
      });

      const eff = effectiveSchedule(loanInput, scheduleInputs);
      let nextAmount: number | null = null;
      if (eff && eff.length > progress.installmentsPaid) {
        nextAmount = eff[progress.installmentsPaid].amount;
      } else {
        // Igual que la app: cuota del cronograma, si no la cuota fija, si no el saldo.
        nextAmount = loan.installment_amount ?? progress.balance;
      }

      const totalCount = eff ? eff.length : (loan.installments_total ?? null);
      const isClosed = Boolean(loan.closed_at) || progress.isClosed;

      const item: LoanCardItem = {
        loan,
        progress,
        nextAmount,
        totalCount,
      };

      if (isClosed) {
        closedList.push(item);
      } else {
        if (loan.direction === 'owe') {
          activeOweList.push(item);
          oweSum += progress.balance;
        } else {
          activeLentList.push(item);
          lentSum += progress.balance;
        }
      }
    }

    return {
      activeOwe: activeOweList,
      activeLent: activeLentList,
      closedLoans: closedList,
      totalOwe: oweSum,
      totalLent: lentSum,
    };
  }, [loans, installments, payments]);

  if (isLoading) {
    return (
      <div data-testid="prestamos-skeleton" className="space-y-6">
        <div className="flex items-center justify-between">
          <Skeleton className="w-48 h-8 rounded-xl" />
          <Skeleton className="w-36 h-6 rounded-full" />
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Skeleton className="h-28 rounded-2xl" />
          <Skeleton className="h-28 rounded-2xl" />
        </div>
        <div className="space-y-4">
          <Skeleton className="h-36 rounded-2xl" />
          <Skeleton className="h-36 rounded-2xl" />
        </div>
      </div>
    );
  }

  const renderLoanCard = ({ loan, progress, nextAmount, totalCount }: LoanCardItem) => {
    const isOwe = loan.direction === 'owe';
    const percentInt = Math.round(progress.percent * 100);

    return (
      <Link
        key={loan.id}
        to={`/prestamos/${loan.id}`}
        className="block group"
      >
        <div className="p-5 rounded-2xl bg-glass-fill border border-glass-border hover:border-brand-start/40 transition-all duration-200 shadow-sm relative overflow-hidden">
          <div className="flex items-start justify-between gap-4">
            <div>
              <div className="flex items-center gap-2">
                <span
                  className="w-6 h-6 rounded-lg grid place-items-center text-xs"
                  style={{
                    backgroundColor: isOwe ? 'rgba(244, 81, 79, 0.12)' : 'rgba(74, 212, 150, 0.12)',
                    color: isOwe ? 'var(--danger)' : 'var(--positive)',
                  }}
                >
                  {isOwe ? <ArrowUpRight className="w-3.5 h-3.5" /> : <ArrowDownLeft className="w-3.5 h-3.5" />}
                </span>
                <h3 className="font-bold text-base text-text-primary group-hover:text-brand-start transition-colors">
                  {loan.name}
                </h3>
              </div>
              {loan.counterparty && (
                <div className="text-xs text-text-tertiary mt-1 ml-8">
                  {isOwe ? `Acreedor: ${loan.counterparty}` : `Deudor: ${loan.counterparty}`}
                </div>
              )}
            </div>

            <ChevronRight className="w-5 h-5 text-text-tertiary group-hover:text-text-primary group-hover:translate-x-0.5 transition-all" />
          </div>

          {/* Saldo pendiente */}
          <div className="mt-4">
            <div className="text-xs text-text-tertiary">Saldo pendiente</div>
            <div className="text-2xl font-extrabold tracking-tight text-text-primary tabular-nums mt-0.5 whitespace-nowrap">
              <CountUp value={progress.balance} formatter={formatGs} />
            </div>
          </div>

          {/* Barra de avance con resorte */}
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

          {/* Detalles de cuotas y próxima fecha */}
          <div className="flex items-center justify-between text-xs text-text-secondary mt-3">
            <span>
              {totalCount != null
                ? `${progress.installmentsPaid} de ${totalCount} cuotas · ${percentInt}%`
                : `${progress.installmentsPaid} pagadas · ${percentInt}%`}
            </span>
            {nextAmount != null && progress.nextDueDate && (
              <span className="font-medium text-text-primary whitespace-nowrap shrink-0">
                Próxima: Gs. {formatThousands(nextAmount)} · vence {formatDateShort(progress.nextDueDate)}
              </span>
            )}
          </div>
        </div>
      </Link>
    );
  };

  return (
    <div className="space-y-8 select-none">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-text-primary">
            Préstamos
          </h1>
          <p className="text-xs text-text-tertiary mt-1">
            Seguimiento de deudas y préstamos con cronograma y cuotas
          </p>
        </div>

        {/* Aviso discreto */}
        <span className="inline-flex items-center gap-1.5 text-xs text-text-tertiary">
          <Info className="w-3.5 h-3.5 shrink-0" />
          <span>Para editar, usá la app</span>
        </span>
      </div>

      {/* Totales Debés vs Te deben */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div className="p-5 rounded-2xl bg-glass-fill border border-glass-border">
          <div className="flex items-center gap-2 text-xs font-semibold text-text-secondary">
            <ArrowUpRight className="w-4 h-4 text-danger" />
            <span>Debés</span>
          </div>
          <div className="text-2xl sm:text-3xl font-extrabold tracking-tight text-text-primary tabular-nums mt-2 whitespace-nowrap">
            <CountUp value={totalOwe} formatter={formatGs} />
          </div>
          <div className="text-xs text-text-tertiary mt-1">
            {activeOwe.length} {activeOwe.length === 1 ? 'préstamo activo' : 'préstamos activos'}
          </div>
        </div>

        <div className="p-5 rounded-2xl bg-glass-fill border border-glass-border">
          <div className="flex items-center gap-2 text-xs font-semibold text-text-secondary">
            <ArrowDownLeft className="w-4 h-4 text-positive" />
            <span>Te deben</span>
          </div>
          <div className="text-2xl sm:text-3xl font-extrabold tracking-tight text-text-primary tabular-nums mt-2 whitespace-nowrap">
            <CountUp value={totalLent} formatter={formatGs} />
          </div>
          <div className="text-xs text-text-tertiary mt-1">
            {activeLent.length} {activeLent.length === 1 ? 'préstamo activo' : 'préstamos activos'}
          </div>
        </div>
      </div>

      {/* Préstamos que debés */}
      <section className="space-y-3">
        <h2 className="text-lg font-bold text-text-primary flex items-center gap-2">
          <span>Préstamos que debés</span>
          <span className="text-xs font-normal text-text-tertiary">({activeOwe.length})</span>
        </h2>
        {activeOwe.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {activeOwe.map(renderLoanCard)}
          </div>
        ) : (
          <div className="p-6 rounded-2xl bg-glass-fill border border-glass-border text-center text-sm text-text-tertiary">
            No tenés préstamos por pagar en este momento.
          </div>
        )}
      </section>

      {/* Préstamos que te deben */}
      <section className="space-y-3">
        <h2 className="text-lg font-bold text-text-primary flex items-center gap-2">
          <span>Préstamos que te deben</span>
          <span className="text-xs font-normal text-text-tertiary">({activeLent.length})</span>
        </h2>
        {activeLent.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {activeLent.map(renderLoanCard)}
          </div>
        ) : (
          <div className="p-6 rounded-2xl bg-glass-fill border border-glass-border text-center text-sm text-text-tertiary">
            No tenés préstamos a cobrar en este momento.
          </div>
        )}
      </section>

      {/* Préstamos cerrados / saldados (plegados) */}
      {closedLoans.length > 0 && (
        <section className="pt-2 border-t border-glass-border">
          <button
            type="button"
            onClick={() => setShowClosed(!showClosed)}
            aria-expanded={showClosed}
            className="flex items-center justify-between w-full p-4 rounded-xl hover:bg-white/5 transition-colors cursor-pointer text-left"
          >
            <div className="flex items-center gap-2 font-bold text-sm text-text-secondary">
              <span>Cerrados ({closedLoans.length})</span>
            </div>
            <ChevronDown
              className={`w-4 h-4 text-text-tertiary transition-transform duration-200 ${
                showClosed ? 'rotate-180' : ''
              }`}
            />
          </button>

          {showClosed && (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-3 animate-in fade-in duration-200">
              {closedLoans.map(renderLoanCard)}
            </div>
          )}
        </section>
      )}
    </div>
  );
}
