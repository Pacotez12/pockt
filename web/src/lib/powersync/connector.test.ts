import { describe, it, expect, vi } from 'vitest';
import { UpdateType } from '@powersync/web';
import { PocktSupabaseConnector, type SupabaseSyncBackend } from './connector';

describe('PocktSupabaseConnector', () => {
  const fakeUrl = 'https://powersync.example.com';

  function createMockBackend(overrides: Partial<SupabaseSyncBackend> = {}): SupabaseSyncBackend {
    return {
      getAccessToken: vi.fn().mockResolvedValue('test-access-token'),
      upsert: vi.fn().mockResolvedValue({ error: null }),
      update: vi.fn().mockResolvedValue({ error: null }),
      delete: vi.fn().mockResolvedValue({ error: null }),
      ...overrides,
    };
  }

  function createMockDb(crudOps: any[]) {
    const complete = vi.fn().mockResolvedValue(undefined);
    return {
      getNextCrudTransaction: vi.fn().mockResolvedValue(
        crudOps.length > 0
          ? {
              crud: crudOps,
              complete,
            }
          : null
      ),
      complete,
    };
  }

  describe('fetchCredentials', () => {
    it('returns endpoint and token when session is active', async () => {
      const backend = createMockBackend();
      const connector = new PocktSupabaseConnector(backend, fakeUrl);

      const creds = await connector.fetchCredentials();
      expect(creds).toEqual({
        endpoint: fakeUrl,
        token: 'test-access-token',
      });
    });

    it('returns null when no session is active', async () => {
      const backend = createMockBackend({
        getAccessToken: vi.fn().mockResolvedValue(null),
      });
      const connector = new PocktSupabaseConnector(backend, fakeUrl);

      const creds = await connector.fetchCredentials();
      expect(creds).toBeNull();
    });
  });

  describe('uploadData', () => {
    it('does nothing when there is no crud transaction', async () => {
      const backend = createMockBackend();
      const connector = new PocktSupabaseConnector(backend, fakeUrl);
      const db = createMockDb([]);

      await connector.uploadData(db as any);
      expect(backend.upsert).not.toHaveBeenCalled();
    });

    it('handles PUT by upserting on user_id,id and strips user_id from data', async () => {
      const backend = createMockBackend();
      const connector = new PocktSupabaseConnector(backend, fakeUrl);
      const db = createMockDb([
        {
          id: 'tx-123',
          table: 'transactions',
          op: UpdateType.PUT,
          opData: {
            user_id: 'should-be-removed',
            amount: 50000,
            type: 'expense',
          },
        },
      ]);

      await connector.uploadData(db as any);

      expect(backend.upsert).toHaveBeenCalledWith(
        'transactions',
        {
          id: 'tx-123',
          amount: 50000,
          type: 'expense',
        },
        'user_id,id'
      );
      expect(db.complete).toHaveBeenCalled();
    });

    it('handles PATCH by updating by id', async () => {
      const backend = createMockBackend();
      const connector = new PocktSupabaseConnector(backend, fakeUrl);
      const db = createMockDb([
        {
          id: 'cat-456',
          table: 'categories',
          op: UpdateType.PATCH,
          opData: {
            user_id: 'should-be-removed',
            name: 'Supermercado',
          },
        },
      ]);

      await connector.uploadData(db as any);

      expect(backend.update).toHaveBeenCalledWith(
        'categories',
        'cat-456',
        { name: 'Supermercado' }
      );
      expect(db.complete).toHaveBeenCalled();
    });

    it('handles DELETE by deleting by id', async () => {
      const backend = createMockBackend();
      const connector = new PocktSupabaseConnector(backend, fakeUrl);
      const db = createMockDb([
        {
          id: 'tx-999',
          table: 'transactions',
          op: UpdateType.DELETE,
        },
      ]);

      await connector.uploadData(db as any);

      expect(backend.delete).toHaveBeenCalledWith('transactions', 'tx-999');
      expect(db.complete).toHaveBeenCalled();
    });

    it('discards and warns on Postgres 22* and 23* error codes without failing the transaction', async () => {
      const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});
      const backend = createMockBackend({
        upsert: vi.fn().mockResolvedValue({
          error: { code: '23505', message: 'duplicate key value violates unique constraint' },
        }),
      });
      const connector = new PocktSupabaseConnector(backend, fakeUrl);
      const db = createMockDb([
        {
          id: 'tx-conflict',
          table: 'transactions',
          op: UpdateType.PUT,
          opData: { amount: 100 },
        },
      ]);

      await connector.uploadData(db as any);

      expect(warnSpy).toHaveBeenCalledWith(
        expect.stringContaining('PowerSync: rejected PUT on transactions (23505)')
      );
      expect(db.complete).toHaveBeenCalled();
      warnSpy.mockRestore();
    });

    it('rethrows unexpected errors (e.g. 500 or network error) and does not complete transaction', async () => {
      const backend = createMockBackend({
        update: vi.fn().mockResolvedValue({
          error: { code: '500', message: 'Internal server error' },
        }),
      });
      const connector = new PocktSupabaseConnector(backend, fakeUrl);
      const db = createMockDb([
        {
          id: 'tx-fail',
          table: 'transactions',
          op: UpdateType.PATCH,
          opData: { amount: 200 },
        },
      ]);

      await expect(connector.uploadData(db as any)).rejects.toMatchObject({
        code: '500',
      });
      expect(db.complete).not.toHaveBeenCalled();
    });
  });
});
