import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import React from 'react';
import { InicioRoute } from './inicio';
import * as powersyncReact from '@powersync/react';

vi.mock('@powersync/react', () => ({
  useQuery: vi.fn(),
  usePowerSync: vi.fn(),
  useStatus: vi.fn(),
}));

describe('InicioRoute', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('shows skeleton while loading', () => {
    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [],
      isLoading: true,
      error: undefined,
    } as any);

    render(<InicioRoute />);

    expect(screen.getByTestId('inicio-skeleton')).toBeInTheDocument();
    expect(screen.queryByText(/Gastado en/)).not.toBeInTheDocument();
  });

  it('renders month header and "Gastado en <mes>" sum with formatted amount and no "Podés gastar hoy"', async () => {
    // Enable reduced motion in this test to assert final count directly
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

    const now = new Date();
    const currentMonthTimestamp = Math.floor(now.getTime() / 1000);

    vi.mocked(powersyncReact.useQuery).mockReturnValue({
      data: [
        { id: '1', type: 'expense', amount: 120000, occurred_at: currentMonthTimestamp, deleted_at: null },
        { id: '2', type: 'expense', amount: 80000, occurred_at: currentMonthTimestamp, deleted_at: null },
        { id: '3', type: 'income', amount: 5000000, occurred_at: currentMonthTimestamp, deleted_at: null },
      ],
      isLoading: false,
      error: undefined,
    } as any);

    render(<InicioRoute />);

    expect(screen.getByText(/Gastado en/i)).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.getByText('Gs. 200.000')).toBeInTheDocument();
    });

    // Verify PROHIBITION: Sin "Podés gastar hoy"
    expect(screen.queryByText(/Podés gastar hoy/i)).not.toBeInTheDocument();
    expect(document.title).toBe('Inicio · Pockt');
  });
});
