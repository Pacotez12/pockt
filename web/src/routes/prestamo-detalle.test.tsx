import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import React from 'react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { PrestamoDetalleRoute } from './prestamo-detalle';
import * as powersyncReact from '@powersync/react';

vi.mock('@powersync/react', () => ({
  useQuery: vi.fn(),
  usePowerSync: vi.fn(),
  useStatus: vi.fn(),
}));

describe('PrestamoDetalleRoute', () => {
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

  const mockLoan = {
    id: 'loan-banco',
    name: 'Préstamo banco',
    direction: 'owe',
    kind: 'installments',
    total_amount: 25000000,
    installment_amount: 805000,
    installments_total: 36,
    due_day: 2,
    start_date: Math.floor(new Date('2026-01-01').getTime() / 1000),
    closed_at: null,
    paid_before_count: 0,
  };

  const mockSchedule = [
    { id: 'loan-banco:1', loan_id: 'loan-banco', number: 1, due_date: Math.floor(new Date('2027-01-02').getTime() / 1000), amount: 905000 },
    { id: 'loan-banco:2', loan_id: 'loan-banco', number: 2, due_date: Math.floor(new Date('2027-02-02').getTime() / 1000), amount: 805000 },
    { id: 'loan-banco:3', loan_id: 'loan-banco', number: 3, due_date: Math.floor(new Date('2027-03-02').getTime() / 1000), amount: 705000 },
  ];

  const mockPayments = [
    { id: 'tx-1', loan_id: 'loan-banco', type: 'expense', amount: 905000, occurred_at: Math.floor(new Date('2027-01-02').getTime() / 1000), is_extra: 0, deleted_at: null },
  ];

  it('renders breadcrumbs, title, and sets document.title', () => {
    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('FROM loans WHERE id =')) {
        return { data: [mockLoan], isLoading: false } as any;
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
      <MemoryRouter initialEntries={['/prestamos/loan-banco']}>
        <Routes>
          <Route path="/prestamos/:id" element={<PrestamoDetalleRoute />} />
        </Routes>
      </MemoryRouter>
    );

    expect(document.title).toBe('Préstamo banco · Préstamos · Pockt');
    // Breadcrumbs
    expect(screen.getByRole('link', { name: 'Préstamos' })).toBeInTheDocument();
    expect(screen.getAllByText('Préstamo banco').length).toBeGreaterThan(0);
  });

  it('renders 3 KPIs (Saldo pendiente, Próxima cuota, Fin) and does NOT show Intereses del préstamo', () => {
    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('FROM loans WHERE id =')) {
        return { data: [mockLoan], isLoading: false } as any;
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
      <MemoryRouter initialEntries={['/prestamos/loan-banco']}>
        <Routes>
          <Route path="/prestamos/:id" element={<PrestamoDetalleRoute />} />
        </Routes>
      </MemoryRouter>
    );

    expect(screen.getByText('Saldo pendiente')).toBeInTheDocument();
    expect(screen.getByText('Próxima cuota')).toBeInTheDocument();
    expect(screen.queryByText('Intereses del préstamo')).not.toBeInTheDocument();
    expect(screen.getByText('Fin')).toBeInTheDocument();
  });

  it('renders cronograma table and payments list', () => {
    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('FROM loans WHERE id =')) {
        return { data: [mockLoan], isLoading: false } as any;
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
      <MemoryRouter initialEntries={['/prestamos/loan-banco']}>
        <Routes>
          <Route path="/prestamos/:id" element={<PrestamoDetalleRoute />} />
        </Routes>
      </MemoryRouter>
    );

    expect(screen.getByText('Cronograma')).toBeInTheDocument();
    expect(screen.getByText('Pagada')).toBeInTheDocument();
    expect(screen.getByText('Próxima')).toBeInTheDocument();

    expect(screen.getByText('Pagos registrados')).toBeInTheDocument();
    expect(screen.getByText(/Para editar, usá la app/i)).toBeInTheDocument();
  });

  it('triggers CSV download on "Descargar cronograma"', () => {
    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('FROM loans WHERE id =')) {
        return { data: [mockLoan], isLoading: false } as any;
      }
      if (sql.includes('FROM loan_installments')) {
        return { data: mockSchedule, isLoading: false } as any;
      }
      if (sql.includes('FROM transactions')) {
        return { data: mockPayments, isLoading: false } as any;
      }
      return { data: [], isLoading: false } as any;
    });

    const createObjectURLMock = vi.fn().mockReturnValue('blob:test');
    const revokeObjectURLMock = vi.fn();
    window.URL.createObjectURL = createObjectURLMock;
    window.URL.revokeObjectURL = revokeObjectURLMock;
    const clickSpy = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {});

    render(
      <MemoryRouter initialEntries={['/prestamos/loan-banco']}>
        <Routes>
          <Route path="/prestamos/:id" element={<PrestamoDetalleRoute />} />
        </Routes>
      </MemoryRouter>
    );

    const downloadBtn = screen.getByRole('button', { name: /descargar cronograma/i });
    fireEvent.click(downloadBtn);

    expect(createObjectURLMock).toHaveBeenCalled();
    expect(clickSpy).toHaveBeenCalled();
    clickSpy.mockRestore();
  });

  it('shows not found when loan does not exist', () => {
    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [],
      isLoading: false,
    } as any);

    render(
      <MemoryRouter initialEntries={['/prestamos/non-existent']}>
        <Routes>
          <Route path="/prestamos/:id" element={<PrestamoDetalleRoute />} />
        </Routes>
      </MemoryRouter>
    );

    expect(screen.getByText('Préstamo no encontrado')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /volver a préstamos/i })).toBeInTheDocument();
  });
});
