import {
  UpdateType,
  type AbstractPowerSyncDatabase,
  type PowerSyncBackendConnector,
  type PowerSyncCredentials,
} from '@powersync/web';
import type { SupabaseClient } from '@supabase/supabase-js';

export interface BackendResult {
  error?: { code?: string; message?: string } | null;
}

export interface SupabaseSyncBackend {
  getAccessToken(): Promise<string | null>;
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
}

export function createSupabaseBackend(client: SupabaseClient): SupabaseSyncBackend {
  return {
    async getAccessToken() {
      const { data } = await client.auth.getSession();
      return data.session?.access_token ?? null;
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
    private endpoint: string = import.meta.env.VITE_POWERSYNC_URL || ''
  ) {}

  async fetchCredentials(): Promise<PowerSyncCredentials | null> {
    const token = await this.backend.getAccessToken();
    if (!token) return null;
    return {
      endpoint: this.endpoint,
      token,
    };
  }

  async uploadData(database: AbstractPowerSyncDatabase): Promise<void> {
    const transaction = await database.getNextCrudTransaction();
    if (!transaction) return;

    const token = await this.backend.getAccessToken();
    if (!token) {
      throw new Error('No hay sesión activa para sincronizar datos.');
    }

    for (const op of transaction.crud) {
      const data = { ...((op.opData as Record<string, unknown>) || {}) };
      delete data.user_id;

      try {
        let result: BackendResult | undefined;

        if (op.op === UpdateType.PUT) {
          result = await this.backend.upsert(
            op.table,
            { ...data, id: op.id },
            'user_id,id'
          );
        } else if (op.op === UpdateType.PATCH) {
          result = await this.backend.update(op.table, op.id, data);
        } else if (op.op === UpdateType.DELETE) {
          result = await this.backend.delete(op.table, op.id);
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
