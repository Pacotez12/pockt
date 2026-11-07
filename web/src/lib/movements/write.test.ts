import { describe, it, expect, vi } from 'vitest';
import {
  createMovement,
  updateMovement,
  softDeleteMovement,
  restoreMovement,
} from './write';

describe('movements write operations', () => {
  const mockDb = () => {
    const executed: Array<{ sql: string; params: any[] }> = [];
    return {
      executed,
      execute: vi.fn(async (sql: string, params: any[] = []) => {
        executed.push({ sql, params });
        return { rows: [] };
      }),
      getAll: vi.fn(async (_sql: string, _params: any[] = []): Promise<any[]> => []),
      getOptional: vi.fn(async (_sql: string, _params: any[] = []): Promise<any> => null),
    };
  };

  describe('createMovement', () => {
    it('creates movement with valid columns, types, Unix seconds, and UUID', async () => {
      const db = mockDb();
      const date = new Date('2026-10-28T14:30:00Z');
      const occurredAtSeconds = Math.floor(date.getTime() / 1000);

      const id = await createMovement(db as any, {
        type: 'expense',
        amount: 45000,
        categoryId: 'cat-groceries',
        occurredAt: date,
        merchant: 'Superseis',
        note: 'Merienda',
      });

      expect(typeof id).toBe('string');
      expect(id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i);
      expect(db.execute).toHaveBeenCalledTimes(1);

      const call = db.executed[0];
      expect(call.sql).toContain('INSERT INTO transactions');
      expect(call.sql).toContain('occurred_at');
      expect(call.sql).toContain('created_at');
      expect(call.sql).toContain('updated_at');
      expect(call.sql).toContain('deleted_at');

      // Check parameter values:
      const params = call.params;
      expect(params[0]).toBe(id);
      expect(params[1]).toBe('expense');
      expect(params[2]).toBe(45000);
      expect(params[3]).toBe('PYG');
      expect(params[4]).toBe('cat-groceries');
      expect(params[5]).toBe('Superseis');
      expect(params[6]).toBe('Merienda');
      expect(params[7]).toBe(occurredAtSeconds);
      // created_at and updated_at should be positive integers in seconds
      expect(typeof params[8]).toBe('number');
      expect(params[8]).toBeGreaterThan(1700000000);
      expect(params[9]).toBe(params[8]);
      expect(params[10]).toBe('manual');
      expect(params[11]).toBe(0);
      expect(params[12]).toBeNull();
    });

    it('rejects invalid amounts (negative, zero, decimal)', async () => {
      const db = mockDb();

      await expect(
        createMovement(db as any, {
          type: 'expense',
          amount: 0,
          categoryId: 'cat-1',
          occurredAt: Math.floor(Date.now() / 1000),
        })
      ).rejects.toThrow(/monto/i);

      await expect(
        createMovement(db as any, {
          type: 'expense',
          amount: -5000,
          categoryId: 'cat-1',
          occurredAt: Math.floor(Date.now() / 1000),
        })
      ).rejects.toThrow(/monto/i);

      await expect(
        createMovement(db as any, {
          type: 'expense',
          amount: 1500.5,
          categoryId: 'cat-1',
          occurredAt: Math.floor(Date.now() / 1000),
        })
      ).rejects.toThrow(/monto/i);
    });
  });

  describe('updateMovement', () => {
    it('updates movement and updates updated_at timestamp', async () => {
      const db = mockDb();
      db.getOptional.mockResolvedValueOnce({
        id: 'tx-123',
        loan_id: null,
      });

      await updateMovement(db as any, 'tx-123', {
        amount: 90000,
        merchant: 'Biggie Express',
      });

      expect(db.execute).toHaveBeenCalledTimes(1);
      const call = db.executed[0];
      expect(call.sql).toContain('UPDATE transactions SET');
      expect(call.sql).toContain('amount = ?');
      expect(call.sql).toContain('merchant = ?');
      expect(call.sql).toContain('updated_at = ?');
      expect(call.sql).toContain('WHERE id = ?');
      expect(call.params).toContain(90000);
      expect(call.params).toContain('Biggie Express');
      expect(call.params[call.params.length - 1]).toBe('tx-123');
    });

    it('rejects editing movements linked to loans', async () => {
      const db = mockDb();
      db.getOptional.mockResolvedValueOnce({
        id: 'tx-loan-1',
        loan_id: 'loan-xyz',
      });

      await expect(
        updateMovement(db as any, 'tx-loan-1', {
          amount: 100000,
        })
      ).rejects.toThrow(/préstamo/i);
    });
  });

  describe('softDeleteMovement and restoreMovement', () => {
    it('soft deletes by setting deleted_at and updated_at without deleting row', async () => {
      const db = mockDb();
      db.getOptional.mockResolvedValueOnce({
        id: 'tx-to-delete',
        loan_id: null,
      });

      await softDeleteMovement(db as any, 'tx-to-delete');

      expect(db.execute).toHaveBeenCalledTimes(1);
      const call = db.executed[0];
      expect(call.sql).not.toContain('DELETE FROM');
      expect(call.sql).toContain('UPDATE transactions SET deleted_at = ?, updated_at = ? WHERE id = ?');
      expect(typeof call.params[0]).toBe('number');
      expect(typeof call.params[1]).toBe('number');
      expect(call.params[0]).toBe(call.params[1]); // deleted_at == updated_at
      expect(call.params[2]).toBe('tx-to-delete');
    });

    it('rejects deleting movements linked to loans', async () => {
      const db = mockDb();
      db.getOptional.mockResolvedValueOnce({
        id: 'tx-loan-1',
        loan_id: 'loan-abc',
      });

      await expect(softDeleteMovement(db as any, 'tx-loan-1')).rejects.toThrow(/préstamo/i);
    });

    it('restores soft-deleted movement by setting deleted_at to NULL', async () => {
      const db = mockDb();

      await restoreMovement(db as any, 'tx-to-restore');

      expect(db.execute).toHaveBeenCalledTimes(1);
      const call = db.executed[0];
      expect(call.sql).toContain('UPDATE transactions SET deleted_at = NULL, updated_at = ? WHERE id = ?');
      expect(call.params[1]).toBe('tx-to-restore');
    });
  });
});
