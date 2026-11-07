import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import React from 'react';
import { MovimientosRoute } from './movimientos';
import * as powersyncReact from '@powersync/react';
import * as writeOps from '@/lib/movements/write';
import * as exportOps from '@/lib/movements/export';
import { MemoryRouter } from 'react-router-dom';

vi.mock('@powersync/react', () => ({
  useQuery: vi.fn(),
  usePowerSync: vi.fn(),
  useStatus: vi.fn(),
}));

vi.mock('@/lib/movements/write', () => ({
  createMovement: vi.fn(),
  updateMovement: vi.fn(),
  softDeleteMovement: vi.fn(),
  restoreMovement: vi.fn(),
}));

vi.mock('@/lib/movements/export', async () => {
  const actual = await vi.importActual<any>('@/lib/movements/export');
  return {
    ...actual,
    toCsv: vi.fn(() => '\uFEFFFecha;Tipo;Monto;Categoría;Nota;Comercio\n'),
    toXlsx: vi.fn(async () => new Uint8Array([1, 2, 3])),
    downloadBlob: vi.fn(),
    getExportFilename: vi.fn((ext) => `pockt-movimientos-test.${ext}`),
  };
});

describe('MovimientosRoute', () => {
  const mockDb = {
    execute: vi.fn(),
    getAll: vi.fn(),
    getOptional: vi.fn(),
  };

  const mockCategories = [
    { id: 'cat-1', name: 'Comida', kind: 'expense', sort_order: 1, color_dark: 0xffe4a067, color_light: 0xffe4a067 },
  ];

  const occurredAt = Math.floor(new Date(2026, 9, 28, 14, 0).getTime() / 1000);

  const mockMovements = [
    {
      id: 'tx-1',
      type: 'expense',
      amount: 184000,
      merchant: 'Supermercado Los Jardines',
      note: 'Semanal',
      occurred_at: occurredAt,
      category_id: 'cat-1',
      category_name: 'Comida',
      category_color_dark: 0xffe4a067,
      category_color_light: 0xffe4a067,
      source: 'manual',
      loan_id: null,
    },
    {
      id: 'tx-2',
      type: 'income',
      amount: 2500000,
      merchant: null,
      note: 'Cobro de honorarios',
      occurred_at: occurredAt,
      category_id: 'cat-1',
      category_name: 'Ingresos',
      category_color_dark: 0xff4ad496,
      category_color_light: 0xff008856,
      source: 'manual',
      loan_id: null,
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(powersyncReact.usePowerSync).mockReturnValue(mockDb as any);
    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (typeof sql === 'string' && sql.includes('FROM transactions')) {
        return { data: mockMovements, isLoading: false } as any;
      }
      return { data: mockCategories, isLoading: false } as any;
    });
  });

  const renderComponent = (initialEntries = ['/movimientos']) => {
    return render(
      <MemoryRouter initialEntries={initialEntries}>
        <MovimientosRoute />
      </MemoryRouter>
    );
  };

  it('renders skeleton while loading', () => {
    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (typeof sql === 'string' && sql.includes('FROM transactions')) {
        return { data: [], isLoading: true } as any;
      }
      return { data: mockCategories, isLoading: false } as any;
    });

    renderComponent();

    expect(screen.getByTestId('movimientos-skeleton')).toBeInTheDocument();
  });

  it('renders summary with CountUp and list of movements', () => {
    renderComponent();

    expect(screen.getByText('Movimientos')).toBeInTheDocument();
    expect(screen.getByText(/2 movimientos/i)).toBeInTheDocument();
    expect(screen.getByText(/salieron Gs\./i)).toBeInTheDocument();
    expect(screen.getByText(/entraron Gs\./i)).toBeInTheDocument();

    expect(screen.getByText('Supermercado Los Jardines')).toBeInTheDocument();
    expect(screen.getByText('−Gs. 184.000')).toBeInTheDocument();
    expect(screen.getByText('Cobro de honorarios')).toBeInTheDocument();
    expect(screen.getByText('+Gs. 2.500.000')).toBeInTheDocument();
    expect(document.title).toBe('Movimientos · Pockt');
  });

  it('opens create panel when pressing keyboard shortcut "n"', () => {
    renderComponent();

    expect(screen.queryByText('Cargar movimiento')).not.toBeInTheDocument();

    fireEvent.keyDown(window, { key: 'n' });

    expect(screen.getByText('Cargar movimiento')).toBeInTheDocument();
  });

  it('opens edit panel when clicking a movement row', () => {
    renderComponent();

    const row = screen.getByText('Supermercado Los Jardines').closest('tr');
    fireEvent.click(row!);

    expect(screen.getByText('Editar movimiento')).toBeInTheDocument();
    expect(screen.getByDisplayValue('Supermercado Los Jardines')).toBeInTheDocument();
  });

  it('shows undo notification after deleting and restores on click', async () => {
    vi.mocked(writeOps.softDeleteMovement).mockResolvedValueOnce();
    vi.mocked(writeOps.restoreMovement).mockResolvedValueOnce();

    renderComponent();

    // Click row
    fireEvent.click(screen.getByText('Supermercado Los Jardines').closest('tr')!);

    // Click delete
    fireEvent.click(screen.getByRole('button', { name: /Borrar/i }));
    fireEvent.click(screen.getByRole('button', { name: /Confirmar borrar/i }));

    await waitFor(() => {
      expect(screen.getByText(/Movimiento borrado/i)).toBeInTheDocument();
    });

    const undoBtn = screen.getByRole('button', { name: /Deshacer/i });
    fireEvent.click(undoBtn);

    await waitFor(() => {
      expect(writeOps.restoreMovement).toHaveBeenCalledWith(mockDb, 'tx-1');
    });
  });

  it('triggers CSV and Excel downloads', async () => {
    renderComponent();

    const downloadBtn = screen.getByRole('button', { name: /Descargar/i });
    fireEvent.click(downloadBtn);

    const csvBtn = screen.getByRole('button', { name: /Descargar CSV/i });
    fireEvent.click(csvBtn);

    expect(exportOps.toCsv).toHaveBeenCalled();
    expect(exportOps.downloadBlob).toHaveBeenCalled();
  });
});
