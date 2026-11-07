import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import React from 'react';
import { MemoryRouter } from 'react-router-dom';
import { DayDetailPanel, DayDetailTransaction } from './DayDetailPanel';

describe('DayDetailPanel', () => {
  const mockTransactions: DayDetailTransaction[] = [
    {
      id: 'tx-1',
      type: 'expense',
      amount: 184000,
      merchant: 'Superseis',
      note: 'Compras de la semana',
      occurred_at: Math.floor(new Date(2026, 10, 6, 11, 30).getTime() / 1000),
      category_name: 'Comida',
      category_color_dark: 0xffe4a067,
      category_color_light: 0xffc9844d,
    },
    {
      id: 'tx-2',
      type: 'income',
      amount: 3500000,
      merchant: 'Empresa',
      note: '1ª quincena',
      occurred_at: Math.floor(new Date(2026, 10, 6, 8, 30).getTime() / 1000),
      category_name: 'Sueldo',
      category_color_dark: 0xff4ad496,
      category_color_light: 0xff008856,
    },
    {
      id: 'tx-3',
      type: 'expense',
      amount: 450000,
      merchant: 'Banco Atlas',
      note: 'Cuota préstamo moto',
      occurred_at: Math.floor(new Date(2026, 10, 6, 16, 45).getTime() / 1000),
      category_name: 'Préstamos',
      loan_id: 'loan-xyz',
    },
  ];

  it('renders date header, subtotals, and lists all 3 movements', () => {
    const onSelect = vi.fn();
    const onClose = vi.fn();

    render(
      <MemoryRouter>
        <DayDetailPanel
          isOpen={true}
          dateKey="2026-11-06"
          transactions={mockTransactions}
          onClose={onClose}
          onSelectTransaction={onSelect}
        />
      </MemoryRouter>
    );

    // Date header
    expect(screen.getByText(/6 de noviembre/i)).toBeInTheDocument();

    // Subtotals
    expect(screen.getByText(/Salieron:/i)).toBeInTheDocument();
    expect(screen.getByText(/Entraron:/i)).toBeInTheDocument();

    // All 3 movements
    expect(screen.getByText('Superseis')).toBeInTheDocument();
    expect(screen.getByText('Empresa')).toBeInTheDocument();
    expect(screen.getByText('Banco Atlas')).toBeInTheDocument();

    // Loan badge on loan item
    expect(screen.getByText('Préstamo')).toBeInTheDocument();

    // "Ver en Movimientos" link with desde and hasta
    const link = screen.getByRole('link', { name: /Ver en Movimientos/i });
    expect(link).toHaveAttribute('href', '/movimientos?desde=2026-11-06&hasta=2026-11-06');
  });

  it('calls onSelectTransaction when clicking a row', () => {
    const onSelect = vi.fn();
    const onClose = vi.fn();

    render(
      <MemoryRouter>
        <DayDetailPanel
          isOpen={true}
          dateKey="2026-11-06"
          transactions={mockTransactions}
          onClose={onClose}
          onSelectTransaction={onSelect}
        />
      </MemoryRouter>
    );

    fireEvent.click(screen.getByText('Superseis').closest('div[role="button"]') || screen.getByText('Superseis'));
    expect(onSelect).toHaveBeenCalledWith(mockTransactions[0]);
  });

  it('shows empty state "Sin movimientos este día" when transactions list is empty', () => {
    render(
      <MemoryRouter>
        <DayDetailPanel
          isOpen={true}
          dateKey="2026-11-06"
          transactions={[]}
          onClose={vi.fn()}
          onSelectTransaction={vi.fn()}
        />
      </MemoryRouter>
    );

    expect(screen.getByText('Sin movimientos este día')).toBeInTheDocument();
  });

  it('calls onClose when pressing Escape or clicking backdrop', () => {
    const onClose = vi.fn();

    render(
      <MemoryRouter>
        <DayDetailPanel
          isOpen={true}
          dateKey="2026-11-06"
          transactions={mockTransactions}
          onClose={onClose}
          onSelectTransaction={vi.fn()}
        />
      </MemoryRouter>
    );

    fireEvent.keyDown(window, { key: 'Escape' });
    expect(onClose).toHaveBeenCalledTimes(1);

    const backdrop = screen.getByTestId('day-detail-backdrop');
    fireEvent.click(backdrop);
    expect(onClose).toHaveBeenCalledTimes(2);
  });
});
