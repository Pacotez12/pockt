export interface TransactionLike {
  type?: string | null;
  amount?: number | null;
  occurred_at?: number | null;
  deleted_at?: number | null;
}

export function getMonthBounds(year: number, month: number): { start: number; end: number } {
  // month is 1-based (1 = Enero, ..., 10 = Octubre, 12 = Diciembre)
  const start = Math.floor(new Date(year, month - 1, 1, 0, 0, 0, 0).getTime() / 1000);
  const end = Math.floor(new Date(year, month, 1, 0, 0, 0, 0).getTime() / 1000);
  return { start, end };
}

export function calculateMonthExpenses(
  transactions: TransactionLike[],
  year: number,
  month: number
): number {
  const { start, end } = getMonthBounds(year, month);
  let total = 0;

  for (const tx of transactions) {
    if (tx.deleted_at != null) continue;
    if (tx.type !== 'expense') continue;
    if (tx.amount == null || tx.occurred_at == null) continue;

    const occurred = tx.occurred_at > 1e11 ? Math.floor(tx.occurred_at / 1000) : tx.occurred_at;
    if (occurred >= start && occurred < end) {
      total += Math.abs(tx.amount);
    }
  }

  return total;
}

const MONTH_NAMES = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

export function formatMonthYear(date: Date): { monthName: string; year: number; title: string } {
  const monthName = MONTH_NAMES[date.getMonth()];
  const capitalizedMonth = monthName.charAt(0).toUpperCase() + monthName.slice(1);
  const year = date.getFullYear();
  return {
    monthName,
    year,
    title: `${capitalizedMonth} ${year}`,
  };
}
