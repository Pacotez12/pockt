import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import React from 'react';
import { MovimientosRoute } from './movimientos';
import * as powersyncReact from '@powersync/react';

vi.mock('@powersync/react', () => ({
  useQuery: vi.fn(),
  usePowerSync: vi.fn(),
  useStatus: vi.fn(),
}));

describe('MovimientosRoute', () => {
  it('renders skeleton while loading', () => {
    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [],
      isLoading: true,
      error: undefined,
    } as any);

    render(<MovimientosRoute />);

    expect(screen.getByTestId('movimientos-skeleton')).toBeInTheDocument();
    expect(screen.queryByRole('table')).not.toBeInTheDocument();
  });

  it('renders read-only table with movements, category dots, and signed amounts', () => {
    const occurredAt = Math.floor(new Date(2026, 9, 28, 14, 0).getTime() / 1000);

    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [
        {
          id: 'tx-1',
          type: 'expense',
          amount: 184000,
          merchant: 'Supermercado Los Jardines',
          note: null,
          occurred_at: occurredAt,
          category_name: 'Comida',
          category_color_dark: 0xffe4a067,
          category_color_light: 0xffe4a067,
        },
        {
          id: 'tx-2',
          type: 'income',
          amount: 2500000,
          merchant: null,
          note: 'Cobro de honorarios',
          occurred_at: occurredAt,
          category_name: 'Ingresos',
          category_color_dark: 0xff4ad496,
          category_color_light: 0xff008856,
        },
      ],
      isLoading: false,
      error: undefined,
    } as any);

    render(<MovimientosRoute />);

    expect(screen.getByText('Movimientos')).toBeInTheDocument();
    expect(screen.getByText('Supermercado Los Jardines')).toBeInTheDocument();
    expect(screen.getByText('Comida')).toBeInTheDocument();
    expect(screen.getByText('−Gs. 184.000')).toBeInTheDocument();

    expect(screen.getByText('Cobro de honorarios')).toBeInTheDocument();
    expect(screen.getByText('Ingresos')).toBeInTheDocument();
    expect(screen.getByText('+Gs. 2.500.000')).toBeInTheDocument();

    expect(document.title).toBe('Movimientos · Pockt');
  });

  it('shows empty state when no transactions exist', () => {
    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [],
      isLoading: false,
      error: undefined,
    } as any);

    render(<MovimientosRoute />);

    expect(screen.getByText('No hay movimientos registrados')).toBeInTheDocument();
  });
});
