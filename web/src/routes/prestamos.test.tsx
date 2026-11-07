import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import React from 'react';
import { MemoryRouter } from 'react-router-dom';
import { PrestamosRoute } from './prestamos';
import * as powersyncReact from '@powersync/react';

vi.mock('@powersync/react', () => ({
  useQuery: vi.fn(),
  usePowerSync: vi.fn(),
  useStatus: vi.fn(),
}));

describe('PrestamosRoute', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
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
      data: undefined,
      isLoading: true,
      error: undefined,
    } as any);

    render(
      <MemoryRouter>
        <PrestamosRoute />
      </MemoryRouter>
    );

    expect(screen.getByTestId('prestamos-skeleton')).toBeInTheDocument();
  });

  it('renders title, app notice, and sets document.title', () => {
    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [],
      isLoading: false,
      error: undefined,
    } as any);

    render(
      <MemoryRouter>
        <PrestamosRoute />
      </MemoryRouter>
    );

    expect(document.title).toBe('Préstamos · Pockt');
    expect(screen.getByRole('heading', { level: 1, name: 'Préstamos' })).toBeInTheDocument();
    expect(screen.getByText(/Para editar, usá la app/i)).toBeInTheDocument();
  });

  it('separates "Debés" vs "Te deben" with totals and loan cards', () => {
    const mockLoans = [
      {
        id: 'loan-1',
        name: 'Préstamo banco',
        direction: 'owe',
        kind: 'installments',
        total_amount: 25000000,
        installment_amount: 805000,
        installments_total: 36,
        due_day: 2,
        start_date: Math.floor(new Date('2026-01-01').getTime() / 1000),
        closed_at: null,
        paid_before_count: 1,
      },
      {
        id: 'loan-2',
        name: 'Préstamo a Lucas',
        direction: 'lent',
        kind: 'loan',
        total_amount: 2000000,
        installment_amount: null,
        installments_total: null,
        due_day: 15,
        start_date: Math.floor(new Date('2026-06-01').getTime() / 1000),
        closed_at: null,
        paid_before_count: 0,
      },
    ];

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('FROM loans')) {
        return { data: mockLoans, isLoading: false } as any;
      }
      if (sql.includes('FROM loan_installments')) {
        return { data: [], isLoading: false } as any;
      }
      if (sql.includes('FROM transactions')) {
        return { data: [], isLoading: false } as any;
      }
      return { data: [], isLoading: false } as any;
    });

    render(
      <MemoryRouter>
        <PrestamosRoute />
      </MemoryRouter>
    );

    // Totales de Debés y Te deben
    expect(screen.getAllByText(/Debés/i).length).toBeGreaterThan(0);
    expect(screen.getAllByText(/Te deben/i).length).toBeGreaterThan(0);

    // Nombres de los préstamos
    expect(screen.getByText('Préstamo banco')).toBeInTheDocument();
    expect(screen.getByText('Préstamo a Lucas')).toBeInTheDocument();
  });

  it('calculates correct next installment for variable schedule with paid installments', () => {
    const mockLoans = [
      {
        id: 'loan-var',
        name: 'Auto cuotas variables',
        direction: 'owe',
        kind: 'installments',
        total_amount: 10000000,
        installment_amount: null,
        installments_total: 3,
        due_day: 10,
        start_date: Math.floor(new Date('2026-01-01').getTime() / 1000),
        closed_at: null,
        paid_before_count: 0,
      },
    ];

    const mockSchedule = [
      { id: 'loan-var:1', loan_id: 'loan-var', number: 1, due_date: Math.floor(new Date('2026-02-10').getTime() / 1000), amount: 5000000 },
      { id: 'loan-var:2', loan_id: 'loan-var', number: 2, due_date: Math.floor(new Date('2026-03-10').getTime() / 1000), amount: 3000000 },
      { id: 'loan-var:3', loan_id: 'loan-var', number: 3, due_date: Math.floor(new Date('2026-04-10').getTime() / 1000), amount: 2000000 },
    ];

    const mockPayments = [
      { id: 'tx-1', loan_id: 'loan-var', type: 'expense', amount: 5000000, occurred_at: Math.floor(new Date('2026-02-10').getTime() / 1000), is_extra: 0, deleted_at: null },
    ];

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('FROM loans')) {
        return { data: mockLoans, isLoading: false } as any;
      }
      if (sql.includes('FROM loan_installments')) {
        return { data: mockSchedule, isLoading: false } as any;
      }
      if (sql.includes('FROM transactions')) {
        return { data: mockPayments, isLoading: false } as any;
      }
      return { data: [], isLoading: false } as any;
    });

    render(
      <MemoryRouter>
        <PrestamosRoute />
      </MemoryRouter>
    );

    // Próxima cuota debe ser 3.000.000 (la cuota 2), NO 10.000.000 (el total)
    expect(screen.getByText(/3\.000\.000/)).toBeInTheDocument();
    // Saldo restante debe ser 5.000.000
    expect(screen.getAllByText(/5\.000\.000/).length).toBeGreaterThanOrEqual(1);
  });

  it('renders closed loans folded in collapsible section', () => {
    const mockLoans = [
      {
        id: 'loan-closed',
        name: 'Préstamo saldado',
        direction: 'owe',
        kind: 'installments',
        total_amount: 5000000,
        installment_amount: 5000000,
        installments_total: 1,
        due_day: 5,
        start_date: Math.floor(new Date('2025-01-01').getTime() / 1000),
        closed_at: Math.floor(new Date('2025-02-05').getTime() / 1000),
        paid_before_count: 1,
      },
    ];

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('FROM loans')) {
        return { data: mockLoans, isLoading: false } as any;
      }
      return { data: [], isLoading: false } as any;
    });

    render(
      <MemoryRouter>
        <PrestamosRoute />
      </MemoryRouter>
    );

    const toggleBtn = screen.getByRole('button', { name: /cerrados/i });
    expect(toggleBtn).toBeInTheDocument();

    // Al abrir el colapsable, aparece el préstamo cerrado
    fireEvent.click(toggleBtn);
    expect(screen.getByText('Préstamo saldado')).toBeInTheDocument();
  });
});
