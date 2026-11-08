import {
  UpdateType,
  type AbstractPowerSyncDatabase,
  type PowerSyncBackendConnector,
  type PowerSyncCredentials,
} from '@powersync/web';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

export interface BackendResult {
  error?: { code?: string; message?: string } | null;
}

export interface SupabaseSyncBackend {
  getAccessToken(): Promise<string | null>;
  getCurrentUserId?(): Promise<string | null>;
  upsert(
    table: string,
    data: Record<string, unknown>,
    onConflict: string
  ): Promise<BackendResult>;
  update(
    table: string,
    id: string,
    data: Record<string, unknown>
  ): Promise<BackendResult>;
  delete(table: string, id: string): Promise<BackendResult>;
  createBatchBackend?(token: string): SupabaseSyncBackend;
}

export type ClientFactory = (url: string, key: string, options: any) => SupabaseClient;

export function createSupabaseBackend(
  client: SupabaseClient,
  url: string = import.meta.env.VITE_SUPABASE_URL || 'http://localhost:54321',
  anonKey: string = import.meta.env.VITE_SUPABASE_ANON_KEY || 'missing-anon-key',
  clientFactory?: ClientFactory
): SupabaseSyncBackend {
  return {
    async getAccessToken() {
      const { data } = await client.auth.getSession();
      return data.session?.access_token ?? null;
    },
    async getCurrentUserId() {
      const { data } = await client.auth.getSession();
      return data.session?.user?.id ?? null;
    },
    createBatchBackend(token: string) {
      const clientOptions = {
        global: { headers: { Authorization: `Bearer ${token}` } },
        auth: {
          persistSession: false,
          autoRefreshToken: false,
          detectSessionInUri: false,
        },
      };
      const batchClient = (clientFactory || createClient)(url, anonKey, clientOptions);
      return createSupabaseBackend(batchClient, url, anonKey, clientFactory);
    },
    async upsert(table, data, onConflict) {
      const res = await client.from(table).upsert(data, { onConflict });
      return { error: res.error };
    },
    async update(table, id, data) {
      const res = await client.from(table).update(data).eq('id', id);
      return { error: res.error };
    },
    async delete(table, id) {
      const res = await client.from(table).delete().eq('id', id);
      return { error: res.error };
    },
  };
}

export class PocktSupabaseConnector implements PowerSyncBackendConnector {
  constructor(
    private backend: SupabaseSyncBackend,
    private endpoint: string = import.meta.env.VITE_POWERSYNC_URL || '',
    private dbOwnerUserId: string | null = null,
    private supabaseUrl: string = import.meta.env.VITE_SUPABASE_URL || 'http://localhost:54321',
    private supabaseAnonKey: string = import.meta.env.VITE_SUPABASE_ANON_KEY || 'missing-anon-key',
    private clientFactory?: ClientFactory
  ) {}

  async fetchCredentials(): Promise<PowerSyncCredentials | null> {
    if (this.dbOwnerUserId && this.backend.getCurrentUserId) {
      const currentUserId = await this.backend.getCurrentUserId();
      if (!currentUserId || currentUserId !== this.dbOwnerUserId) {
        throw new Error(
          `PowerSync: sesión no válida o de otro usuario (esperado: ${this.dbOwnerUserId}, actual: ${currentUserId})`
        );
      }
    }

    const token = await this.backend.getAccessToken();
    if (!token) return null;
    return {
      endpoint: this.endpoint,
      token,
    };
  }

  async uploadData(database: AbstractPowerSyncDatabase): Promise<void> {
    const token = await this.backend.getAccessToken();
    if (!token) {
      throw new Error('No hay sesión activa para sincronizar datos. Cola intacta.');
    }

    if (this.dbOwnerUserId && this.backend.getCurrentUserId) {
      const currentUserId = await this.backend.getCurrentUserId();
      if (!currentUserId || currentUserId !== this.dbOwnerUserId) {
        throw new Error(
          `PowerSync: sesión no válida o de otro usuario (esperado: ${this.dbOwnerUserId}, actual: ${currentUserId}). Cola intacta.`
        );
      }
    }

    const transaction = await database.getNextCrudTransaction();
    if (!transaction) return;

    const batchBackend = this.backend.createBatchBackend
      ? this.backend.createBatchBackend(token)
      : createSupabaseBackend(
          (this.clientFactory || createClient)(this.supabaseUrl, this.supabaseAnonKey, {
            global: { headers: { Authorization: `Bearer ${token}` } },
            auth: {
              persistSession: false,
              autoRefreshToken: false,
              detectSessionInUri: false,
            },
          }),
          this.supabaseUrl,
          this.supabaseAnonKey,
          this.clientFactory
        );

    for (const op of transaction.crud) {
      const data = { ...((op.opData as Record<string, unknown>) || {}) };
      delete data.user_id;

      try {
        let result: BackendResult | undefined;

        if (op.op === UpdateType.PUT) {
          result = await batchBackend.upsert(
            op.table,
            { ...data, id: op.id },
            'user_id,id'
          );
        } else if (op.op === UpdateType.PATCH) {
          result = await batchBackend.update(op.table, op.id, data);
        } else if (op.op === UpdateType.DELETE) {
          result = await batchBackend.delete(op.table, op.id);
        }

        if (result?.error) {
          throw result.error;
        }
      } catch (err: any) {
        const code = (err?.code as string | undefined) || '';
        const invalidData = code.startsWith('22') || code.startsWith('23');
        if (invalidData) {
          // Keep row contents and server messages out of logs
          console.warn(`PowerSync: rejected ${op.op} on ${op.table} (${code})`);
        } else {
          throw err;
        }
      }
    }

    await transaction.complete();
  }
}
