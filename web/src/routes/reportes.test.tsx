import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react';
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

  it('renders negative net savings subtitle when spending exceeds income', async () => {
    const deficitTxs = [
      {
        id: 'tx-1',
        type: 'expense',
        amount: 5000000,
        occurred_at: Math.floor(Date.now() / 1000) - 3600,
        merchant: 'Alquiler',
        category_id: 'cat-1',
        category_name: 'Vivienda',
      },
      {
        id: 'tx-2',
        type: 'income',
        amount: 2000000,
        occurred_at: Math.floor(Date.now() / 1000) - 7200,
        merchant: 'Sueldo',
        category_id: 'cat-2',
        category_name: 'Ingresos',
      },
    ];

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('transactions')) {
        return { data: deficitTxs, isLoading: false, error: undefined } as any;
      }
      return { data: [], isLoading: false, error: undefined } as any;
    });

    render(
      <MemoryRouter initialEntries={['/reportes']}>
        <ReportesRoute />
      </MemoryRouter>
    );

    await waitFor(() => {
      expect(screen.getByText(/Gastaste Gs\..*más de lo que entró/i)).toBeInTheDocument();
    });
  });

  it('displays the total sum across all days shown in TusDias rather than just the single month', async () => {
    // Current month expense: 1.000.000 Gs (today)
    // Past month expense (within 60 days): 3.000.000 Gs
    // Single month total should be 1.000.000, but TusDias 6-month total should be 4.000.000 Gs
    const multiMonthTxs = [
      {
        id: 'tx-current',
        type: 'expense',
        amount: 1000000,
        occurred_at: Math.floor(Date.now() / 1000) - 3600,
        merchant: 'Supermercado',
        category_id: 'cat-1',
        category_name: 'Comida',
      },
      {
        id: 'tx-past',
        type: 'expense',
        amount: 3000000,
        occurred_at: Math.floor(Date.now() / 1000) - 45 * 86400,
        merchant: 'Alquiler Mes Anterior',
        category_id: 'cat-2',
        category_name: 'Vivienda',
      },
    ];

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('transactions')) {
        return { data: multiMonthTxs, isLoading: false, error: undefined } as any;
      }
      return { data: [], isLoading: false, error: undefined } as any;
    });

    render(
      <MemoryRouter initialEntries={['/reportes']}>
        <ReportesRoute />
      </MemoryRouter>
    );

    // TusDias header has dynamic title "Gastado desde el ..." and total 4.000.000
    await waitFor(() => {
      expect(screen.getByText(/Gastado desde el/i)).toBeInTheDocument();
      // Should find Gs. 4.000.000 in TusDias container
      const container = screen.getByTestId('tus-dias-container');
      expect(container).toHaveTextContent(/4\.000\.000/);
    });
  });

  it('tapping a day with 3 movements opens DayDetailPanel listing all 3, and tapping a row opens MovementPanel', async () => {
    const today = new Date();
    const todayStartSec = Math.floor(new Date(today.getFullYear(), today.getMonth(), today.getDate(), 0, 0, 0).getTime() / 1000);

    const threeDayTxs = [
      {
        id: 'tx-day-1',
        type: 'expense',
        amount: 85000,
        occurred_at: todayStartSec + 3600 * 9,
        merchant: 'Biggie Express',
        note: 'Desayuno',
        category_id: 'cat-1',
        category_name: 'Comida',
        color_dark: '#E4A067',
      },
      {
        id: 'tx-day-2',
        type: 'expense',
        amount: 45000,
        occurred_at: todayStartSec + 3600 * 13,
        merchant: 'Café Martínez',
        note: 'Café con amigos',
        category_id: 'cat-1',
        category_name: 'Comida',
        color_dark: '#E4A067',
      },
      {
        id: 'tx-day-3',
        type: 'income',
        amount: 1500000,
        occurred_at: todayStartSec + 3600 * 17,
        merchant: 'Cliente freelance',
        note: 'Diseño web',
        category_id: 'cat-3',
        category_name: 'Ingresos',
        color_dark: '#30D158',
      },
    ];

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('transactions')) {
        return { data: threeDayTxs, isLoading: false, error: undefined } as any;
      }
      return { data: [], isLoading: false, error: undefined } as any;
    });

    render(
      <MemoryRouter initialEntries={['/reportes']}>
        <ReportesRoute />
      </MemoryRouter>
    );

    const y = today.getFullYear();
    const m = String(today.getMonth() + 1).padStart(2, '0');
    const d = String(today.getDate()).padStart(2, '0');
    const dateKey = `${y}-${m}-${d}`;

    // Get the day cell in TusDias matching today's date
    const todayCell = document.querySelector(`[data-date="${dateKey}"]`);
    expect(todayCell).toBeInTheDocument();

    fireEvent.click(todayCell!);

    // DayDetailPanel should open and list all 3 movements
    await waitFor(() => {
      const panel = screen.getByRole('dialog');
      expect(within(panel).getByText('Biggie Express')).toBeInTheDocument();
      expect(within(panel).getByText('Café Martínez')).toBeInTheDocument();
      expect(within(panel).getByText('Cliente freelance')).toBeInTheDocument();
    });

    // Check link to Movimientos with desde and hasta
    const panel = screen.getByRole('dialog');
    const link = within(panel).getByRole('link', { name: /Ver en Movimientos/i });
    expect(link).toHaveAttribute('href', `/movimientos?desde=${dateKey}&hasta=${dateKey}`);

    // Tapping a row opens MovementPanel with "Editar movimiento"
    fireEvent.click(within(panel).getByText('Biggie Express'));

    await waitFor(() => {
      expect(screen.getByText('Editar movimiento')).toBeInTheDocument();
    });
  });

  it('triggers PDF download with name pockt-resumen-<periodo>.pdf when clicking Resumen · PDF', async () => {
    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('transactions')) {
        return { data: sampleTxs, isLoading: false, error: undefined } as any;
      }
      return { data: [], isLoading: false, error: undefined } as any;
    });

    const createObjectURLMock = vi.fn().mockReturnValue('blob:test-pdf');
    const revokeObjectURLMock = vi.fn();
    window.URL.createObjectURL = createObjectURLMock;
    window.URL.revokeObjectURL = revokeObjectURLMock;

    let clickedFilename = '';
    const clickSpy = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (this: HTMLAnchorElement) {
      clickedFilename = this.download;
    });

    render(
      <MemoryRouter initialEntries={['/reportes']}>
        <ReportesRoute />
      </MemoryRouter>
    );

    const pdfBtn = screen.getByRole('button', { name: /Resumen · PDF/i });
    fireEvent.click(pdfBtn);

    await waitFor(() => {
      expect(clickSpy).toHaveBeenCalled();
    });

    expect(clickedFilename).toMatch(/^pockt-resumen-.*\.pdf$/);
    clickSpy.mockRestore();
  });
});
