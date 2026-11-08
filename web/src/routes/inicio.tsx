import React, { useEffect, useState, useMemo, useRef } from 'react';
import { motion, useReducedMotion } from 'motion/react';
import { useQuery, usePowerSync } from '@powersync/react';
import { Link, useSearchParams } from 'react-router-dom';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { Skeleton } from '@/components/Skeleton';
import { CountUp } from '@/components/CountUp';
import { AuroraShader } from '@/components/AuroraShader';
import { MovementPanel } from '@/components/movements/MovementPanel';
import { periodFor } from '@/lib/calc/date_period';
import { buildCategoryArcSegments } from '@/lib/calc/category_arc_data';
import { compareToPreviousMonth } from '@/lib/calc/reports';
import {
  calculateLoanProgress,
  effectiveSchedule,
  LoanInput,
  LoanInstallmentInput,
  LoanPaymentInput,
} from '@/lib/calc/loan_progress';
import { formatGs } from '@/lib/format';
import { cn } from '@/lib/utils';

const MONTH_ABBRS = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

interface TxRow {
  id: string;
  type: string;
  amount: number;
  category_id: string;
  category_name?: string;
  color_dark?: number;
  color_light?: number;
  merchant?: string | null;
  note?: string | null;
  occurred_at: number;
  is_extra?: number;
  currency?: string;
}

interface GoalRow {
  id: string;
  name: string;
  target_amount: number;
  archived: number;
}

interface GoalContribRow {
  id: string;
  goal_id: string;
  amount: number;
  date: number;
}

interface UpcomingDue {
  id: string;
  title: string;
  dateStr: string;
  timestamp: number;
  amount: number;
}

function parseHexColor(colorInt: number | null | undefined): string {
  if (colorInt == null) return '#7C8796';
  const rgb = colorInt & 0x00ffffff;
  return `#${rgb.toString(16).padStart(6, '0')}`;
}

