/**
 * loan_progress.ts
 * Port of lib/features/loans/domain/loan_progress.dart
 */

export interface LoanInput {
  id: string;
  name: string;
  kind: 'loan' | 'installments' | string;
  direction: 'owe' | 'lent' | string;
  totalAmount: number;
  installmentAmount?: number | null;
  installmentsTotal?: number | null;
  dueDay?: number | null;
  startDate: string; // YYYY-MM-DD
  paidBeforeCount?: number;
  closedAt?: string | null;
}

export interface LoanInstallmentInput {
  id: string;
  loanId: string;
  number: number;
  dueDate: string; // YYYY-MM-DD
  amount: number;
}

export interface LoanPaymentInput {
  id: string;
  type: 'expense' | 'income' | string;
  amount: number;
  occurredAt: string; // ISO string or YYYY-MM-DD
  isExtra?: boolean;
  deletedAt?: string | null;
}

export interface LoanProgressResult {
  paid: number;
  balance: number;
  installmentsPaid: number;
  installmentsRemaining: number | null;
  percent: number;
  isClosed: boolean;
  nextDueDate: string | null;
  estimatedEndDate: string | null;
  daysUntilNextDue: number | null;
  paidBeforeCount: number;
  paidBeforeAmount: number;
}

function parseYMD(s: string): { year: number; month: number; day: number } {
  const parts = s.split('T')[0].split('-').map(Number);
  return { year: parts[0], month: parts[1], day: parts[2] };
}

function daysInMonth(year: number, month: number): number {
  return new Date(year, month, 0).getDate();
}

