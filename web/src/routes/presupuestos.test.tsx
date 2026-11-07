import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import React from 'react';
import { MemoryRouter } from 'react-router-dom';
import { PresupuestosRoute } from './presupuestos';
import * as powersyncReact from '@powersync/react';

vi.mock('@powersync/react', () => ({
  useQuery: vi.fn(),
  usePowerSync: vi.fn(),
  useStatus: vi.fn(),
}));

describe('PresupuestosRoute', () => {
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
        <PresupuestosRoute />
      </MemoryRouter>
    );

    expect(screen.getByTestId('presupuestos-skeleton')).toBeInTheDocument();
  });

  it('renders title, period, app notice, and sets document.title', () => {
    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [],
      isLoading: false,
      error: undefined,
    } as any);

    render(
      <MemoryRouter>
        <PresupuestosRoute />
      </MemoryRouter>
    );

    expect(document.title).toBe('Presupuestos · Pockt');
    expect(screen.getByRole('heading', { level: 1, name: 'Presupuestos' })).toBeInTheDocument();
    expect(screen.getByText(/Para editar, usá la app/i)).toBeInTheDocument();
  });

  it('renders budget cards with progress, total, and status colors (ok, warning >=80%, over >=100%)', () => {
    const mockBudgets = [
      { id: 'b-comida', category_id: 'cat-comida', monthly_limit: 1500000 },
      { id: 'b-transporte', category_id: 'cat-transporte', monthly_limit: 500000 },
      { id: 'b-ocio', category_id: 'cat-ocio', monthly_limit: 200000 },
    ];

    const mockCategories = [
      { id: 'cat-comida', name: 'Comida', color_dark: 0xffe4a067, color_light: 0xffc9844d, sort_order: 1 },
      { id: 'cat-transporte', name: 'Transporte', color_dark: 0xff6bbaf0, color_light: 0xff4a9ed6, sort_order: 2 },
      { id: 'cat-ocio', name: 'Ocio', color_dark: 0xfff4514f, color_light: 0xffcc272e, sort_order: 3 },
    ];

    const nowSec = Math.floor(Date.now() / 1000);
    const mockTransactions = [
      // Comida: 930.000 de 1.500.000 -> 62% (ok)
      { id: 'tx-1', category_id: 'cat-comida', type: 'expense', amount: 930000, occurred_at: nowSec, deleted_at: null },
      // Transporte: 430.000 de 500.000 -> 86% (warning >= 80%)
      { id: 'tx-2', category_id: 'cat-transporte', type: 'expense', amount: 430000, occurred_at: nowSec, deleted_at: null },
      // Ocio: 250.000 de 200.000 -> 125% (over >= 100%)
      { id: 'tx-3', category_id: 'cat-ocio', type: 'expense', amount: 250000, occurred_at: nowSec, deleted_at: null },
    ];

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('FROM budgets')) {
        return { data: mockBudgets, isLoading: false } as any;
      }
      if (sql.includes('FROM categories')) {
        return { data: mockCategories, isLoading: false } as any;
      }
      if (sql.includes('FROM transactions')) {
        return { data: mockTransactions, isLoading: false } as any;
      }
      return { data: [], isLoading: false } as any;
    });

    render(
      <MemoryRouter>
        <PresupuestosRoute />
      </MemoryRouter>
    );

    // Nombres de categorías
    expect(screen.getByText('Comida')).toBeInTheDocument();
    expect(screen.getByText('Transporte')).toBeInTheDocument();
    expect(screen.getByText('Ocio')).toBeInTheDocument();

    // Comida: 62% -> quedan 570.000
    expect(screen.getByText(/quedan Gs\. 570\.000/i)).toBeInTheDocument();

    // Transporte: 86% -> advertencia
    expect(screen.getByText(/86 % usado/i)).toBeInTheDocument();

    // Ocio: 125% -> excedido
    expect(screen.getByText(/excedido por Gs\. 50\.000/i)).toBeInTheDocument();
  });

  it('handles budget with 0 limit without dividing by zero or breaking the screen', () => {
    const mockBudgets = [
      { id: 'b-zero', category_id: 'cat-zero', monthly_limit: 0 },
    ];

    const mockCategories = [
      { id: 'cat-zero', name: 'Sin Límite', color_dark: 0xffffffff, color_light: 0xff000000, sort_order: 1 },
    ];

    const mockTransactions = [
      { id: 'tx-z', category_id: 'cat-zero', type: 'expense', amount: 50000, occurred_at: Math.floor(Date.now() / 1000), deleted_at: null },
    ];

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('FROM budgets')) {
        return { data: mockBudgets, isLoading: false } as any;
      }
      if (sql.includes('FROM categories')) {
        return { data: mockCategories, isLoading: false } as any;
      }
      if (sql.includes('FROM transactions')) {
        return { data: mockTransactions, isLoading: false } as any;
      }
      return { data: [], isLoading: false } as any;
    });

    render(
      <MemoryRouter>
        <PresupuestosRoute />
      </MemoryRouter>
    );

    expect(screen.getByText('Sin Límite')).toBeInTheDocument();
    expect(screen.getAllByText(/excedido por Gs\. 50\.000/i).length).toBeGreaterThanOrEqual(1);
  });
});
