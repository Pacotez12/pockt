import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import React from 'react';
import { MovementPanel } from './MovementPanel';
import * as writeOps from '@/lib/movements/write';

vi.mock('@/lib/movements/write', () => ({
  createMovement: vi.fn(),
  updateMovement: vi.fn(),
  softDeleteMovement: vi.fn(),
  restoreMovement: vi.fn(),
}));

describe('MovementPanel', () => {
  const mockDb = {} as any;
  const mockCategories = [
    { id: 'cat-food', name: 'Comida', kind: 'expense', sort_order: 1, color_dark: 0xffe4a067, color_light: 0xffe4a067, icon: 'utensils' },
    { id: 'cat-salary', name: 'Sueldo', kind: 'income', sort_order: 2, color_dark: 0xff4ad496, color_light: 0xff008856, icon: 'wallet' },
    { id: 'cat-transfer', name: 'Transferencia', kind: 'expense', sort_order: 3, color_dark: 0xff6bbaf0, color_light: 0xff2176ae, icon: 'repeat' },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders "Cargar movimiento" with default fields and validates amount', async () => {
    const onClose = vi.fn();
    const onSaved = vi.fn();

    render(
      <MovementPanel
        isOpen={true}
        db={mockDb}
        categories={mockCategories}
        onClose={onClose}
        onSaved={onSaved}
      />
    );

    expect(screen.getByText('Cargar movimiento')).toBeInTheDocument();
    expect(screen.getByLabelText(/Monto/i)).toBeInTheDocument();
    expect(screen.getByText('Sin decimales, ej. 45.000')).toBeInTheDocument();

    const saveButton = screen.getByRole('button', { name: /Guardar/i });
    fireEvent.click(saveButton);

    // Shows validation error for amount
    expect(await screen.findByText(/ingresá un monto válido/i)).toBeInTheDocument();
    expect(writeOps.createMovement).not.toHaveBeenCalled();
  });

  it('elige una categoría por defecto cuando las categorías llegan después de abrir', async () => {
    vi.mocked(writeOps.createMovement).mockResolvedValueOnce('new-tx-id');
    const props = { isOpen: true, db: mockDb, onClose: vi.fn(), onSaved: vi.fn() };
    const { rerender } = render(<MovementPanel {...props} categories={[]} />);
    rerender(<MovementPanel {...props} categories={mockCategories} />);

    fireEvent.change(screen.getByLabelText(/Monto/i), { target: { value: '1000' } });
    fireEvent.click(screen.getByRole('button', { name: /Guardar/i }));

    await waitFor(() => expect(writeOps.createMovement).toHaveBeenCalled());
    expect(vi.mocked(writeOps.createMovement).mock.calls[0][1]).toMatchObject({ categoryId: 'cat-food' });
  });

  it('formats amount with thousands separator and creates movement on save', async () => {
    vi.mocked(writeOps.createMovement).mockResolvedValueOnce('new-tx-id');
    const onClose = vi.fn();
    const onSaved = vi.fn();

    render(
      <MovementPanel
        isOpen={true}
        db={mockDb}
        categories={mockCategories}
        onClose={onClose}
        onSaved={onSaved}
      />
    );

    const amountInput = screen.getByLabelText(/Monto/i);
    // User types "184000"
    fireEvent.change(amountInput, { target: { value: '184000' } });
    expect(amountInput).toHaveValue('184.000');

    // Merchant and Note
    fireEvent.change(screen.getByLabelText(/Comercio/i), { target: { value: 'Superseis' } });
    fireEvent.change(screen.getByLabelText(/Nota/i), { target: { value: 'Compra semanal' } });

    const saveButton = screen.getByRole('button', { name: /Guardar/i });
    fireEvent.click(saveButton);

    await waitFor(() => {
      expect(writeOps.createMovement).toHaveBeenCalledWith(
        mockDb,
        expect.objectContaining({
          type: 'expense',
          amount: 184000,
          categoryId: 'cat-food',
          merchant: 'Superseis',
          note: 'Compra semanal',
        })
      );
    });

    expect(onSaved).toHaveBeenCalledWith('new-tx-id');
    expect(onClose).toHaveBeenCalled();
  });

  it('renders "Editar movimiento" prefilled and updates on save', async () => {
    vi.mocked(writeOps.updateMovement).mockResolvedValueOnce();
    const onClose = vi.fn();
    const onSaved = vi.fn();

    const existingTx = {
      id: 'tx-existing',
      type: 'expense',
      amount: 45000,
      category_id: 'cat-food',
      merchant: 'Café Martínez',
      note: 'Café con medialunas',
      occurred_at: Math.floor(new Date('2026-10-28T10:00:00').getTime() / 1000),
      loan_id: null,
    };

    render(
      <MovementPanel
        isOpen={true}
        movement={existingTx as any}
        db={mockDb}
        categories={mockCategories}
        onClose={onClose}
        onSaved={onSaved}
      />
    );

    expect(screen.getByText('Editar movimiento')).toBeInTheDocument();
    expect(screen.getByLabelText(/Monto/i)).toHaveValue('45.000');
    expect(screen.getByLabelText(/Comercio/i)).toHaveValue('Café Martínez');
    expect(screen.getByLabelText(/Nota/i)).toHaveValue('Café con medialunas');

    // Change amount to 50000
    fireEvent.change(screen.getByLabelText(/Monto/i), { target: { value: '50000' } });

    const saveButton = screen.getByRole('button', { name: /Guardar/i });
    fireEvent.click(saveButton);

    await waitFor(() => {
      expect(writeOps.updateMovement).toHaveBeenCalledWith(
        mockDb,
        'tx-existing',
        expect.objectContaining({
          amount: 50000,
          merchant: 'Café Martínez',
        })
      );
    });

    expect(onSaved).toHaveBeenCalledWith('tx-existing');
  });

  it('shows loan notice and disables edits when movement has loan_id', () => {
    const loanTx = {
      id: 'tx-loan-1',
      type: 'expense',
      amount: 550000,
      category_id: 'cat-food',
      merchant: 'Cuota Préstamo',
      note: 'Cuota 3',
      occurred_at: Math.floor(Date.now() / 1000),
      loan_id: 'loan-123',
    };

    render(
      <MovementPanel
        isOpen={true}
        movement={loanTx as any}
        db={mockDb}
        categories={mockCategories}
        onClose={vi.fn()}
      />
    );

    expect(screen.getByText(/Editalo desde la app, afecta al préstamo/i)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Guardar/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Borrar/i })).not.toBeInTheDocument();
  });

  it('prompts confirmation when deleting and calls softDeleteMovement', async () => {
    vi.mocked(writeOps.softDeleteMovement).mockResolvedValueOnce();
    const onDelete = vi.fn();
    const onClose = vi.fn();

    const tx = {
      id: 'tx-del',
      type: 'expense',
      amount: 25000,
      category_id: 'cat-food',
      merchant: 'Heladería',
      occurred_at: Math.floor(Date.now() / 1000),
      loan_id: null,
    };

    render(
      <MovementPanel
        isOpen={true}
        movement={tx as any}
        db={mockDb}
        categories={mockCategories}
        onClose={onClose}
        onDeleted={onDelete}
      />
    );

    const deleteBtn = screen.getByRole('button', { name: /Borrar/i });
    fireEvent.click(deleteBtn);

    // Confirmation appears
    expect(screen.getByText(/Se borra también del teléfono/i)).toBeInTheDocument();

    const confirmDeleteBtn = screen.getByRole('button', { name: /Confirmar borrar/i });
    fireEvent.click(confirmDeleteBtn);

    await waitFor(() => {
      expect(writeOps.softDeleteMovement).toHaveBeenCalledWith(mockDb, 'tx-del');
    });

    expect(onDelete).toHaveBeenCalledWith('tx-del');
    expect(onClose).toHaveBeenCalled();
  });

  it('preserves draft edits when parent re-renders with fresh movement/categories object references (5d)', () => {
    const tx = {
      id: 'tx-draft',
      type: 'expense',
      amount: 50000,
      category_id: 'cat-food',
      merchant: 'Bar',
      occurred_at: Math.floor(Date.now() / 1000),
      loan_id: null,
    };

    const { rerender } = render(
      <MovementPanel
        isOpen={true}
        movement={tx as any}
        db={mockDb}
        categories={mockCategories}
        onClose={vi.fn()}
      />
    );

    // Edit the merchant field
    const merchantInput = screen.getByLabelText(/Comercio/i) as HTMLInputElement;
    fireEvent.change(merchantInput, { target: { value: 'Bar Nuevo' } });
    expect(merchantInput.value).toBe('Bar Nuevo');

    // Parent re-renders with a NEW object reference with same ID and new categories array reference
    rerender(
      <MovementPanel
        isOpen={true}
        movement={{ ...tx }}
        db={mockDb}
        categories={[...mockCategories]}
        onClose={vi.fn()}
      />
    );

    // The draft must NOT be wiped out
    expect(merchantInput.value).toBe('Bar Nuevo');
  });
});
