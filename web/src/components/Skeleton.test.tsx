import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import React from 'react';
import { Skeleton } from './Skeleton';

describe('Skeleton', () => {
  it('renders with accessibility role and shimmer class by default', () => {
    render(<Skeleton data-testid="sk" className="w-20 h-6" />);
    const el = screen.getByTestId('sk');

    expect(el).toHaveAttribute('role', 'status');
    expect(el).toHaveAttribute('aria-label', 'Cargando...');
    expect(el).toHaveClass('skeleton-shimmer');
    expect(el).toHaveClass('w-20');
  });

  it('allows disabling shimmer', () => {
    render(<Skeleton data-testid="sk-no-shimmer" shimmer={false} />);
    const el = screen.getByTestId('sk-no-shimmer');
    expect(el).not.toHaveClass('skeleton-shimmer');
  });
});
