import React, { useEffect, useMemo } from 'react';
import { useParams, Link } from 'react-router-dom';
import { motion, useReducedMotion } from 'motion/react';
import { useQuery } from '@powersync/react';
import { ChevronRight, Download, ArrowLeft, ArrowUpRight, ArrowDownLeft } from 'lucide-react';
import { CountUp } from '@/components/CountUp';
import { Skeleton } from '@/components/Skeleton';
import { formatGs, formatThousands } from '@/lib/format';
import {
  calculateLoanProgress,
  effectiveSchedule,
  LoanInput,
  LoanInstallmentInput,
  LoanPaymentInput,
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

function formatDateFull(dateStr: string | null): string {
  if (!dateStr) return '';
  const [y, m, d] = dateStr.split('T')[0].split('-');
  return `${d}/${m}/${y}`;
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

export function PrestamoDetalleRoute() {
  const { id } = useParams<{ id: string }>();
  const prefersReduced = useReducedMotion();

  const { data: loanRows, isLoading: loadingLoan } = useQuery<LoanDbRow>(
    'SELECT * FROM loans WHERE id = ?',
    [id || '']
  );

  const { data: installmentRows, isLoading: loadingInstallments } = useQuery<InstallmentDbRow>(
    'SELECT * FROM loan_installments WHERE loan_id = ? ORDER BY number ASC',
    [id || '']
  );

  const { data: paymentRows, isLoading: loadingPayments } = useQuery<TxDbRow>(
    'SELECT id, loan_id, type, amount, occurred_at, is_extra, deleted_at FROM transactions WHERE loan_id = ? AND deleted_at IS NULL ORDER BY occurred_at DESC',
    [id || '']
  );

  const loan = loanRows?.[0];

  useEffect(() => {
    if (loan) {
      document.title = `${loan.name} · Préstamos · Pockt`;
    } else {
      document.title = 'Préstamo · Pockt';
    }
  }, [loan]);

  const { progress, effSchedule, nextAmount, totalInstallments, intereses } = useMemo(() => {
    if (!loan) {
      return {
        progress: null,
        effSchedule: [],
        nextAmount: null,
        totalInstallments: null,
        intereses: 0,
      };
    }

    const scheduleInputs: LoanInstallmentInput[] = (installmentRows ?? []).map((i) => ({
      id: i.id,
      loanId: i.loan_id,
      number: i.number,
      dueDate: toYMD(i.due_date),
      amount: i.amount,
    }));

    const paymentInputs: LoanPaymentInput[] = (paymentRows ?? []).map((p) => ({
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

    const calculatedProgress = calculateLoanProgress({
      loan: loanInput,
      schedule: scheduleInputs,
      payments: paymentInputs,
      now: new Date(),
    });

    const effective = effectiveSchedule(loanInput, scheduleInputs) ?? [];

    let calculatedNextAmount: number | null = null;
    if (effective.length > calculatedProgress.installmentsPaid) {
      calculatedNextAmount = effective[calculatedProgress.installmentsPaid].amount;
    } else {
      calculatedNextAmount = loan.installment_amount ?? (loan.installments_total == null ? calculatedProgress.balance : null);
    }

    const totalCount = effective.length > 0 ? effective.length : (loan.installments_total ?? null);

    const totalScheduleAmount = effective.length > 0
      ? effective.reduce((s, i) => s + i.amount, 0)
      : (loan.installment_amount && loan.installments_total ? loan.installment_amount * loan.installments_total : 0);

    const calcIntereses = Math.max(0, totalScheduleAmount - loan.total_amount);

    return {
      progress: calculatedProgress,
      effSchedule: effective,
      nextAmount: calculatedNextAmount,
      totalInstallments: totalCount,
      intereses: calcIntereses,
    };
  }, [loan, installmentRows, paymentRows]);

  if (loadingLoan || loadingInstallments || loadingPayments) {
    return (
      <div className="space-y-6">
        <Skeleton className="w-48 h-6 rounded-lg" />
        <Skeleton className="w-72 h-10 rounded-xl" />
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <Skeleton className="h-32 rounded-2xl" />
          <Skeleton className="h-32 rounded-2xl" />
          <Skeleton className="h-32 rounded-2xl" />
          <Skeleton className="h-32 rounded-2xl" />
        </div>
      </div>
    );
  }

  if (!loan || !progress) {
    return (
      <div className="text-center py-16 space-y-4">
        <h2 className="text-2xl font-bold text-text-primary">Préstamo no encontrado</h2>
        <p className="text-sm text-text-secondary">
          El préstamo que buscás no existe o fue eliminado.
        </p>
        <Link
          to="/prestamos"
          className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full font-bold text-sm text-white shadow-md hover:opacity-90 transition-opacity"
          style={{
            background: 'linear-gradient(90deg, var(--brand-start), var(--brand-end))',
          }}
        >
          <ArrowLeft className="w-4 h-4" />
          <span>Volver a Préstamos</span>
        </Link>
      </div>
    );
  }

  const isOwe = loan.direction === 'owe';
  const percentInt = Math.round(progress.percent * 100);

  const handleDownloadSchedule = () => {
    if (!effSchedule || effSchedule.length === 0) return;

    const headers = ['Cuota', 'Vencimiento', 'Estado', 'Monto'];
    const rows = effSchedule.map((inst, idx) => {
      let estado = '';
      if (idx < progress.installmentsPaid) {
        estado = 'Pagada';
      } else if (idx === progress.installmentsPaid && !progress.isClosed) {
        estado = 'Próxima';
      }
      return [
        inst.number.toString(),
        inst.dueDate,
        estado,
        inst.amount.toString(),
      ];
    });

    const csvContent = [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `cronograma-${loan.name.toLowerCase().replace(/\s+/g, '-')}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  return (
    <div className="space-y-6 select-none">
      {/* Migas de pan */}
      <div className="flex items-center gap-2 text-xs text-text-tertiary">
        <Link to="/prestamos" className="hover:text-text-primary transition-colors">
          Préstamos
        </Link>
        <ChevronRight className="w-3.5 h-3.5 text-text-tertiary" />
        <span className="text-text-primary font-medium">{loan.name}</span>
      </div>

      {/* Header con título, chip de descarga y aviso de app */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <span
            className="w-8 h-8 rounded-xl grid place-items-center text-sm"
            style={{
              backgroundColor: isOwe ? 'rgba(244, 81, 79, 0.12)' : 'rgba(74, 212, 150, 0.12)',
              color: isOwe ? 'var(--danger)' : 'var(--positive)',
            }}
          >
            {isOwe ? <ArrowUpRight className="w-4 h-4" /> : <ArrowDownLeft className="w-4 h-4" />}
          </span>
          <div>
            <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-text-primary">
              {loan.name}
            </h1>
            {loan.counterparty && (
              <p className="text-xs text-text-tertiary mt-0.5">
                {isOwe ? `Acreedor: ${loan.counterparty}` : `Deudor: ${loan.counterparty}`}
              </p>
            )}
          </div>
        </div>

        <div className="flex items-center gap-3">
          <span className="hidden sm:inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold text-text-tertiary bg-white/5 border border-glass-border">
            Para editar, usá la app
          </span>

          {effSchedule.length > 0 && (
            <button
              type="button"
              onClick={handleDownloadSchedule}
              className="inline-flex items-center gap-2 px-4 py-2 rounded-full text-xs font-bold text-text-primary bg-glass-fill border border-glass-border hover:bg-white/10 transition-colors cursor-pointer"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Descargar cronograma</span>
            </button>
          )}
        </div>
      </div>

      {/* 4 KPIs grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* KPI 1: Saldo pendiente */}
        <div
          className="p-5 rounded-2xl border"
          style={{
            borderColor: 'rgba(255, 138, 61, 0.4)',
            background: 'linear-gradient(160deg, rgba(255, 138, 61, 0.13), rgba(255, 61, 127, 0.05))',
          }}
        >
          <div className="text-xs font-semibold text-text-secondary">Saldo pendiente</div>
          <div className="text-2xl sm:text-3xl font-extrabold tracking-tight text-text-primary tabular-nums mt-2">
            <CountUp value={progress.balance} formatter={formatGs} />
          </div>
          {/* Barra de progreso con resorte */}
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
          <div className="text-xs text-text-tertiary mt-2">
            {totalInstallments != null
              ? `${progress.installmentsPaid} de ${totalInstallments} cuotas · ${percentInt} %`
              : `${progress.installmentsPaid} pagadas · ${percentInt} %`}
          </div>
        </div>

        {/* KPI 2: Próxima cuota */}
        <div className="p-5 rounded-2xl bg-glass-fill border border-glass-border">
          <div className="text-xs font-semibold text-text-secondary">Próxima cuota</div>
          <div className="text-2xl sm:text-3xl font-extrabold tracking-tight text-text-primary tabular-nums mt-2">
            {nextAmount != null ? <CountUp value={nextAmount} formatter={formatGs} /> : '—'}
          </div>
          <div className="text-xs text-text-tertiary mt-2">
            {progress.nextDueDate
              ? `vence ${formatDateShort(progress.nextDueDate)} · en ${progress.daysUntilNextDue ?? 0} días`
              : 'Sin cuotas pendientes'}
          </div>
        </div>

        {/* KPI 3: Intereses del préstamo */}
        <div className="p-5 rounded-2xl bg-glass-fill border border-glass-border">
          <div className="text-xs font-semibold text-text-secondary">Intereses del préstamo</div>
          <div className="text-2xl sm:text-3xl font-extrabold tracking-tight text-text-primary tabular-nums mt-2">
            <CountUp value={intereses} formatter={formatGs} />
          </div>
          <div className="text-xs text-text-tertiary mt-2">total menos capital</div>
        </div>

        {/* KPI 4: Fin */}
        <div className="p-5 rounded-2xl bg-glass-fill border border-glass-border">
          <div className="text-xs font-semibold text-text-secondary">Fin</div>
          <div className="text-2xl sm:text-3xl font-extrabold tracking-tight text-text-primary mt-2">
            {progress.estimatedEndDate ? formatMonthYear(progress.estimatedEndDate) : '—'}
          </div>
          <div className="text-xs text-text-tertiary mt-2">sin adelantos</div>
        </div>
      </div>

      {/* 2 columnas: Cronograma vs Pagos registrados */}
      <div className="grid grid-cols-1 lg:grid-cols-[1.6fr_1fr] gap-6">
        {/* Columna Izquierda: Cronograma */}
        <div className="p-5 rounded-2xl bg-glass-fill border border-glass-border">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-bold text-base text-text-primary">Cronograma</h2>
            <span className="text-xs text-text-tertiary">
              {effSchedule.length > 0 ? `${effSchedule.length} cuotas` : 'Sin cronograma'}
            </span>
          </div>

          {effSchedule.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs sm:text-sm border-collapse">
                <thead>
                  <tr className="border-b border-glass-border text-text-tertiary text-xs">
                    <th className="py-2 font-semibold">Cuota</th>
                    <th className="py-2 font-semibold">Vence</th>
                    <th className="py-2 font-semibold">Estado</th>
                    <th className="py-2 font-semibold text-right">Monto</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-white/5">
                  {effSchedule.map((inst, idx) => {
                    const isPaid = idx < progress.installmentsPaid;
                    const isNext = idx === progress.installmentsPaid && !progress.isClosed;

                    return (
                      <tr
                        key={inst.id}
                        className={`transition-colors ${
                          isNext ? 'bg-[rgba(255,138,61,0.08)]' : 'hover:bg-white/5'
                        }`}
                      >
                        <td className={`py-3 ${isPaid ? 'text-text-tertiary' : 'text-text-primary font-medium'}`}>
                          Cuota {inst.number} de {effSchedule.length}
                        </td>
                        <td className="py-3 text-text-tertiary tabular-nums">
                          {formatDateFull(inst.dueDate)}
                        </td>
                        <td className="py-3">
                          {isPaid && (
                            <span className="text-text-tertiary font-medium">Pagada</span>
                          )}
                          {isNext && (
                            <span className="text-brand-start font-bold">Próxima</span>
                          )}
                        </td>
                        <td className={`py-3 text-right tabular-nums ${isPaid ? 'text-text-tertiary' : 'text-text-primary font-medium'}`}>
                          Gs. {formatThousands(inst.amount)}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="py-8 text-center text-xs text-text-tertiary">
              Este préstamo no tiene un cronograma de cuotas detallado.
            </div>
          )}
        </div>

        {/* Columna Derecha: Pagos registrados */}
        <div className="p-5 rounded-2xl bg-glass-fill border border-glass-border flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-bold text-base text-text-primary">Pagos registrados</h2>
              <span className="text-xs text-text-tertiary">
                {paymentRows?.length ?? 0} {paymentRows?.length === 1 ? 'pago' : 'pagos'}
              </span>
            </div>

            {paymentRows && paymentRows.length > 0 ? (
              <div className="space-y-3">
                {paymentRows.map((tx, idx) => (
                  <div
                    key={tx.id}
                    className="flex items-center justify-between py-2 border-b border-white/5 last:border-none text-xs sm:text-sm"
                  >
                    <div>
                      <div className="font-semibold text-text-primary">
                        Cuota {paymentRows.length - idx}
                      </div>
                      <div className="text-xs text-text-tertiary">
                        {toYMD(tx.occurred_at)}
                      </div>
                    </div>
                    <div className="font-bold text-text-primary tabular-nums">
                      Gs. {formatThousands(tx.amount)}
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="py-8 text-center text-xs text-text-tertiary">
                No hay pagos registrados aún para este préstamo.
              </div>
            )}
          </div>

          {/* Aviso al pie */}
          <div className="mt-8 pt-4 border-t border-glass-border text-xs text-text-tertiary leading-relaxed">
            Los pagos se registran en el celular o con "Cargar" eligiendo el préstamo.
            Préstamos, metas y presupuestos se ven acá y se editan en la app (primera versión).
          </div>
        </div>
      </div>
    </div>
  );
}