export function InicioRoute() {
  const prefersReduced = useReducedMotion();
  const db = usePowerSync();

  useEffect(() => {
    document.title = 'Inicio · Pockt';
  }, []);

  const [searchParams, setSearchParams] = useSearchParams();
  const mesParam = searchParams.get('mes');

  const now = useMemo(() => new Date(), []);
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth() + 1; // 1-12
  const currentMonthKey = `${currentYear}-${String(currentMonth).padStart(2, '0')}`;

  const { selectedYear, selectedMonth, selectedMonthKey, isPastMonth, isCurrentMonth } = useMemo(() => {
    if (mesParam && /^\d{4}-(0[1-9]|1[0-2])$/.test(mesParam)) {
      const [y, m] = mesParam.split('-').map(Number);
      if (y > currentYear || (y === currentYear && m > currentMonth)) {
        return {
          selectedYear: currentYear,
          selectedMonth: currentMonth,
          selectedMonthKey: currentMonthKey,
          isPastMonth: false,
          isCurrentMonth: true,
        };
      }
      const isPast = y < currentYear || (y === currentYear && m < currentMonth);
      return {
        selectedYear: y,
        selectedMonth: m,
        selectedMonthKey: `${y}-${String(m).padStart(2, '0')}`,
        isPastMonth: isPast,
        isCurrentMonth: !isPast,
      };
    }
    return {
      selectedYear: currentYear,
      selectedMonth: currentMonth,
      selectedMonthKey: currentMonthKey,
      isPastMonth: false,
      isCurrentMonth: true,
    };
  }, [mesParam, currentYear, currentMonth, currentMonthKey]);

  const [slideDirection, setSlideDirection] = useState<-1 | 1 | 0>(0);
  const [popoverOpen, setPopoverOpen] = useState(false);
  const [popoverYear, setPopoverYear] = useState(selectedYear);
  const selectorRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setPopoverYear(selectedYear);
  }, [selectedYear, popoverOpen]);

  const navigateToMonth = (targetYear: number, targetMonth: number) => {
    if (targetYear > currentYear || (targetYear === currentYear && targetMonth > currentMonth)) {
      return;
    }
    const targetKey = `${targetYear}-${String(targetMonth).padStart(2, '0')}`;
    const diff = targetYear * 12 + targetMonth - (selectedYear * 12 + selectedMonth);
    setSlideDirection(diff < 0 ? -1 : 1);

    const newParams = new URLSearchParams(searchParams);
    if (targetKey === currentMonthKey) {
      newParams.delete('mes');
    } else {
      newParams.set('mes', targetKey);
    }
    setSearchParams(newParams);
    setPopoverOpen(false);
  };

  const handlePrevMonth = () => {
    let prevY = selectedYear;
    let prevM = selectedMonth - 1;
    if (prevM < 1) {
      prevM = 12;
      prevY -= 1;
    }
    navigateToMonth(prevY, prevM);
  };

  const handleNextMonth = () => {
    if (isCurrentMonth) return;
    let nextY = selectedYear;
    let nextM = selectedMonth + 1;
    if (nextM > 12) {
      nextM = 1;
      nextY += 1;
    }
    navigateToMonth(nextY, nextM);
  };

  const handleResetToCurrentMonth = () => {
    navigateToMonth(currentYear, currentMonth);
  };

  // Keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const active = document.activeElement;
      const isInput =
        active instanceof HTMLInputElement ||
        active instanceof HTMLTextAreaElement ||
        (active && (active as HTMLElement).isContentEditable);

      if (e.key === 'Escape') {
        setPopoverOpen(false);
        return;
      }

      if (isInput) return;

      if (e.key === 'ArrowLeft') {
        handlePrevMonth();
      } else if (e.key === 'ArrowRight') {
        if (!isCurrentMonth) {
          handleNextMonth();
        }
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [selectedYear, selectedMonth, isCurrentMonth]);

  // Click outside listener for popover
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (selectorRef.current && !selectorRef.current.contains(e.target as Node)) {
        setPopoverOpen(false);
      }
    };
    if (popoverOpen) {
      document.addEventListener('mousedown', handleClickOutside);
      return () => document.removeEventListener('mousedown', handleClickOutside);
    }
  }, [popoverOpen]);

  const todayStr = useMemo(() => {
    const y = now.getFullYear().toString().padStart(4, '0');
    const m = (now.getMonth() + 1).toString().padStart(2, '0');
    const d = now.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${d}`;
  }, [now]);

  // Settings
  const { data: settingsData, isLoading: loadingSettings } = useQuery<{ key: string; value: string }>(
    "SELECT * FROM settings WHERE key = 'period_month_start'"
  );

  // Income Schedule
  const { data: scheduleData, isLoading: loadingSchedule } = useQuery<{
    pay_days: string;
    pay_day_rules: string;
  }>('SELECT * FROM income_schedules ORDER BY effective_from DESC LIMIT 1');

  // Compute period
  const period = useMemo(() => {
    const modeSetting = settingsData?.find((s) => s.key === 'period_month_start')?.value;
    const sched = scheduleData?.[0];

    let payDays: number[] | undefined;
    let payDayRules: string[] | undefined;

    if (sched) {
      try {
        if (sched.pay_days) payDays = JSON.parse(sched.pay_days);
      } catch (_) {}
      try {
        if (sched.pay_day_rules) payDayRules = JSON.parse(sched.pay_day_rules);
      } catch (_) {}
    }

    const targetDayStr = isCurrentMonth
      ? todayStr
      : `${selectedYear}-${String(selectedMonth).padStart(2, '0')}-15`;

    return periodFor(targetDayStr, {
      mode: modeSetting,
      payDays,
      payDayRules,
    });
  }, [settingsData, scheduleData, todayStr, isCurrentMonth, selectedYear, selectedMonth]);

  const startSec = useMemo(() => Math.floor(new Date(period.start + 'T00:00:00').getTime() / 1000), [period.start]);
  const endSec = useMemo(() => Math.floor(new Date(period.end + 'T23:59:59').getTime() / 1000) + 1, [period.end]);

  // Current period transactions
  const { data: periodTxs, isLoading: loadingTxs } = useQuery<TxRow>(
    `SELECT t.*, c.name as category_name, c.color_dark, c.color_light
     FROM transactions t
     LEFT JOIN categories c ON t.category_id = c.id
     WHERE t.deleted_at IS NULL AND t.occurred_at >= ? AND t.occurred_at < ?
     ORDER BY t.occurred_at DESC`,
    [startSec, endSec]
  );

  // Six-month transactions for evolution & comparison (ending in selected month)
  const sixMonthsAgoSec = useMemo(() => {
    const d = new Date(selectedYear, selectedMonth - 1 - 5, 1, 0, 0, 0);
    return Math.floor(d.getTime() / 1000);
  }, [selectedYear, selectedMonth]);

  const sixMonthsEndSec = useMemo(() => {
    const d = new Date(selectedYear, selectedMonth, 1, 0, 0, 0);
    return Math.floor(d.getTime() / 1000);
  }, [selectedYear, selectedMonth]);

  const { data: sixMonthsTxs, isLoading: loadingSixMonths } = useQuery<TxRow>(
    `SELECT t.*, c.name as category_name, c.color_dark, c.color_light
     FROM transactions t
     LEFT JOIN categories c ON t.category_id = c.id
     WHERE t.deleted_at IS NULL AND t.occurred_at >= ? AND t.occurred_at < ?
     ORDER BY t.occurred_at ASC`,
    [sixMonthsAgoSec, sixMonthsEndSec]
  );

  // All transaction dates for popover activity
  const { data: allTxDates } = useQuery<{ occurred_at: number }>(
    'SELECT occurred_at FROM transactions WHERE deleted_at IS NULL'
  );

  const activeMonths = useMemo(() => {
    const set = new Set<string>();
    for (const tx of allTxDates ?? []) {
      const ms = tx.occurred_at > 1e11 ? tx.occurred_at : tx.occurred_at * 1000;
      const d = new Date(ms);
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      set.add(key);
    }
    for (const tx of sixMonthsTxs ?? []) {
      const ms = tx.occurred_at > 1e11 ? tx.occurred_at : tx.occurred_at * 1000;
      const d = new Date(ms);
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      set.add(key);
    }
    return set;
  }, [allTxDates, sixMonthsTxs]);

  // Goals
  const { data: goals, isLoading: loadingGoals } = useQuery<GoalRow>(
    'SELECT * FROM goals WHERE archived = 0'
  );

  const { data: goalContribs, isLoading: loadingContribs } = useQuery<GoalContribRow>(
    'SELECT * FROM goal_contributions'
  );

  // Loans, installments, and payments for upcoming loan dues
  const { data: loansData, isLoading: loadingLoans } = useQuery<{
    id: string;
    direction: 'owe' | 'lent';
    kind: string;
    name: string;
    total_amount: number;
    installment_amount?: number | null;
    installments_total?: number | null;
    due_day?: number | null;
    start_date: number | string;
    closed_at?: number | null;
    paid_before_count?: number | null;
  }>('SELECT * FROM loans WHERE closed_at IS NULL');

  const { data: loanInstallmentsData, isLoading: loadingInstallments } = useQuery<{
    id: string;
    loan_id: string;
    number: number;
    due_date: number | string;
    amount: number;
  }>('SELECT * FROM loan_installments ORDER BY number ASC');

  const { data: loanPaymentsData, isLoading: loadingPayments } = useQuery<{
    id: string;
    loan_id?: string | null;
    type: string;
    amount: number;
    occurred_at: number;
    is_extra?: number | null;
    deleted_at?: number | null;
  }>('SELECT id, loan_id, type, amount, occurred_at, is_extra, deleted_at FROM transactions WHERE loan_id IS NOT NULL AND deleted_at IS NULL');

  // Upcoming recurring rules (always from today onwards)
  const { data: recurringDues, isLoading: loadingRecurring } = useQuery<{
    id: string;
    name: string;
    amount: number;
    next_due_date: number;
    active: number;
  }>(
    `SELECT * FROM recurring_rules
     WHERE active = 1 AND next_due_date >= ? AND next_due_date <= ?
     ORDER BY next_due_date ASC LIMIT 5`,
    [Math.floor(now.getTime() / 1000), Math.floor(now.getTime() / 1000) + 30 * 86400]
  );

  // Latest 5 transactions
  const { data: recentTxsQuery, isLoading: loadingRecent } = useQuery<TxRow>(
    `SELECT t.*, c.name as category_name, c.color_dark, c.color_light
     FROM transactions t
     LEFT JOIN categories c ON t.category_id = c.id
     WHERE t.deleted_at IS NULL AND t.occurred_at >= ? AND t.occurred_at < ?
     ORDER BY t.occurred_at DESC LIMIT 5`,
    [startSec, endSec]
  );

  const recentTxs = useMemo(() => {
    if (recentTxsQuery && recentTxsQuery.length > 0) return recentTxsQuery;
    return (periodTxs ?? []).slice(0, 5);
  }, [recentTxsQuery, periodTxs]);

  // Categories for MovementPanel
  const { data: allCategories } = useQuery<{
    id: string;
    name: string;
    icon: string;
    color_dark: number;
    color_light: number;
  }>('SELECT id, name, icon, color_dark, color_light FROM categories WHERE archived = 0 ORDER BY sort_order ASC');

  // Selected movement for editing
  const [selectedTx, setSelectedTx] = useState<TxRow | null>(null);

  // Helper for formatting YMD
  function toYMD(val: number | string | Date | null | undefined): string {
    if (!val) return '';
    if (val instanceof Date) {
      const y = val.getFullYear().toString().padStart(4, '0');
      const m = (val.getMonth() + 1).toString().padStart(2, '0');
      const d = val.getDate().toString().padStart(2, '0');
      return `${y}-${m}-${d}`;
    }
    if (typeof val === 'number') {
      const ms = val > 1e11 ? val : val * 1000;
      const d = new Date(ms);
      const y = d.getFullYear().toString().padStart(4, '0');
      const m = (d.getMonth() + 1).toString().padStart(2, '0');
      const day = d.getDate().toString().padStart(2, '0');
      return `${y}-${m}-${day}`;
    }
    const str = String(val);
    if (str.includes('-')) return str.split('T')[0];
    const num = Number(str);
    if (!isNaN(num) && num > 0) {
      const ms = num > 1e11 ? num : num * 1000;
      const d = new Date(ms);
      const y = d.getFullYear().toString().padStart(4, '0');
      const m = (d.getMonth() + 1).toString().padStart(2, '0');
      const day = d.getDate().toString().padStart(2, '0');
      return `${y}-${m}-${day}`;
    }
    return str;
  }

  // Calculations
  const totalSpent = useMemo(() => {
    return (periodTxs ?? [])
      .filter((t) => t.type === 'expense')
      .reduce((sum, t) => sum + t.amount, 0);
  }, [periodTxs]);

  const { totalIncome, incomeCount } = useMemo(() => {
    const incomes = (periodTxs ?? []).filter((t) => t.type === 'income');
    return {
      totalIncome: incomes.reduce((sum, t) => sum + t.amount, 0),
      incomeCount: incomes.length,
    };
  }, [periodTxs]);

  const { totalSaved, activeGoalsCount } = useMemo(() => {
    const activeGoals = goals ?? [];
    const activeIds = new Set(activeGoals.map((g) => g.id));
    const saved = (goalContribs ?? [])
      .filter((c) => {
        if (!activeIds.has(c.goal_id)) return false;
        if (c.date != null) {
          const ms = typeof c.date === 'number' ? (c.date > 1e11 ? c.date : c.date * 1000) : new Date(c.date).getTime();
          const sec = Math.floor(ms / 1000);
          return sec <= endSec;
        }
        return true;
      })
      .reduce((sum, c) => sum + c.amount, 0);
    return {
      totalSaved: saved,
      activeGoalsCount: activeGoals.length,
    };
  }, [goals, goalContribs, endSec]);

  // Comparison
  const comparison = useMemo(() => {
    const dailyMap: Record<string, number> = {};
    for (const tx of sixMonthsTxs ?? []) {
      if (tx.type !== 'expense') continue;
      const ms = tx.occurred_at > 1e11 ? tx.occurred_at : tx.occurred_at * 1000;
      const d = new Date(ms);
      const y = d.getFullYear().toString().padStart(4, '0');
      const m = (d.getMonth() + 1).toString().padStart(2, '0');
      const day = d.getDate().toString().padStart(2, '0');
      const key = `${y}-${m}-${day}`;
      dailyMap[key] = (dailyMap[key] ?? 0) + tx.amount;
    }
    const compareDay = isCurrentMonth ? todayStr : period.end;
    return compareToPreviousMonth({
      today: compareDay,
      dailyExpenseByLocalDay: dailyMap,
    });
  }, [sixMonthsTxs, todayStr, isCurrentMonth, period.end]);

  const prevMonthName = useMemo(() => {
    const prevDate = new Date(selectedYear, selectedMonth - 2, 1);
    return prevDate.toLocaleDateString('es-PY', { month: 'long' }).toLowerCase();
  }, [selectedYear, selectedMonth]);

  const prevMonthTotal = useMemo(() => {
    const prevDate = new Date(selectedYear, selectedMonth - 2, 1);
    const prevYear = prevDate.getFullYear();
    const prevMonth = prevDate.getMonth() + 1;
    let total = 0;
    for (const tx of sixMonthsTxs ?? []) {
      if (tx.type !== 'expense') continue;
      const ms = tx.occurred_at > 1e11 ? tx.occurred_at : tx.occurred_at * 1000;
      const d = new Date(ms);
      if (d.getFullYear() === prevYear && (d.getMonth() + 1) === prevMonth) {
        total += tx.amount;
      }
    }
    return total;
  }, [sixMonthsTxs, selectedYear, selectedMonth]);

  // Categories arc data
  const arcSegments = useMemo(() => {
    const catMap = new Map<string, { id: string; name: string; amount: number; colorDark: number; colorLight: number }>();
    for (const tx of periodTxs ?? []) {
      if (tx.type !== 'expense') continue;
      const id = tx.category_id;
      const cur = catMap.get(id);
      if (cur) {
        cur.amount += tx.amount;
      } else {
        catMap.set(id, {
          id,
          name: tx.category_name ?? 'Categoría',
          amount: tx.amount,
          colorDark: tx.color_dark ?? 0xff7c8796,
          colorLight: tx.color_light ?? 0xff606a74,
        });
      }
    }
    return buildCategoryArcSegments(Array.from(catMap.values()));
  }, [periodTxs]);

  // 6 months evolution data
  const sixMonthsData = useMemo(() => {
    const months: { label: string; year: number; month: number; income: number; expense: number }[] = [];
    const monthNames = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

    for (let i = 5; i >= 0; i--) {
      const d = new Date(selectedYear, selectedMonth - 1 - i, 1);
      months.push({
        label: monthNames[d.getMonth()],
        year: d.getFullYear(),
        month: d.getMonth() + 1,
        income: 0,
        expense: 0,
      });
    }

    for (const tx of sixMonthsTxs ?? []) {
      const ms = tx.occurred_at > 1e11 ? tx.occurred_at : tx.occurred_at * 1000;
      const d = new Date(ms);
      const y = d.getFullYear();
      const m = d.getMonth() + 1;
      const found = months.find((entry) => entry.year === y && entry.month === m);
      if (found) {
        if (tx.type === 'expense') found.expense += tx.amount;
        else if (tx.type === 'income') found.income += tx.amount;
      }
    }

    return months;
  }, [sixMonthsTxs, now]);

  // Upcoming dues merged (loans using loan_progress + recurring rules)
  const upcomingList: UpcomingDue[] = useMemo(() => {
    const list: UpcomingDue[] = [];

    const instMap = new Map<string, Array<{ id: string; loan_id: string; number: number; due_date: number | string; amount: number }>>();
    for (const inst of loanInstallmentsData ?? []) {
      const l = instMap.get(inst.loan_id) ?? [];
      l.push(inst);
      instMap.set(inst.loan_id, l);
    }

    const payMap = new Map<string, Array<{ id: string; loan_id?: string | null; type: string; amount: number; occurred_at: number; is_extra?: number | null; deleted_at?: number | null }>>();
    for (const pay of loanPaymentsData ?? []) {
      if (!pay.loan_id) continue;
      const l = payMap.get(pay.loan_id) ?? [];
      l.push(pay);
      payMap.set(pay.loan_id, l);
    }

    for (const loan of loansData ?? []) {
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

      if (progress.isClosed || !progress.nextDueDate) continue;

      const [y, m, d] = progress.nextDueDate.split('-').map(Number);
      const dueDateObj = new Date(y, m - 1, d);
      const dueSec = Math.floor(dueDateObj.getTime() / 1000);
      const nowSec = Math.floor(now.getTime() / 1000);
      const thirtyDaysSec = nowSec + 30 * 86400;

      // Within next 30 days
      if (dueSec >= nowSec - 86400 && dueSec <= thirtyDaysSec) {
        const eff = effectiveSchedule(loanInput, scheduleInputs);
        let nextAmount: number;
        if (eff && eff.length > progress.installmentsPaid) {
          nextAmount = eff[progress.installmentsPaid].amount;
        } else {
          nextAmount = loan.installment_amount ?? progress.balance;
        }

        const totalCount = eff ? eff.length : (loan.installments_total ?? null);
        const installmentNum = progress.installmentsPaid + 1;
        const title = totalCount
          ? `${loan.name} · cuota ${installmentNum} de ${totalCount}`
          : loan.name;

        list.push({
          id: `loan-${loan.id}-${installmentNum}`,
          title,
          dateStr: `${d.toString().padStart(2, '0')}/${m.toString().padStart(2, '0')}`,
          timestamp: dueSec,
          amount: nextAmount,
        });
      }
    }

    for (const r of recurringDues ?? []) {
      const d = new Date(r.next_due_date * 1000);
      const dd = d.getDate().toString().padStart(2, '0');
      const mm = (d.getMonth() + 1).toString().padStart(2, '0');
      list.push({
        id: `rec-${r.id}`,
        title: r.name,
        dateStr: `${dd}/${mm}`,
        timestamp: r.next_due_date,
        amount: r.amount,
      });
    }

    list.sort((a, b) => a.timestamp - b.timestamp);
    return list.slice(0, 5);
  }, [loansData, loanInstallmentsData, loanPaymentsData, recurringDues, now]);

  // Month header name in Spanish
  const monthLabel = useMemo(() => {
    const d = new Date(selectedYear, selectedMonth - 1, 1);
    const name = d.toLocaleDateString('es-PY', { month: 'long' });
    const capitalized = name.charAt(0).toUpperCase() + name.slice(1);
    return `${capitalized} ${selectedYear}`;
  }, [selectedYear, selectedMonth]);

  const shortMonth = useMemo(() => {
    const d = new Date(selectedYear, selectedMonth - 1, 1);
    const name = d.toLocaleDateString('es-PY', { month: 'long' });
    return name.charAt(0).toUpperCase() + name.slice(1);
  }, [selectedYear, selectedMonth]);

  const isLoadingKPIs = loadingSettings || loadingSchedule || loadingTxs || loadingGoals || loadingContribs || loadingSixMonths;
  const isLoadingCharts = loadingSixMonths || loadingTxs;
  const isLoadingLists = loadingRecent || loadingLoans || loadingInstallments || loadingPayments || loadingRecurring;

  // Stagger animation variants
  const cardVariants = {
    hidden: { opacity: 0, y: 14, scale: 0.98 },
    visible: { opacity: 1, y: 0, scale: 1 },
  };

  return (
    <div className="space-y-6 relative max-w-[1180px] mx-auto pb-12">
      <AuroraShader opacity={0.22} interactive={false} />

      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <h1 className="text-[26px] sm:text-[28px] font-extrabold tracking-tight text-text-primary">
          {monthLabel}
        </h1>

        <div className="flex items-center gap-3 relative" ref={selectorRef}>
          {isPastMonth && (
            <button
              type="button"
              onClick={handleResetToCurrentMonth}
              className="min-h-[40px] inline-flex items-center text-[12.5px] font-semibold text-brand-start hover:underline cursor-pointer transition-colors"
            >
              Volver a este mes
            </button>
          )}

          <div className="flex items-center gap-1 bg-glass-fill border border-glass-border rounded-full p-1 backdrop-blur-md shadow-sm min-h-[40px]">
            <button
              type="button"
              aria-label="Mes anterior"
              onClick={handlePrevMonth}
              className="h-8 w-8 min-w-[32px] min-h-[32px] rounded-full flex items-center justify-center text-text-secondary hover:text-text-primary hover:bg-white/10 transition-colors cursor-pointer"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>

            <button
              type="button"
              onClick={() => setPopoverOpen((v) => !v)}
              className="min-h-[32px] px-3 rounded-full flex items-center justify-center text-[13px] font-semibold text-text-primary hover:bg-white/10 transition-colors cursor-pointer"
            >
              {shortMonth}
            </button>

            <button
              type="button"
              aria-label="Mes siguiente"
              onClick={handleNextMonth}
              disabled={isCurrentMonth}
              className={cn(
                'h-8 w-8 min-w-[32px] min-h-[32px] rounded-full flex items-center justify-center transition-colors',
                isCurrentMonth
                  ? 'opacity-30 cursor-not-allowed pointer-events-none'
                  : 'text-text-secondary hover:text-text-primary hover:bg-white/10 cursor-pointer'
              )}
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>

          {/* Month Popover */}
          {popoverOpen && (
            <motion.div
              initial={prefersReduced ? false : { opacity: 0, y: -6, scale: 0.98 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: -6, scale: 0.98 }}
              transition={prefersReduced ? { duration: 0 } : { duration: 0.15, ease: 'easeOut' }}
              className="absolute left-0 sm:left-auto sm:right-0 top-full mt-2 z-50 w-[260px] max-w-[calc(100vw-32px)] bg-sheet-surface border border-glass-border rounded-2xl p-3 shadow-2xl backdrop-blur-xl"
            >
              <div className="flex items-center justify-between text-[13px] font-bold text-text-primary mb-2.5 px-1">
                <button
                  type="button"
                  aria-label="Año anterior"
                  onClick={() => setPopoverYear((y) => y - 1)}
                  className="w-10 h-10 min-w-[40px] min-h-[40px] flex items-center justify-center rounded-xl text-text-secondary hover:text-text-primary hover:bg-white/10 transition-colors cursor-pointer"
                >
                  <ChevronLeft className="w-4 h-4" />
                </button>
                <span>{popoverYear}</span>
                <button
                  type="button"
                  aria-label="Año siguiente"
                  onClick={() => setPopoverYear((y) => Math.min(currentYear, y + 1))}
                  disabled={popoverYear >= currentYear}
                  className={cn(
                    'w-10 h-10 min-w-[40px] min-h-[40px] flex items-center justify-center rounded-xl transition-colors',
                    popoverYear >= currentYear
                      ? 'opacity-30 cursor-not-allowed pointer-events-none'
                      : 'text-text-secondary hover:text-text-primary hover:bg-white/10 cursor-pointer'
                  )}
                >
                  <ChevronRight className="w-4 h-4" />
                </button>
              </div>

              <div className="grid grid-cols-3 gap-1.5">
                {MONTH_ABBRS.map((abbr, idx) => {
                  const mNum = idx + 1;
                  const isFuture =
                    popoverYear > currentYear ||
                    (popoverYear === currentYear && mNum > currentMonth);
                  const isSelected =
                    popoverYear === selectedYear && mNum === selectedMonth;
                  const mKey = `${popoverYear}-${String(mNum).padStart(2, '0')}`;
                  const hasMovements = activeMonths.has(mKey);

                  return (
                    <button
                      key={abbr}
                      type="button"
                      disabled={isFuture}
                      onClick={() => navigateToMonth(popoverYear, mNum)}
                      className={cn(
                        'text-[12.5px] min-h-[40px] py-2 rounded-xl transition-all font-medium text-center flex items-center justify-center',
                        isSelected
                          ? 'bg-gradient-to-br from-[#FF8A3D] to-[#FF3D7F] text-white font-bold shadow-sm'
                          : isFuture
                          ? 'opacity-25 cursor-not-allowed text-text-tertiary'
                          : hasMovements
                          ? 'text-text-primary hover:bg-white/10 font-semibold cursor-pointer'
                          : 'text-text-secondary/60 hover:text-text-primary hover:bg-white/5 cursor-pointer'
                      )}
                    >
                      {abbr}
                    </button>
                  );
                })}
              </div>
            </motion.div>
          )}
        </div>
      </div>

      <motion.div
        key={selectedMonthKey}
        initial={prefersReduced ? false : { x: slideDirection * 10, opacity: 0.85 }}
        animate={{ x: 0, opacity: 1 }}
        transition={
          prefersReduced
            ? { duration: 0 }
            : { type: 'spring', stiffness: 350, damping: 28 }
        }
        className="space-y-6"
      >
        {/* Main KPI Grid */}
      {isLoadingKPIs ? (
        <div data-testid="inicio-kpi-skeleton" className="grid grid-cols-1 md:grid-cols-3 gap-3.5">
          <Skeleton className="h-[120px] rounded-2xl" />
          <Skeleton className="h-[120px] rounded-2xl" />
          <Skeleton className="h-[120px] rounded-2xl" />
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)_minmax(0,1fr)] gap-3.5">
          {/* Main card: Gastado en <mes> */}
          <motion.div
            variants={cardVariants}
            initial={prefersReduced ? false : 'hidden'}
            animate="visible"
            transition={prefersReduced ? { duration: 0 } : { type: 'spring', stiffness: 280, damping: 24 }}
            className="rounded-2xl p-5 border border-[rgba(255,138,61,0.4)] bg-[linear-gradient(160deg,rgba(255,138,61,0.13),rgba(255,61,127,0.05))] shadow-sm backdrop-blur-md"
          >
            <div className="text-[12.5px] font-medium text-text-secondary">
              Gastado en {shortMonth.toLowerCase()}
            </div>
            <div className="text-[32px] sm:text-[34px] font-extrabold tracking-tight text-text-primary mt-1.5 tabular-nums whitespace-nowrap">
              <CountUp value={totalSpent} />
            </div>
            <div className="text-[12px] font-medium text-pos mt-1">
              {comparison.changePct != null ? (
                comparison.changePct < 0 ? (
                  `${Math.abs(comparison.changePct)} % menos que mes anterior a esta altura`
                ) : comparison.changePct > 0 ? (
                  `${comparison.changePct} % más que mes anterior a esta altura`
                ) : (
                  'Lo mismo que mes anterior a esta altura'
                )
              ) : prevMonthTotal > 0 ? (
                `Sin gastos en ${prevMonthName} a esta altura`
              ) : (
                'Primer mes registrado'
              )}
            </div>
          </motion.div>

          {/* Ingresos */}
          <motion.div
            variants={cardVariants}
            initial={prefersReduced ? false : 'hidden'}
            animate="visible"
            transition={prefersReduced ? { duration: 0 } : { type: 'spring', stiffness: 280, damping: 24, delay: 0.05 }}
            className="rounded-2xl p-5 border border-glass-border bg-glass-fill shadow-sm backdrop-blur-md"
          >
            <div className="text-[12.5px] font-medium text-text-secondary">Ingresos</div>
            <div className="text-[28px] sm:text-[30px] font-extrabold tracking-tight text-text-primary mt-1.5 tabular-nums whitespace-nowrap">
              <CountUp value={totalIncome} />
            </div>
            <div className="text-[12px] text-text-tertiary mt-1">
              {incomeCount} {incomeCount === 1 ? 'cobro' : 'cobros'}
            </div>
          </motion.div>

          {/* Ahorrado en metas */}
          <motion.div
            variants={cardVariants}
            initial={prefersReduced ? false : 'hidden'}
            animate="visible"
            transition={prefersReduced ? { duration: 0 } : { type: 'spring', stiffness: 280, damping: 24, delay: 0.1 }}
            className="rounded-2xl p-5 border border-glass-border bg-glass-fill shadow-sm backdrop-blur-md"
          >
            <div className="text-[12.5px] font-medium text-text-secondary">Ahorrado en metas</div>
            <div className="text-[28px] sm:text-[30px] font-extrabold tracking-tight text-text-primary mt-1.5 tabular-nums whitespace-nowrap">
              <CountUp value={totalSaved} />
            </div>
            <div className="text-[12px] text-text-tertiary mt-1">
              {activeGoalsCount} {activeGoalsCount === 1 ? 'meta activa' : 'metas activas'}
            </div>
          </motion.div>
        </div>
      )}

      {/* Middle Row: Por categoría & Entradas y salidas */}
      {isLoadingCharts ? (
        <div data-testid="inicio-charts-skeleton" className="grid grid-cols-1 md:grid-cols-[minmax(0,1fr)_minmax(0,1.7fr)] gap-3.5">
          <Skeleton className="h-[286px] rounded-2xl" />
          <Skeleton className="h-[286px] rounded-2xl" />
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-[minmax(0,1fr)_minmax(0,1.7fr)] gap-3.5">
          {/* Card: Por categoría */}
          <motion.div
            variants={cardVariants}
            initial={prefersReduced ? false : 'hidden'}
            animate="visible"
            transition={prefersReduced ? { duration: 0 } : { type: 'spring', stiffness: 280, damping: 24, delay: 0.15 }}
            className="rounded-2xl p-5 border border-glass-border bg-glass-fill shadow-sm backdrop-blur-md min-h-[286px] flex flex-col justify-between"
          >
            <div className="flex items-center justify-between">
              <span className="font-bold text-[14px] text-text-primary">Por categoría</span>
              <span className="text-[12px] text-text-tertiary">{shortMonth.toLowerCase()}</span>
            </div>

            {/* Semicircle category arc SVG */}
            <div className="my-2 flex justify-center">
              <svg viewBox="0 0 220 120" width="210" height="114" className="block">
                {arcSegments.length === 0 ? (
                  <path
                    d="M 12 110 A 98 98 0 0 1 208 110"
                    fill="none"
                    stroke="#2D3139"
                    strokeWidth="12"
                    strokeLinecap="round"
                  />
                ) : (
                  arcSegments.map((seg, idx) => {
                    // Compute SVG arc segment from percentage
                    let cumulativeBefore = 0;
                    for (let j = 0; j < idx; j++) {
                      cumulativeBefore += arcSegments[j].percentage;
                    }
                    const startAngle = Math.PI - (cumulativeBefore / 100) * Math.PI;
                    const endAngle = Math.PI - ((cumulativeBefore + seg.percentage) / 100) * Math.PI;

                    const cx = 110;
                    const cy = 110;
                    const r = 98;

                    const x1 = cx + r * Math.cos(startAngle);
                    const y1 = cy - r * Math.sin(startAngle);
                    const x2 = cx + r * Math.cos(endAngle);
                    const y2 = cy - r * Math.sin(endAngle);

                    const color = parseHexColor(seg.colorDark);
                    const isFirst = idx === 0;
                    const isLast = idx === arcSegments.length - 1;

                    return (
                      <path
                        key={seg.id}
                        d={`M ${x1.toFixed(1)} ${y1.toFixed(1)} A ${r} ${r} 0 0 1 ${x2.toFixed(1)} ${y2.toFixed(1)}`}
                        fill="none"
                        stroke={color}
                        strokeWidth="12"
                        strokeLinecap={isFirst || isLast ? 'round' : 'butt'}
                      />
                    );
                  })
                )}
              </svg>
            </div>

            {/* Arc legend */}
            <div className="text-[12.5px] grid grid-cols-2 gap-x-4 gap-y-2 mt-2">
              {arcSegments.slice(0, 4).map((seg) => (
                <div key={seg.id} className="flex items-center justify-between">
                  <span className="flex items-center gap-1.5 truncate text-text-secondary">
                    <span
                      className="w-2.5 h-2.5 rounded-full shrink-0"
                      style={{ background: parseHexColor(seg.colorDark) }}
                    />
                    <span className="truncate">{seg.name}</span>
                  </span>
                  <span className="text-text-tertiary tabular-nums ml-1.5">{seg.percentage} %</span>
                </div>
              ))}
            </div>
          </motion.div>

          {/* Card: Entradas y salidas (6 months) */}
          <motion.div
            variants={cardVariants}
            initial={prefersReduced ? false : 'hidden'}
            animate="visible"
            transition={prefersReduced ? { duration: 0 } : { type: 'spring', stiffness: 280, damping: 24, delay: 0.2 }}
            className="rounded-2xl p-5 border border-glass-border bg-glass-fill shadow-sm backdrop-blur-md min-h-[286px] flex flex-col justify-between"
          >
            <div className="flex items-center justify-between">
              <span className="font-bold text-[14px] text-text-primary">Entradas y salidas</span>
              <div className="flex items-center gap-3.5 text-[12px] text-text-tertiary">
                <span className="flex items-center gap-1.5">
                  <span className="w-2.5 h-2.5 rounded-full bg-positive" />
                  Entradas
                </span>
                <span className="flex items-center gap-1.5">
                  <span className="w-2.5 h-2.5 rounded-full bg-brand-start" />
                  Salidas
                </span>
              </div>
            </div>

            {/* 6 months bar chart SVG */}
            <div className="mt-2 w-full">
              <svg viewBox="0 0 640 210" width="100%" height="200" className="overflow-visible">
                {(() => {
                  const maxVal = Math.max(
                    1,
                    ...sixMonthsData.map((m) => Math.max(m.income, m.expense))
                  );
                  const chartH = 140;

                  return sixMonthsData.map((m, idx) => {
                    const x = 30 + idx * 100;
                    const inH = Math.max(4, (m.income / maxVal) * chartH);
                    const exH = Math.max(4, (m.expense / maxVal) * chartH);

                    const inY = 170 - inH;
                    const exY = 170 - exH;

                    return (
                      <g key={m.label}>
                        {/* Income bar */}
                        <rect
                          x={x}
                          y={inY}
                          width={28}
                          height={inH}
                          rx={7}
                          fill="var(--positive)"
                          opacity={0.85}
                        />
                        {/* Expense bar */}
                        <rect
                          x={x + 32}
                          y={exY}
                          width={28}
                          height={exH}
                          rx={7}
                          fill="var(--brand-start)"
                        />
                        {/* Month label */}
                        <text
                          x={x + 30}
                          y={196}
                          textAnchor="middle"
                          fill="currentColor"
                          className="text-text-tertiary"
                          fontSize="11"
                          fontFamily="Inter, system-ui, sans-serif"
                        >
                          {m.label}
                        </text>
                      </g>
                    );
                  });
                })()}
              </svg>
            </div>
          </motion.div>
        </div>
      )}

      {/* Bottom Row: Últimos movimientos & Próximos vencimientos */}
      {isLoadingLists ? (
        <div data-testid="inicio-lists-skeleton" className="grid grid-cols-1 md:grid-cols-[minmax(0,1.7fr)_minmax(0,1fr)] gap-3.5">
          <Skeleton className="h-[220px] rounded-2xl" />
          <Skeleton className="h-[220px] rounded-2xl" />
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-[minmax(0,1.7fr)_minmax(0,1fr)] gap-3.5">
          {/* Últimos movimientos */}
          <motion.div
            variants={cardVariants}
            initial={prefersReduced ? false : 'hidden'}
            animate="visible"
            transition={prefersReduced ? { duration: 0 } : { type: 'spring', stiffness: 280, damping: 24, delay: 0.25 }}
            className="rounded-2xl p-5 border border-glass-border bg-glass-fill shadow-sm backdrop-blur-md"
          >
            <div className="flex items-center justify-between mb-3">
              <span className="font-bold text-[14px] text-text-primary">Últimos movimientos</span>
              <Link
                to="/movimientos"
                className="text-[12.5px] font-semibold text-brand-primary hover:underline"
              >
                Ver todos
              </Link>
            </div>

            {(!recentTxs || recentTxs.length === 0) ? (
              <div className="text-[13px] text-text-tertiary py-8 text-center">
                Sin movimientos recientes
              </div>
            ) : (
              <table className="w-full text-[13px]">
                <tbody>
                  {recentTxs.map((tx) => {
                    const isExpense = tx.type === 'expense';
                    const color = parseHexColor(tx.color_dark);
                    const d = new Date(tx.occurred_at * 1000);
                    const timeStr = `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;

                    return (
                      <tr
                        key={tx.id}
                        onClick={() => setSelectedTx(tx)}
                        className="hover:bg-glass-hover cursor-pointer border-b border-glass-border/40 last:border-0 transition-colors"
                      >
                        <td className="py-2.5 pr-2 w-full max-w-0">
                          <span className="flex items-center gap-2 font-medium text-text-primary min-w-0">
                            <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ background: color }} />
                            <span className="truncate min-w-0 flex-1">{tx.merchant || tx.note || tx.category_name || 'Movimiento'}</span>
                          </span>
                        </td>
                        <td className="py-2.5 px-2 text-text-tertiary hidden sm:table-cell">
                          {tx.category_name ?? 'General'}
                        </td>
                        <td className="py-2.5 px-2 text-text-tertiary whitespace-nowrap shrink-0">
                          {timeStr}
                        </td>
                        <td className="py-2.5 pl-2 text-right tabular-nums font-semibold text-text-primary whitespace-nowrap shrink-0">
                          {isExpense ? `−${formatGs(tx.amount)}` : `+${formatGs(tx.amount)}`}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            )}
          </motion.div>

          {/* Próximos vencimientos */}
          <motion.div
            variants={cardVariants}
            initial={prefersReduced ? false : 'hidden'}
            animate="visible"
            transition={prefersReduced ? { duration: 0 } : { type: 'spring', stiffness: 280, damping: 24, delay: 0.3 }}
            className="rounded-2xl p-5 border border-glass-border bg-glass-fill shadow-sm backdrop-blur-md"
          >
            <div className="font-bold text-[14px] text-text-primary mb-3">
              Próximos vencimientos
            </div>

            {upcomingList.length === 0 ? (
              <div className="text-[13px] text-text-tertiary py-8 text-center">
                Sin vencimientos en los próximos 30 días
              </div>
            ) : (
              <div className="space-y-3">
                {upcomingList.map((item) => (
                  <div key={item.id} className="flex items-center justify-between text-[13px] gap-2">
                    <span className="text-text-primary truncate min-w-0 flex-1">{item.title}</span>
                    <div className="flex items-center gap-2.5 shrink-0 tabular-nums">
                      <span className="font-semibold text-text-primary whitespace-nowrap shrink-0">{formatGs(item.amount)}</span>
                      <span className="text-text-tertiary text-[12px] font-medium whitespace-nowrap shrink-0">{item.dateStr}</span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </motion.div>
        </div>
      )}
      </motion.div>

      {/* MovementPanel for editing selected transaction */}
      <MovementPanel
        isOpen={selectedTx != null}
        movement={
          selectedTx
            ? {
                id: selectedTx.id,
                type: selectedTx.type as 'expense' | 'income' | 'transfer',
                amount: selectedTx.amount,
                category_id: selectedTx.category_id,
                merchant: selectedTx.merchant,
                note: selectedTx.note,
                occurred_at: selectedTx.occurred_at,
              }
            : null
        }
        db={db}
        categories={(allCategories ?? []).map((c) => ({
          id: c.id,
          name: c.name,
          kind: 'expense',
          sort_order: 0,
          icon: c.icon,
          color_dark: c.color_dark,
          color_light: c.color_light,
        }))}
        onClose={() => setSelectedTx(null)}
        onSaved={() => setSelectedTx(null)}
        onDeleted={() => setSelectedTx(null)}
      />
    </div>
  );
}
