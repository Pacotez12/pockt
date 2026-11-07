import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
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
});
