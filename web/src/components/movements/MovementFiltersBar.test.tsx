import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import React from 'react';
import { MovementFiltersBar } from './MovementFiltersBar';

describe('MovementFiltersBar', () => {
  const mockCategories = [
    { id: 'cat-1', name: 'Comida' },
    { id: 'cat-2', name: 'Transporte' },
  ];

  it('renders search input and filter buttons', () => {
    render(
      <MovementFiltersBar
        search=""
        onSearchChange={vi.fn()}
        filters={{}}
        onFiltersChange={vi.fn()}
        categories={mockCategories as any}
        onExportCsv={vi.fn()}
        onExportXlsx={vi.fn()}
      />
    );

    expect(screen.getByPlaceholderText(/Buscar comercio o nota/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Descargar/i })).toBeInTheDocument();
  });

  it('triggers search change when typing', () => {
    const onSearch = vi.fn();
    render(
      <MovementFiltersBar
        search=""
        onSearchChange={onSearch}
        filters={{}}
        onFiltersChange={vi.fn()}
        categories={mockCategories as any}
        onExportCsv={vi.fn()}
        onExportXlsx={vi.fn()}
      />
    );

    const input = screen.getByPlaceholderText(/Buscar comercio o nota/i);
    fireEvent.change(input, { target: { value: 'Superseis' } });

    expect(onSearch).toHaveBeenCalledWith('Superseis');
  });

  it('shows and calls clear filters when any filter is active', () => {
    const onClear = vi.fn();
    render(
      <MovementFiltersBar
        search="algo"
        onSearchChange={vi.fn()}
        filters={{ type: 'expense' }}
        onFiltersChange={vi.fn()}
        onClearFilters={onClear}
        categories={mockCategories as any}
        onExportCsv={vi.fn()}
        onExportXlsx={vi.fn()}
      />
    );

    const clearBtn = screen.getByRole('button', { name: /Limpiar/i });
    expect(clearBtn).toBeInTheDocument();

    fireEvent.click(clearBtn);
    expect(onClear).toHaveBeenCalled();
  });

  it('keeps only one popover open at a time, closing previous popovers', () => {
    render(
      <MovementFiltersBar
        search=""
        onSearchChange={vi.fn()}
        filters={{}}
        onFiltersChange={vi.fn()}
        categories={mockCategories as any}
        onExportCsv={vi.fn()}
        onExportXlsx={vi.fn()}
      />
    );

    const catBtn = screen.getByRole('button', { name: /Categoría/i });
    const typeBtn = screen.getByRole('button', { name: /Tipo/i });

    // Open category popover
    fireEvent.click(catBtn);
    expect(screen.getByText('Comida')).toBeInTheDocument();

    // Now open type popover - category should close
    fireEvent.click(typeBtn);
    expect(screen.queryByText('Comida')).not.toBeInTheDocument();
    expect(screen.getByText('Gastos')).toBeInTheDocument();
  });

  it('closes open popover on Escape key and on clicking outside', () => {
    render(
      <MovementFiltersBar
        search=""
        onSearchChange={vi.fn()}
        filters={{}}
        onFiltersChange={vi.fn()}
        categories={mockCategories as any}
        onExportCsv={vi.fn()}
        onExportXlsx={vi.fn()}
      />
    );

    const catBtn = screen.getByRole('button', { name: /Categoría/i });

    // Open popover
    fireEvent.click(catBtn);
    expect(screen.getByText('Comida')).toBeInTheDocument();

    // Press Escape
    fireEvent.keyDown(document, { key: 'Escape' });
    expect(screen.queryByText('Comida')).not.toBeInTheDocument();

    // Open again and click outside
    fireEvent.click(catBtn);
    expect(screen.getByText('Comida')).toBeInTheDocument();

    fireEvent.mouseDown(document.body);
    expect(screen.queryByText('Comida')).not.toBeInTheDocument();
  });
});
