import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import React from 'react';
import { MemoryRouter } from 'react-router-dom';
import { MetasRoute } from './metas';
import * as powersyncReact from '@powersync/react';

vi.mock('@powersync/react', () => ({
  useQuery: vi.fn(),
  usePowerSync: vi.fn(),
  useStatus: vi.fn(),
}));

describe('MetasRoute', () => {
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
        <MetasRoute />
      </MemoryRouter>
    );

    expect(screen.getByTestId('metas-skeleton')).toBeInTheDocument();
  });

  it('renders title, app notice, and sets document.title', () => {
    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [],
      isLoading: false,
      error: undefined,
    } as any);

    render(
      <MemoryRouter>
        <MetasRoute />
      </MemoryRouter>
    );

    expect(document.title).toBe('Metas · Pockt');
    expect(screen.getByRole('heading', { level: 1, name: 'Metas' })).toBeInTheDocument();
    expect(screen.getByText(/Para editar, usá la app/i)).toBeInTheDocument();
  });

  it('renders active goals with saved total, progress bar, pace, and recent contributions', () => {
    const mockGoals = [
      {
        id: 'goal-1',
        name: 'Ahorro general',
        icon: 'piggy-bank',
        target_amount: 10000000,
        target_date: null,
        created_at: Math.floor(new Date('2026-01-01').getTime() / 1000),
        archived: 0,
      },
      {
        id: 'goal-2',
        name: 'Viaje vacaciones',
        icon: 'airplane',
        target_amount: 3000000,
        target_date: Math.floor(new Date('2026-12-31').getTime() / 1000),
        created_at: Math.floor(new Date('2026-01-01').getTime() / 1000),
        archived: 0,
      },
    ];

    const mockContributions = [
      { id: 'c-1', goal_id: 'goal-1', amount: 1650000, date: Math.floor(new Date('2026-10-15').getTime() / 1000), note: 'Ahorro mes' },
      { id: 'c-2', goal_id: 'goal-2', amount: 500000, date: Math.floor(new Date('2026-10-20').getTime() / 1000), note: 'Reserva pasaje' },
    ];

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('FROM goals')) {
        return { data: mockGoals, isLoading: false } as any;
      }
      if (sql.includes('FROM goal_contributions')) {
        return { data: mockContributions, isLoading: false } as any;
      }
      return { data: [], isLoading: false } as any;
    });

    render(
      <MemoryRouter>
        <MetasRoute />
      </MemoryRouter>
    );

    // Total ahorrado: 1.650.000 + 500.000 = 2.150.000
    expect(screen.getByText(/Ahorrado total/i)).toBeInTheDocument();
    expect(screen.getByText(/2\.150\.000/)).toBeInTheDocument();

    // Nombres de metas
    expect(screen.getByText('Ahorro general')).toBeInTheDocument();
    expect(screen.getByText('Viaje vacaciones')).toBeInTheDocument();

    // Montos
    expect(screen.getAllByText(/1\.650\.000/).length).toBeGreaterThan(0);
    expect(screen.getByText(/10\.000\.000/)).toBeInTheDocument();
    expect(screen.getAllByText(/500\.000/).length).toBeGreaterThan(0);
    expect(screen.getByText(/3\.000\.000/)).toBeInTheDocument();

    // Aportes recientes
    expect(screen.getByText(/Ahorro mes/)).toBeInTheDocument();
  });

  it('handles goal without target date and 0 contributions without breaking the screen', () => {
    const mockGoals = [
      {
        id: 'goal-nodate',
        name: 'Fondo de emergencia',
        icon: 'shield',
        target_amount: 5000000,
        target_date: null,
        created_at: Math.floor(new Date('2026-01-01').getTime() / 1000),
        archived: 0,
      },
    ];

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('FROM goals')) {
        return { data: mockGoals, isLoading: false } as any;
      }
      return { data: [], isLoading: false } as any;
    });

    render(
      <MemoryRouter>
        <MetasRoute />
      </MemoryRouter>
    );

    expect(screen.getByText('Fondo de emergencia')).toBeInTheDocument();
    expect(screen.getByText(/sin fecha/i)).toBeInTheDocument();
    expect(screen.getAllByText(/Gs\. 0/).length).toBeGreaterThanOrEqual(1);
  });

  it('renders archived goals folded in collapsible section', () => {
    const mockGoals = [
      {
        id: 'goal-archived',
        name: 'Meta archivada',
        icon: 'check',
        target_amount: 1000000,
        target_date: null,
        created_at: Math.floor(new Date('2025-01-01').getTime() / 1000),
        archived: 1,
      },
    ];

    vi.mocked(powersyncReact.useQuery).mockImplementation((sql: any) => {
      if (sql.includes('FROM goals')) {
        return { data: mockGoals, isLoading: false } as any;
      }
      return { data: [], isLoading: false } as any;
    });

    render(
      <MemoryRouter>
        <MetasRoute />
      </MemoryRouter>
    );

    const toggleBtn = screen.getByRole('button', { name: /archivadas/i });
    expect(toggleBtn).toBeInTheDocument();

    fireEvent.click(toggleBtn);
    expect(screen.getByText('Meta archivada')).toBeInTheDocument();
  });
});
