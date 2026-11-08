import React from 'react';
import { describe, it, expect, vi } from 'vitest';
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

  it('renders in 2D mode by default with 4 stats cards and title', () => {
    const days = generateMockDays(182);
    render(
      <TusDias
        days={days}
        referenceDate={new Date(2026, 9, 29)}
      />
    );

    expect(screen.getByText(/Gastado desde el/i)).toBeInTheDocument();
    expect(screen.getByText('Día más caro')).toBeInTheDocument();
    expect(screen.getByText('Promedio por día')).toBeInTheDocument();
    expect(screen.getByText('Días sin gastos')).toBeInTheDocument();
    expect(screen.getByText('Racha actual')).toBeInTheDocument();

    expect(screen.getByRole('button', { name: '2D' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '3D' })).toBeInTheDocument();
    expect(screen.getByText(/menos/i)).toBeInTheDocument();
    expect(screen.getByText(/^más$/i)).toBeInTheDocument();
  });

  it('ventana con datos desde octubre arranca en esa semana', () => {
    const refDate = new Date(2026, 11, 16); // 16 Dec 2026
    const octExpenseDate = new Date(2026, 9, 12); // Monday 12 Oct 2026
    const days: DayData[] = [
      { date: octExpenseDate, amount: 150000, txCount: 2, topMerchant: 'Superseis' },
      { date: new Date(2026, 10, 5), amount: 80000, txCount: 1 },
      { date: refDate, amount: 0, txCount: 0 },
    ];

    render(<TusDias days={days} referenceDate={refDate} />);

    const cells = screen.getAllByTestId('tus-dias-cell');
    // 10 weeks * 7 = 70 cells
    expect(cells.length).toBe(70);
    expect(cells[0]).toHaveAttribute('data-date', '2026-10-12');
  });

  it('con datos de más de 6 meses, la ventana es de 6 meses (26 semanas)', () => {
    const refDate = new Date(2026, 11, 15);
    const days: DayData[] = [
      { date: new Date(2026, 0, 10), amount: 200000, txCount: 1 },
      { date: new Date(2026, 11, 1), amount: 50000, txCount: 1 },
    ];

    render(<TusDias days={days} referenceDate={refDate} />);

    const cells = screen.getAllByTestId('tus-dias-cell');
    expect(cells.length).toBe(26 * 7);
  });

  it('días futuros no clicables', () => {
    const refDate = new Date(2026, 10, 11); // Wednesday 11 Nov 2026
    const onSelectDay = vi.fn();
    const days: DayData[] = [
      { date: new Date(2026, 9, 1), amount: 50000, txCount: 1 },
    ];

    render(
      <TusDias
        days={days}
        referenceDate={refDate}
        onSelectDay={onSelectDay}
      />
    );

    const futureCells = screen.getAllByTestId('tus-dias-cell').filter(
      (c) => c.getAttribute('data-future') === 'true'
    );
    expect(futureCells.length).toBeGreaterThan(0);

    // Clicking future cell does not call onSelectDay
    fireEvent.click(futureCells[0]);
    expect(onSelectDay).not.toHaveBeenCalled();

    // Clicking past/today cell does call onSelectDay
    const pastCells = screen.getAllByTestId('tus-dias-cell').filter(
      (c) => c.getAttribute('data-future') !== 'true'
    );
    fireEvent.click(pastCells[0]);
    expect(onSelectDay).toHaveBeenCalledTimes(1);
  });

  it('cálculos de stats con casos inventados (incluido sin gastos y racha 0)', () => {
    const refDate = new Date(2026, 10, 10);
    // Caso 1: sin gastos
    const zeroDays: DayData[] = [
      { date: new Date(2026, 9, 1), amount: 0, txCount: 0 },
    ];

    const { rerender } = render(
      <TusDias days={zeroDays} referenceDate={refDate} />
    );

    expect(screen.getByTestId('stat-dia-mas-caro')).toHaveTextContent('-');
    expect(screen.getByTestId('stat-dias-sin-gastos')).toHaveTextContent('100 %');

    // Caso 2: hoy con gastos -> racha 0
    const todayExpenseDays: DayData[] = [
      { date: new Date(2026, 10, 10), amount: 200000, txCount: 2, topMerchant: 'Biggie' },
    ];

    rerender(<TusDias days={todayExpenseDays} referenceDate={refDate} />);
    expect(screen.getByTestId('stat-racha-actual')).toHaveTextContent('0 días');
  });

  it('muestra hoy con marca distintiva y días de la semana L, M, V, D', () => {
    const refDate = new Date(2026, 10, 11);
    render(<TusDias days={[]} referenceDate={refDate} />);

    const todayCell = screen.getAllByTestId('tus-dias-cell').find(
      (c) => c.getAttribute('data-today') === 'true'
    );
    expect(todayCell).toBeDefined();

    expect(screen.getByText('L')).toBeInTheDocument();
    expect(screen.getByText('M')).toBeInTheDocument();
    expect(screen.getByText('V')).toBeInTheDocument();
    expect(screen.getByText('D')).toBeInTheDocument();
  });

  it('switches mode when clicking 3D and 2D buttons', () => {
    const days = generateMockDays(60);
    render(<TusDias days={days} />);

    const btn3D = screen.getByRole('button', { name: '3D' });
    const btn2D = screen.getByRole('button', { name: '2D' });

    fireEvent.click(btn3D);
    expect(btn3D).toHaveClass('on');

    fireEvent.click(btn2D);
    expect(btn2D).toHaveClass('on');
  });

  it('renders tooltip on day hover in 2D mode', () => {
    const refDate = new Date(2026, 10, 11);
    const days: DayData[] = [
      { date: new Date(2026, 10, 10), amount: 124500, txCount: 3, topMerchant: 'Farmacenter' },
    ];

    render(<TusDias days={days} referenceDate={refDate} />);

    const cell = screen.getAllByTestId('tus-dias-cell').find(
      (c) => c.getAttribute('data-date') === '2026-11-10'
    );
    expect(cell).toBeDefined();

    fireEvent.mouseEnter(cell!);
    expect(screen.getByTestId('tus-dias-tooltip')).toBeInTheDocument();
    expect(screen.getByText(/124\.500/)).toBeInTheDocument();
  });
});
