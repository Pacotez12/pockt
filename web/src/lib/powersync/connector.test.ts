import { describe, it, expect, vi } from 'vitest';
import { UpdateType } from '@powersync/web';
import {
  PocktSupabaseConnector,
  createSupabaseBackend,
  type SupabaseSyncBackend,
} from './connector';

describe('PocktSupabaseConnector', () => {
  const fakeUrl = 'https://powersync.example.com';

  function createMockBackend(overrides: Partial<SupabaseSyncBackend> = {}): SupabaseSyncBackend {
    const backend: SupabaseSyncBackend = {
      getAccessToken: vi.fn().mockResolvedValue('test-access-token'),
      getCurrentUserId: vi.fn().mockResolvedValue('user-a'),
      upsert: vi.fn().mockResolvedValue({ error: null }),
      update: vi.fn().mockResolvedValue({ error: null }),
      delete: vi.fn().mockResolvedValue({ error: null }),
      ...overrides,
    };
    if (!backend.createBatchBackend) {
      backend.createBatchBackend = vi.fn().mockImplementation((_token: string) => backend);
    }
    return backend;
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
    it('la base de A con sesión de B no llama a upsert, update ni delete', async () => {
      const backend = createMockBackend({
        getCurrentUserId: vi.fn().mockResolvedValue('user-b'),
      });
      const connector = new PocktSupabaseConnector(backend, fakeUrl, 'user-a');
      const db = createMockDb([
        {
          id: 'tx-1',
          table: 'transactions',
          op: UpdateType.PUT,
          opData: { amount: 100 },
        },
        {
          id: 'tx-2',
          table: 'transactions',
          op: UpdateType.PATCH,
          opData: { amount: 200 },
        },
        {
          id: 'tx-3',
          table: 'transactions',
          op: UpdateType.DELETE,
        },
      ]);

      await expect(connector.uploadData(db as any)).rejects.toThrow();
      expect(backend.upsert).not.toHaveBeenCalled();
      expect(backend.update).not.toHaveBeenCalled();
      expect(backend.delete).not.toHaveBeenCalled();
      expect(db.complete).not.toHaveBeenCalled();
    });

    it('un cambio de sesión a mitad del lote no hace que ninguna escritura salga con el token nuevo', async () => {
      let currentToken = 'token-user-a';
      let currentUserId = 'user-a';

      const createdClients: Array<{ token: string; ops: string[] }> = [];

      const clientFactory = vi.fn((_url: string, _key: string, options: any) => {
        const authHeader = options?.global?.headers?.Authorization || '';
        const tokenUsed = authHeader.replace('Bearer ', '');
        const clientOps: string[] = [];
        const clientRecord = { token: tokenUsed, ops: clientOps };
        createdClients.push(clientRecord);

        return {
          from: vi.fn((table: string) => ({
            upsert: vi.fn(async (data: any) => {
              clientOps.push(`upsert:${table}:${data.id}`);
              // Mid-batch session switch simulation!
              currentToken = 'token-user-b';
              currentUserId = 'user-b';
              return { error: null };
            }),
            update: vi.fn((_data: any) => ({
              eq: vi.fn(async (_col: string, id: string) => {
                clientOps.push(`update:${table}:${id}`);
                return { error: null };
              }),
            })),
            delete: vi.fn(() => ({
              eq: vi.fn(async (_col: string, id: string) => {
                clientOps.push(`delete:${table}:${id}`);
                return { error: null };
              }),
            })),
          })),
        } as any;
      });

      const sharedBackend: SupabaseSyncBackend = {
        getAccessToken: vi.fn(async () => currentToken),
        getCurrentUserId: vi.fn(async () => currentUserId),
        upsert: vi.fn().mockRejectedValue(new Error('Shared client must NOT be used for writes')),
        update: vi.fn().mockRejectedValue(new Error('Shared client must NOT be used for writes')),
        delete: vi.fn().mockRejectedValue(new Error('Shared client must NOT be used for writes')),
      };

      const connector = new PocktSupabaseConnector(
        sharedBackend,
        fakeUrl,
        'user-a',
        'http://localhost:54321',
        'test-key',
        clientFactory
      );

      const db = createMockDb([
        { id: 'tx-1', table: 'transactions', op: UpdateType.PUT, opData: { amount: 100 } },
        { id: 'tx-2', table: 'transactions', op: UpdateType.PATCH, opData: { amount: 200 } },
      ]);

      await connector.uploadData(db as any);

      // Exactly 1 batch client created with user-a's token
      expect(clientFactory).toHaveBeenCalledTimes(1);
      expect(createdClients.length).toBe(1);
      expect(createdClients[0].token).toBe('token-user-a');
      expect(createdClients[0].ops).toEqual(['upsert:transactions:tx-1', 'update:transactions:tx-2']);
      // None of the writes went to shared client or with token-b
      expect(sharedBackend.upsert).not.toHaveBeenCalled();
      expect(sharedBackend.update).not.toHaveBeenCalled();
      expect(db.complete).toHaveBeenCalled();
    });

    it('createBatchBackend genera un cliente con Authorization Bearer y sin sesión persistente', async () => {
      const clientFactory = vi.fn((url: string, key: string, options: any) => {
        return {
          url,
          key,
          options,
          from: vi.fn(),
          auth: { getSession: vi.fn() },
        } as any;
      });

      const sharedClient = { auth: { getSession: vi.fn() } } as any;
      const backend = createSupabaseBackend(
        sharedClient,
        'https://test.supabase.co',
        'anon-key-123',
        clientFactory
      );

      expect(backend.createBatchBackend).toBeDefined();
      backend.createBatchBackend!('fixed-batch-token');

      expect(clientFactory).toHaveBeenCalledWith(
        'https://test.supabase.co',
        'anon-key-123',
        {
          global: { headers: { Authorization: 'Bearer fixed-batch-token' } },
          auth: {
            persistSession: false,
            autoRefreshToken: false,
            detectSessionInUri: false,
          },
        }
      );
    });

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
