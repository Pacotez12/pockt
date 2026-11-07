import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import React from 'react';
import { MovementsTable } from './MovementsTable';

describe('MovementsTable', () => {
  const occurredOct28 = Math.floor(new Date(2026, 9, 28, 14, 0).getTime() / 1000);
  const occurredOct27 = Math.floor(new Date(2026, 9, 27, 10, 0).getTime() / 1000);

  const mockMovements = [
    {
      id: 'tx-1',
      type: 'expense',
      amount: 184000,
      merchant: 'Supermercado Los Jardines',
      note: 'Semanal',
      occurred_at: occurredOct28,
      category_name: 'Comida',
      category_color_dark: 0xffe4a067,
      category_color_light: 0xffe4a067,
      source: 'manual',
      loan_id: null,
    },
    {
      id: 'tx-2',
      type: 'income',
      amount: 3000000,
      merchant: null,
      note: 'Sueldo quincena',
      occurred_at: occurredOct27,
      category_name: 'Sueldo',
      category_color_dark: 0xff4ad496,
      category_color_light: 0xff008856,
      source: 'recurring',
      loan_id: null,
    },
    {
      id: 'tx-loan',
      type: 'expense',
      amount: 450000,
      merchant: 'Banco Atlas',
      note: 'Cuota préstamo moto',
      occurred_at: occurredOct27,
      category_name: 'Préstamos',
      source: 'manual',
      loan_id: 'loan-xyz',
    },
  ];

  it('renders movements grouped by date with day totals', () => {
    const onSelect = vi.fn();
    render(
      <MovementsTable
        movements={mockMovements as any}
        isLoading={false}
        onSelectMovement={onSelect}
      />
    );

    // Movements exist
    expect(screen.getByText('Supermercado Los Jardines')).toBeInTheDocument();
    expect(screen.getByText('−Gs. 184.000')).toBeInTheDocument();
    expect(screen.getByText('Sueldo quincena')).toBeInTheDocument();
    expect(screen.getByText('+Gs. 3.000.000')).toBeInTheDocument();

    // Loan badge
    expect(screen.getByText('Préstamo')).toBeInTheDocument();
  });

  it('calls onSelectMovement when clicking a row or pressing Enter on it', () => {
    const onSelect = vi.fn();
    render(
      <MovementsTable
        movements={mockMovements as any}
        isLoading={false}
        onSelectMovement={onSelect}
      />
    );

    const firstRow = screen.getByText('Supermercado Los Jardines').closest('tr');
    expect(firstRow).toBeInTheDocument();

    fireEvent.click(firstRow!);
    expect(onSelect).toHaveBeenCalledWith(mockMovements[0]);

    fireEvent.keyDown(firstRow!, { key: 'Enter' });
    expect(onSelect).toHaveBeenCalledTimes(2);
  });

  it('shows empty state when movements list is empty', () => {
    render(
      <MovementsTable
        movements={[]}
        isLoading={false}
        onSelectMovement={vi.fn()}
      />
    );

    expect(screen.getByText(/no hay movimientos/i)).toBeInTheDocument();
  });

  it('renders mobile flex row layout and hides thead on mobile', () => {
    render(
      <MovementsTable
        movements={mockMovements as any}
        isLoading={false}
        onSelectMovement={vi.fn()}
      />
    );

    const thead = document.querySelector('thead');
    expect(thead).toHaveClass('hidden', 'sm:table-header-group');

    const firstRow = screen.getByText('Supermercado Los Jardines').closest('tr');
    expect(firstRow).toHaveClass('flex', 'items-center', 'justify-between');

    const descCell = screen.getByText('Supermercado Los Jardines').closest('td');
    expect(descCell).toHaveClass('flex-1', 'min-w-0');

    const amountCell = firstRow?.querySelector('td:last-child');
    expect(amountCell).toHaveClass('shrink-0', 'text-right');
  });
});
