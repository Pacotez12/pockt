import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import React from 'react';
import { CountUp } from './CountUp';

describe('CountUp', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('renders final value directly when prefers-reduced-motion is true', () => {
    // Mock matchMedia for prefers-reduced-motion: reduce
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

    render(<CountUp value={1240500} />);

    // Directly shows final value formatted as Gs. 1.240.500
    expect(screen.getByText('Gs. 1.240.500')).toBeInTheDocument();
  });

  it('formats custom amounts and renders tabular-nums class', () => {
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

    render(<CountUp value={45000} className="custom-style" />);
    const el = screen.getByText('Gs. 45.000');
    expect(el).toHaveClass('custom-style');
    expect(el).toHaveClass('tabular-nums');
  });
});