function formatYMD(d: { year: number; month: number; day: number } | Date): string {
  if (d instanceof Date) {
    const y = d.getFullYear().toString().padStart(4, '0');
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${day}`;
  }
  return `${d.year.toString().padStart(4, '0')}-${d.month.toString().padStart(2, '0')}-${d.day.toString().padStart(2, '0')}`;
}

export function effectiveSchedule(
  loan: LoanInput,
  schedule?: LoanInstallmentInput[] | null,
): LoanInstallmentInput[] | null {
  if (schedule && schedule.length > 0) return schedule;
  const amount = loan.installmentAmount;
  const count = loan.installmentsTotal;
  const dueDay = loan.dueDay;
  const paidBeforeCount = loan.paidBeforeCount ?? 0;

  if (
    paidBeforeCount <= 0 ||
    loan.kind !== 'installments' ||
    amount == null ||
    count == null ||
    dueDay == null
  ) {
    return schedule && schedule.length > 0 ? schedule : null;
  }

  function dueIn(year: number, month: number): { year: number; month: number; day: number } {
    const dim = daysInMonth(year, month);
    return { year, month, day: Math.min(dueDay!, dim) };
  }

  const start = parseYMD(loan.startDate);
  let first = dueIn(start.year, start.month);

  const startDateObj = new Date(start.year, start.month - 1, start.day);
  const firstDateObj = new Date(first.year, first.month - 1, first.day);

  if (firstDateObj.getTime() < startDateObj.getTime()) {
    const nextM = start.month === 12 ? 1 : start.month + 1;
    const nextY = start.month === 12 ? start.year + 1 : start.year;
    first = dueIn(nextY, nextM);
  }

  const result: LoanInstallmentInput[] = [];
  for (let i = 0; i < count; i++) {
    const targetMonthIndex = (first.month - 1) + i;
    const y = first.year + Math.floor(targetMonthIndex / 12);
    const m = (targetMonthIndex % 12) + 1;
    const due = dueIn(y, m);
    result.push({
      id: `${loan.id}:${i + 1}`,
      loanId: loan.id,
      number: i + 1,
      dueDate: formatYMD(due),
      amount,
    });
  }

  return result;
}

export function calculateLoanProgress({
  loan,
  schedule,
  payments,
  now,
}: {
  loan: LoanInput;
  schedule?: LoanInstallmentInput[] | null;
  payments: LoanPaymentInput[];
  now?: string | Date;
}): LoanProgressResult {
  const effSchedule = effectiveSchedule(loan, schedule);

  const nowDate = now
    ? (typeof now === 'string' ? new Date(now + 'T00:00:00') : new Date(now.getFullYear(), now.getMonth(), now.getDate()))
    : new Date();
  const today = new Date(nowDate.getFullYear(), nowDate.getMonth(), nowDate.getDate());

  const validPayments = (payments ?? []).filter((p) => p.deletedAt == null);
  const relevantPayments = validPayments.filter((p) => {
    if (loan.direction === 'owe') {
      return p.type === 'expense';
    } else {
      return p.type === 'income';
    }
  });

  const hasSchedule = effSchedule != null && effSchedule.length > 0;
  const paidBeforeCount = loan.paidBeforeCount ?? 0;

  let paidBeforeAmount = 0;
  if (hasSchedule) {
    paidBeforeAmount = effSchedule
      .slice(0, paidBeforeCount)
      .reduce((sum, i) => sum + i.amount, 0);
  } else if (loan.kind === 'installments' && loan.installmentAmount != null) {
    paidBeforeAmount = paidBeforeCount * loan.installmentAmount;
  }

  const paidFromPayments = relevantPayments.reduce((sum, p) => sum + p.amount, 0);
  const paid = paidBeforeAmount + paidFromPayments;
  const balance = Math.max(0, loan.totalAmount - paid);
  const isClosed = balance <= 0 || loan.closedAt != null;

  const regularPaymentsCount = relevantPayments.filter((p) => !p.isExtra).length;
  const totalCount = hasSchedule ? effSchedule.length : (loan.installmentsTotal ?? null);
  const totalRegularAndBefore = paidBeforeCount + regularPaymentsCount;
  const installmentsPaid = totalCount != null
    ? Math.min(totalCount, totalRegularAndBefore)
    : totalRegularAndBefore;

  const rawPercent = loan.totalAmount > 0
    ? Math.max(0, Math.min(1, paid / loan.totalAmount))
    : 1.0;
  const percent = Math.round(rawPercent * 1000) / 1000;

  let installmentsRemaining: number | null = null;
  let nextDueDate: string | null = null;
  let daysUntilNextDue: number | null = null;
  let estimatedEndDate: string | null = null;

  if (hasSchedule) {
    if (isClosed) {
      installmentsRemaining = 0;
      estimatedEndDate = effSchedule[effSchedule.length - 1].dueDate;
    } else {
      installmentsRemaining = Math.max(0, effSchedule.length - installmentsPaid);
      if (installmentsPaid < effSchedule.length) {
        const nextInst = effSchedule[installmentsPaid];
        nextDueDate = nextInst.dueDate;
        const nextDate = new Date(nextDueDate + 'T00:00:00');
        daysUntilNextDue = Math.round((nextDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
      }
      estimatedEndDate = effSchedule[effSchedule.length - 1].dueDate;
    }
  } else {
    if (loan.installmentAmount != null && loan.installmentAmount > 0) {
      installmentsRemaining = Math.ceil(balance / loan.installmentAmount);
    } else if (loan.installmentsTotal != null) {
      installmentsRemaining = Math.max(0, loan.installmentsTotal - installmentsPaid);
    }

    if (loan.dueDay != null && !isClosed) {
      const dueDay = loan.dueDay;

      function makeDate(year: number, month: number, targetDay: number): Date {
        const dim = daysInMonth(year, month);
        const day = Math.min(targetDay, dim);
        return new Date(year, month - 1, day);
      }

      const currentMonthDue = makeDate(today.getFullYear(), today.getMonth() + 1, dueDay);

      const paidThisMonth = relevantPayments.some((p) => {
        if (p.isExtra) return false;
        const pDate = new Date(p.occurredAt);
        return pDate.getFullYear() === today.getFullYear() && pDate.getMonth() === today.getMonth();
      });

      let nextDueObj: Date;
      if (currentMonthDue.getTime() >= today.getTime() && !paidThisMonth) {
        nextDueObj = currentMonthDue;
      } else {
        const nextM = today.getMonth() === 11 ? 1 : today.getMonth() + 2;
        const nextY = today.getMonth() === 11 ? today.getFullYear() + 1 : today.getFullYear();
        nextDueObj = makeDate(nextY, nextM, dueDay);
      }

      nextDueDate = formatYMD(nextDueObj);
      daysUntilNextDue = Math.round((nextDueObj.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));

      if (installmentsRemaining != null && installmentsRemaining > 0) {
        const endMonth = nextDueObj.getMonth() + 1 + (installmentsRemaining - 1);
        const endYear = nextDueObj.getFullYear() + Math.floor((endMonth - 1) / 12);
        const normalizedMonth = ((endMonth - 1) % 12) + 1;
        const endObj = makeDate(endYear, normalizedMonth, dueDay);
        estimatedEndDate = formatYMD(endObj);
      }
    }
  }

  return {
    paid,
    balance,
    installmentsPaid,
    installmentsRemaining,
    percent,
    isClosed,
    nextDueDate,
    estimatedEndDate,
    daysUntilNextDue,
    paidBeforeCount,
    paidBeforeAmount,
  };
}
