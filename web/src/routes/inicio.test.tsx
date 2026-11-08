import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent, within } from '@testing-library/react';
import React from 'react';
import { MemoryRouter } from 'react-router-dom';
import { InicioRoute } from './inicio';
import * as powersyncReact from '@powersync/react';

vi.mock('@powersync/react', () => ({
  useQuery: vi.fn(),
  usePowerSync: vi.fn(),
  useStatus: vi.fn(),
}));

describe('InicioRoute', () => {
  const mockDb = {
    execute: vi.fn().mockResolvedValue({ rows: [] }),
    getAll: vi.fn().mockResolvedValue([]),
  };

  beforeEach(() => {
    vi.restoreAllMocks();
    vi.mocked(powersyncReact.usePowerSync).mockReturnValue(mockDb as any);
    window.matchMedia = vi.fn().mockImplementation((query: string) => ({
      matches: query.includes('prefers-reduced-motion: reduce'),
      media: query,
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    }));
  });

  it('shows skeleton while loading', () => {
    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [],
      isLoading: true,
      error: undefined,
    } as any);

    render(
      <MemoryRouter>
        <InicioRoute />
      </MemoryRouter>
    );

    expect(screen.getByTestId('inicio-kpi-skeleton')).toBeInTheDocument();
    expect(screen.getByTestId('inicio-charts-skeleton')).toBeInTheDocument();
    expect(screen.getByTestId('inicio-lists-skeleton')).toBeInTheDocument();
  });

  it('renders all sections according to propuesta web-pantallas without "Podés gastar hoy"', async () => {
    const now = new Date();
    const nowSec = Math.floor(now.getTime() / 1000);

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('settings')) {
        return { data: [{ key: 'period_month_start', value: 'calendar' }], isLoading: false } as any;
      }
      if (sql.includes('income_schedules')) {
        return { data: [], isLoading: false } as any;
      }
      if (sql.includes('LIMIT 5') && sql.includes('transactions')) {
        return {
          data: [
            {
              id: 'tx-1',
              type: 'expense',
              amount: 184000,
              merchant: 'Supermercado',
              category_id: 'c-comida',
              category_name: 'Comida',
              color_dark: 0xffe4a067,
              color_light: 0xffc9844d,
              occurred_at: nowSec,
            },
            {
              id: 'tx-2',
              type: 'expense',
              amount: 28500,
              merchant: 'Bolt',
              category_id: 'c-transp',
              category_name: 'Transporte',
              color_dark: 0xff6bbaf0,
              color_light: 0xff4d9fd7,
              occurred_at: nowSec - 3600,
            },
          ],
          isLoading: false,
        } as any;
      }
      if (sql.includes('transactions') && sql.includes('occurred_at >=')) {
        return {
          data: [
            { id: '1', type: 'expense', amount: 3214500, category_id: 'c-comida', category_name: 'Comida', color_dark: 0xffe4a067, color_light: 0xffc9844d, occurred_at: nowSec },
            { id: '2', type: 'income', amount: 6000000, category_id: 'c-salario', category_name: 'Sueldo', color_dark: 0xff8fb0f8, color_light: 0xff7093e0, occurred_at: nowSec },
          ],
          isLoading: false,
        } as any;
      }
      if (sql.includes('goals')) {
        return {
          data: [
            { id: 'g1', name: 'Meta 1', target_amount: 5000000, archived: 0 },
            { id: 'g2', name: 'Meta 2', target_amount: 3000000, archived: 0 },
          ],
          isLoading: false,
        } as any;
      }
      if (sql.includes('goal_contributions')) {
        return {
          data: [
            { id: 'gc1', goal_id: 'g1', amount: 1500000, date: nowSec },
            { id: 'gc2', goal_id: 'g2', amount: 650000, date: nowSec },
          ],
          isLoading: false,
        } as any;
      }
      if (sql.includes('loans') || sql.includes('loan_installments')) {
        return {
          data: [
            {
              id: 'l1',
              loan_id: 'l1',
              name: 'Préstamo moto',
              installment_number: 2,
              installments_total: 18,
              due_date: nowSec + 86400 * 5,
              amount: 450000,
            },
          ],
          isLoading: false,
        } as any;
      }
      if (sql.includes('recurring_rules')) {
        return {
          data: [
            {
              id: 'r1',
              name: 'Facultad',
              amount: 500000,
              next_due_date: nowSec + 86400 * 10,
              active: 1,
            },
          ],
          isLoading: false,
        } as any;
      }
      if (sql.includes('categories')) {
        return {
          data: [
            { id: 'c-comida', name: 'Comida', color_dark: 0xffe4a067, color_light: 0xffc9844d },
            { id: 'c-transp', name: 'Transporte', color_dark: 0xff6bbaf0, color_light: 0xff4d9fd7 },
          ],
          isLoading: false,
        } as any;
      }

      return { data: [], isLoading: false } as any;
    });

    render(
      <MemoryRouter>
        <InicioRoute />
      </MemoryRouter>
    );

    // Section headers & KPIs
    expect(screen.getByText(/Gastado en/i)).toBeInTheDocument();
    expect(screen.getByText(/Ingresos/i)).toBeInTheDocument();
    expect(screen.getByText(/Ahorrado en metas/i)).toBeInTheDocument();
    expect(screen.getByText(/Por categoría/i)).toBeInTheDocument();
    expect(screen.getByText(/Entradas y salidas/i)).toBeInTheDocument();
    expect(screen.getByText(/Últimos movimientos/i)).toBeInTheDocument();
    expect(screen.getByText(/Próximos vencimientos/i)).toBeInTheDocument();

    // Verify amounts with CountUp
    await waitFor(() => {
      expect(screen.getByText('Gs. 3.214.500')).toBeInTheDocument();
      expect(screen.getByText('Gs. 6.000.000')).toBeInTheDocument();
      expect(screen.getByText('Gs. 2.150.000')).toBeInTheDocument();
    });

    // Verify upcoming dues
    expect(screen.getByText(/Préstamo moto/i)).toBeInTheDocument();
    expect(screen.getByText(/Facultad/i)).toBeInTheDocument();

    // Verify Prohibition: Sin "Podés gastar hoy"
    expect(screen.queryByText(/Podés gastar hoy/i)).not.toBeInTheDocument();
    expect(document.title).toBe('Inicio · Pockt');
  });

  it('opens MovementPanel when clicking on a recent movement', async () => {
    const now = new Date();
    const nowSec = Math.floor(now.getTime() / 1000);

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('LIMIT 5') && sql.includes('transactions')) {
        return {
          data: [
            {
              id: 'tx-1',
              type: 'expense',
              amount: 184000,
              merchant: 'Supermercado',
              category_id: 'c-comida',
              category_name: 'Comida',
              color_dark: 0xffe4a067,
              color_light: 0xffc9844d,
              occurred_at: nowSec,
            },
          ],
          isLoading: false,
        } as any;
      }
      return { data: [], isLoading: false } as any;
    });

    render(
      <MemoryRouter>
        <InicioRoute />
      </MemoryRouter>
    );

    const txItem = await screen.findByText('Supermercado');
    fireEvent.click(txItem);

    // MovementPanel opens with "Editar movimiento"
    await waitFor(() => {
      expect(screen.getByText('Editar movimiento')).toBeInTheDocument();
    });
  });

  it('compares with previous month when data exists instead of saying "Primer mes registrado"', async () => {
    const now = new Date();
    const curYear = now.getFullYear();
    const curMonth = now.getMonth();
    const curDay = now.getDate();
    const nowSec = Math.floor(now.getTime() / 1000);

    const prevMonthDate = new Date(curMonth === 0 ? curYear - 1 : curYear, curMonth === 0 ? 11 : curMonth - 1, Math.min(curDay, 28));
    const prevMonthSec = Math.floor(prevMonthDate.getTime() / 1000);

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('transactions') && sql.includes('occurred_at >=')) {
        return {
          data: [
            { id: '1', type: 'expense', amount: 500000, category_id: 'c-comida', occurred_at: nowSec },
            { id: '2', type: 'expense', amount: 400000, category_id: 'c-comida', occurred_at: prevMonthSec },
          ],
          isLoading: false,
        } as any;
      }
      return { data: [], isLoading: false } as any;
    });

    render(
      <MemoryRouter>
        <InicioRoute />
      </MemoryRouter>
    );

    expect(screen.queryByText(/Primer mes registrado/i)).not.toBeInTheDocument();
    expect(screen.getByText(/mes anterior a esta altura/i)).toBeInTheDocument();
  });

  it('calculates upcoming loan installments using loan_progress (including a loan without physical installments) and shows amount for each item', async () => {
    const now = new Date();
    const nowSec = Math.floor(now.getTime() / 1000);

    const loanDueDay = 25;
    const loanStartDate = new Date(now.getFullYear(), now.getMonth() - 1, 1).toISOString().split('T')[0];

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('FROM loans')) {
        return {
          data: [
            {
              id: 'loan-tienda',
              direction: 'owe',
              kind: 'installments',
              name: 'Tienda Ficticia',
              total_amount: 3600000,
              installment_amount: 200000,
              installments_total: 18,
              due_day: loanDueDay,
              start_date: loanStartDate,
              closed_at: null,
              paid_before_count: 1,
            },
          ],
          isLoading: false,
        } as any;
      }
      if (sql.includes('FROM loan_installments')) {
        return { data: [], isLoading: false } as any;
      }
      if (sql.includes('loan_id IS NOT NULL')) {
        return { data: [], isLoading: false } as any;
      }
      if (sql.includes('recurring_rules')) {
        return {
          data: [
            {
              id: 'rec-1',
              name: 'Netflix',
              amount: 85000,
              next_due_date: nowSec + 86400 * 3,
              active: 1,
            },
          ],
          isLoading: false,
        } as any;
      }
      return { data: [], isLoading: false } as any;
    });

    render(
      <MemoryRouter>
        <InicioRoute />
      </MemoryRouter>
    );

    expect(await screen.findByText(/Tienda Ficticia/i)).toBeInTheDocument();
    expect(screen.getByText(/Netflix/i)).toBeInTheDocument();
    expect(screen.getByText(/200\.000/)).toBeInTheDocument();
    expect(screen.getByText(/85\.000/)).toBeInTheDocument();
  });

  it('renders recent movements amounts with whitespace-nowrap and truncates description', async () => {
    const now = new Date();
    const nowSec = Math.floor(now.getTime() / 1000);

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('transactions') && (sql.includes('LIMIT 5') || sql.includes('occurred_at >='))) {
        return {
          data: [
            {
              id: 'tx-1',
              type: 'expense',
              amount: 424597,
              merchant: 'Superseis Los Laureles Gran Asunción',
              category_id: 'c-comida',
              category_name: 'Comida',
              color_dark: 0xffe4a067,
              occurred_at: nowSec,
            },
          ],
          isLoading: false,
        } as any;
      }
      return { data: [], isLoading: false } as any;
    });

    render(
      <MemoryRouter>
        <InicioRoute />
      </MemoryRouter>
    );

    // Recent movements amount cell should have whitespace-nowrap and shrink-0
    const table = screen.getByRole('table');
    const amountCell = within(table).getByText(/424\.597/);
    expect(amountCell.className).toContain('whitespace-nowrap');
    expect(amountCell.className).toContain('shrink-0');

    // Description text should be truncated
    const descSpan = screen.getByText('Superseis Los Laureles Gran Asunción');
    expect(descSpan.className).toContain('truncate');
  });

  it('?mes=2026-10 muestra octubre y sus totales', async () => {
    const octStartSec = Math.floor(new Date('2026-10-01T00:00:00').getTime() / 1000);
    const octEndSec = Math.floor(new Date('2026-10-31T23:59:59').getTime() / 1000) + 1;

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any, params: any) => {
      if (sql.includes('transactions') && params && params[0] === octStartSec && params[1] === octEndSec) {
        return {
          data: [
            { id: 'oct-1', type: 'expense', amount: 3355000, category_id: 'c-1', category_name: 'Comida', color_dark: 0xffe4a067, occurred_at: octStartSec + 3600 },
            { id: 'oct-2', type: 'income', amount: 5000000, category_id: 'c-2', category_name: 'Sueldo', color_dark: 0xff30d158, occurred_at: octStartSec + 7200 },
          ],
          isLoading: false,
        } as any;
      }
      return { data: [], isLoading: false } as any;
    });

    render(
      <MemoryRouter initialEntries={['/?mes=2026-10']}>
        <InicioRoute />
      </MemoryRouter>
    );

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Octubre 2026');
    expect(screen.getByRole('button', { name: 'Octubre' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Volver a este mes/i })).toBeInTheDocument();

    await waitFor(() => {
      expect(screen.getByText('Gs. 3.355.000')).toBeInTheDocument();
      expect(screen.getByText('Gs. 5.000.000')).toBeInTheDocument();
    });
  });

  it('› deshabilitado en el mes actual', () => {
    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [],
      isLoading: false,
    } as any);

    render(
      <MemoryRouter initialEntries={['/']}>
        <InicioRoute />
      </MemoryRouter>
    );

    const nextBtn = screen.getByRole('button', { name: 'Mes siguiente' });
    expect(nextBtn).toBeDisabled();
  });

  it('la grilla deshabilita los meses futuros', () => {
    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [],
      isLoading: false,
    } as any);

    render(
      <MemoryRouter initialEntries={['/']}>
        <InicioRoute />
      </MemoryRouter>
    );

    const now = new Date();
    const monthNames = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    const currentMonthIdx = now.getMonth();

    const monthBtn = screen.getByRole('button', {
      name: new RegExp(now.toLocaleDateString('es-PY', { month: 'long' }), 'i'),
    });
    fireEvent.click(monthBtn);

    for (let m = currentMonthIdx + 1; m < 12; m++) {
      const futureMonthBtn = screen.getByRole('button', { name: monthNames[m] });
      expect(futureMonthBtn).toBeDisabled();
    }
  });

  it('"Volver a este mes" solo aparece en meses pasados', () => {
    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [],
      isLoading: false,
    } as any);

    const { unmount } = render(
      <MemoryRouter initialEntries={['/']}>
        <InicioRoute />
      </MemoryRouter>
    );

    expect(screen.queryByRole('button', { name: /Volver a este mes/i })).not.toBeInTheDocument();

    unmount();

    render(
      <MemoryRouter initialEntries={['/?mes=2026-10']}>
        <InicioRoute />
      </MemoryRouter>
    );

    expect(screen.getByRole('button', { name: /Volver a este mes/i })).toBeInTheDocument();
  });

  it('clicking "Volver a este mes" resets to current month', () => {
    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [],
      isLoading: false,
    } as any);

    render(
      <MemoryRouter initialEntries={['/?mes=2026-10']}>
        <InicioRoute />
      </MemoryRouter>
    );

    const backBtn = screen.getByRole('button', { name: /Volver a este mes/i });
    fireEvent.click(backBtn);

    const now = new Date();
    const curMonthLong = now.toLocaleDateString('es-PY', { month: 'long' });
    const expectedHeading = `${curMonthLong.charAt(0).toUpperCase() + curMonthLong.slice(1)} ${now.getFullYear()}`;
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(expectedHeading);
    expect(screen.queryByRole('button', { name: /Volver a este mes/i })).not.toBeInTheDocument();
  });

  it('navigates with Mes anterior and keyboard arrows', () => {
    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [],
      isLoading: false,
    } as any);

    render(
      <MemoryRouter initialEntries={['/?mes=2026-10']}>
        <InicioRoute />
      </MemoryRouter>
    );

    // Prev month via button
    const prevBtn = screen.getByRole('button', { name: 'Mes anterior' });
    fireEvent.click(prevBtn);
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Septiembre 2026');

    // Next month via keyboard
    fireEvent.keyDown(window, { key: 'ArrowRight' });
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Octubre 2026');

    // Prev month via keyboard
    fireEvent.keyDown(window, { key: 'ArrowLeft' });
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Septiembre 2026');
  });

  it('popover closes on Escape', () => {
    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [],
      isLoading: false,
    } as any);

    render(
      <MemoryRouter initialEntries={['/']}>
        <InicioRoute />
      </MemoryRouter>
    );

    const now = new Date();
    const curMonthLong = now.toLocaleDateString('es-PY', { month: 'long' });
    const monthBtn = screen.getByRole('button', { name: new RegExp(curMonthLong, 'i') });

    fireEvent.click(monthBtn);
    expect(screen.getByRole('button', { name: 'ene' })).toBeInTheDocument();

    fireEvent.keyDown(window, { key: 'Escape' });
    expect(screen.queryByRole('button', { name: 'ene' })).not.toBeInTheDocument();
  });

  it('al editar un ingreso desde Inicio, el selector de categoría muestra las categorías de ingreso (5b)', async () => {
    const now = new Date();
    const nowSec = Math.floor(now.getTime() / 1000);

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('settings')) {
        return { data: [{ key: 'period_month_start', value: 'calendar' }], isLoading: false } as any;
      }
      if (sql.includes('FROM categories')) {
        return {
          data: [
            { id: 'cat-salario', name: 'Salario', kind: 'income', icon: 'wallet', color_dark: 1, color_light: 1, sort_order: 1 },
            { id: 'cat-comida', name: 'Comida', kind: 'expense', icon: 'food', color_dark: 2, color_light: 2, sort_order: 2 },
          ],
          isLoading: false,
        } as any;
      }
      if (sql.includes('LIMIT 5') && sql.includes('transactions')) {
        return {
          data: [
            {
              id: 'tx-salario-1',
              type: 'income',
              amount: 5000000,
              merchant: 'Empresa',
              category_id: 'cat-salario',
              category_name: 'Salario',
              color_dark: 1,
              color_light: 1,
              occurred_at: nowSec,
            },
          ],
          isLoading: false,
        } as any;
      }
      return { data: [], isLoading: false } as any;
    });

    render(
      <MemoryRouter>
        <InicioRoute />
      </MemoryRouter>
    );

    // Click on the recent transaction
    const row = await screen.findByText('Empresa');
    fireEvent.click(row);

    // MovementPanel should open and show the category select containing "Salario"
    const catSelect = screen.getByLabelText('Categoría');
    expect(within(catSelect).getByRole('option', { name: 'Salario' })).toBeInTheDocument();
  });
});
