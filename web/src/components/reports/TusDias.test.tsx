import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { TusDias, type DayData } from './TusDias';

describe('TusDias Component', () => {
  const generateMockDays = (count = 182): DayData[] => {
    const days: DayData[] = [];
    const baseDate = new Date(2026, 4, 1);
    for (let i = 0; i < count; i++) {
      const d = new Date(baseDate);
      d.setDate(baseDate.getDate() + i);
      const amount = i % 3 === 0 ? 0 : 50000 * (i % 5);
      days.push({
        date: d,
        amount,
        txCount: amount > 0 ? 1 + (i % 3) : 0,
        topMerchant: amount > 0 ? 'Superseis' : undefined,
      });
    }
    return days;
  };

  it('renders in 2D mode by default with total amount and legend', () => {
    const days = generateMockDays(182);
    render(
      <TusDias
        days={days}
        periodLabel="Gastado en 6 meses"
        totalAmount={14820500}
      />
    );

    expect(screen.getByText('Gastado en 6 meses')).toBeInTheDocument();
    expect(screen.getByText(/14\.820\.500/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '2D' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '3D' })).toBeInTheDocument();
    expect(screen.getByText(/menos/i)).toBeInTheDocument();
    expect(screen.getByText(/más/i)).toBeInTheDocument();

    // In jsdom without WebGL, it falls back cleanly to 2D SVG grid
    const svgGrid = screen.getByTestId('tus-dias-2d-svg');
    expect(svgGrid).toBeInTheDocument();
  });

  it('triggers onSelectDay callback when clicking a day cell in 2D mode', () => {
    const days = generateMockDays(182);
    const onSelectDay = vi.fn();
    render(
      <TusDias
        days={days}
        periodLabel="Gastado en 6 meses"
        totalAmount={14820500}
        onSelectDay={onSelectDay}
      />
    );

    const cells = screen.getAllByTestId('tus-dias-cell');
    expect(cells.length).toBe(182);

    fireEvent.click(cells[1]);
    expect(onSelectDay).toHaveBeenCalledWith(expect.objectContaining({
      amount: days[1].amount,
      txCount: days[1].txCount,
    }));
  });

  it('switches mode when clicking 3D and 2D buttons', () => {
    const days = generateMockDays(182);
    render(
      <TusDias
        days={days}
        periodLabel="Gastado en 6 meses"
        totalAmount={14820500}
      />
    );

    const btn3D = screen.getByRole('button', { name: '3D' });
    const btn2D = screen.getByRole('button', { name: '2D' });

    fireEvent.click(btn3D);
    expect(btn3D).toHaveClass('on');

    fireEvent.click(btn2D);
    expect(btn2D).toHaveClass('on');
  });

  it('renders tooltip on day hover in 2D mode', () => {
    const days = generateMockDays(182);
    render(
      <TusDias
        days={days}
        periodLabel="Gastado en 6 meses"
        totalAmount={14820500}
      />
    );

    const cells = screen.getAllByTestId('tus-dias-cell');
    fireEvent.mouseEnter(cells[2]);

    expect(screen.getByTestId('tus-dias-tooltip')).toBeInTheDocument();
  });
});
