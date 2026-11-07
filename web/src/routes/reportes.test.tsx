import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import * as powersyncReact from '@powersync/react';
import { ReportesRoute } from './reportes';

vi.mock('@powersync/react', () => ({
  useQuery: vi.fn(),
  usePowerSync: vi.fn(),
  useStatus: vi.fn(),
}));

describe('ReportesRoute', () => {
  const mockDb = {
    execute: vi.fn().mockResolvedValue({ rows: [] }),
    getAll: vi.fn().mockResolvedValue([]),
  };

  const sampleTxs = [
    {
      id: 'tx-1',
      type: 'expense',
      amount: 1200000,
      occurred_at: Math.floor(Date.now() / 1000) - 3600,
      merchant: 'Superseis',
      category_id: 'cat-1',
      category_name: 'Supermercado',
      color_dark: '#E4A067',
    },
    {
      id: 'tx-2',
      type: 'expense',
      amount: 450000,
      occurred_at: Math.floor(Date.now() / 1000) - 7200,
      merchant: 'Bolt',
      category_id: 'cat-2',
      category_name: 'Transporte',
      color_dark: '#6BBAF0',
    },
    {
      id: 'tx-3',
      type: 'income',
      amount: 5000000,
      occurred_at: Math.floor(Date.now() / 1000) - 10000,
      merchant: 'Salario',
      category_id: 'cat-3',
      category_name: 'Ingresos',
      color_dark: '#30D158',
    },
  ];

  const sampleRecurring = [
    {
      id: 'rec-1',
      amount: 80000,
      frequency: 'monthly',
      active: 1,
    },
    {
      id: 'rec-2',
      amount: 55000,
      frequency: 'monthly',
      active: 1,
    },
  ];

  beforeEach(() => {
    vi.restoreAllMocks();
    vi.mocked(powersyncReact.usePowerSync).mockReturnValue(mockDb as any);
    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('transactions')) {
        return { data: sampleTxs, isLoading: false, error: undefined } as any;
      }
      if (sql.includes('recurring_rules')) {
        return { data: sampleRecurring, isLoading: false, error: undefined } as any;
      }
      return { data: [], isLoading: false, error: undefined } as any;
    });

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

  it('renders title, period segmented selector, KPIs, and TusDias section', async () => {
    render(
      <MemoryRouter initialEntries={['/reportes']}>
        <ReportesRoute />
      </MemoryRouter>
    );

    expect(screen.getByRole('heading', { level: 1, name: 'Reportes' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Mes' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Año' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Personalizado' })).toBeInTheDocument();

    // Verify presence of KPIs
    await waitFor(() => {
      expect(screen.getAllByText(/Gastado en/i).length).toBeGreaterThanOrEqual(1);
      expect(screen.getByText(/Ahorro neto/i)).toBeInTheDocument();
      expect(screen.getByText(/Mes más caro/i)).toBeInTheDocument();
      expect(screen.getByText(/Suscripciones al año/i)).toBeInTheDocument();
    });

    // Verify sections
    expect(screen.getByText('Tendencia por categoría')).toBeInTheDocument();
    expect(screen.getByText('Dónde gastás más')).toBeInTheDocument();
    expect(screen.getByText('Tus días')).toBeInTheDocument();
    expect(screen.getByText('Descargas')).toBeInTheDocument();

    // Anti-slop check: NO "Podés gastar hoy"
    expect(screen.queryByText(/Podés gastar hoy/i)).not.toBeInTheDocument();
  });

  it('changes period when clicking segmented control buttons and updates URL', async () => {
    render(
      <MemoryRouter initialEntries={['/reportes?period=mes']}>
        <ReportesRoute />
      </MemoryRouter>
    );

    const btnAno = screen.getByRole('button', { name: 'Año' });
    fireEvent.click(btnAno);
    expect(btnAno).toHaveClass('on');

    const btnCustom = screen.getByRole('button', { name: 'Personalizado' });
    fireEvent.click(btnCustom);
    expect(btnCustom).toHaveClass('on');
  });

  it('shows download buttons for CSV, Excel, and PDF', async () => {
    render(
      <MemoryRouter initialEntries={['/reportes']}>
        <ReportesRoute />
      </MemoryRouter>
    );

    expect(screen.getByRole('button', { name: /Movimientos · CSV/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Movimientos · Excel/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Resumen · PDF/i })).toBeInTheDocument();
  });
});
