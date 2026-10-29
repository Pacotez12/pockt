import { createClient } from '@supabase/supabase-js';
import { UpdateType, type PowerSyncBackendConnector } from '@powersync/web';

const { VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY, VITE_POWERSYNC_URL } = import.meta.env;
export const configError = !VITE_SUPABASE_URL || !VITE_SUPABASE_ANON_KEY || !VITE_POWERSYNC_URL;
// Los placeholders permiten mostrar un error de configuración dentro de la página.
export const supabase = createClient(
  VITE_SUPABASE_URL || 'http://localhost:54321',
  VITE_SUPABASE_ANON_KEY || 'missing-local-anon-key',
);

export function connectorFor(userId: string): PowerSyncBackendConnector {
  return {
    async fetchCredentials() {
      const { data, error } = await supabase.auth.getSession();
      if (error) throw error;
      if (!data.session || data.session.user.id !== userId) return null;
      return {
        endpoint: VITE_POWERSYNC_URL,
        token: data.session.access_token,
        expiresAt: new Date(data.session.expires_at! * 1000),
      };
    },
    async uploadData(database) {
      const transaction = await database.getNextCrudTransaction();
      if (!transaction) return;
      for (const entry of transaction.crud) {
        if (entry.table !== 'spike_tx' || entry.op !== UpdateType.PUT) {
          throw new Error('Este spike solo sube inserciones de spike_tx.');
        }
        // Upsert por UUID hace idempotente el reintento de una subida.
        const { error } = await supabase.from('spike_tx').upsert({
          ...entry.opData,
          id: entry.id,
          user_id: userId,
        });
        if (error) throw error;
      }
      await transaction.complete();
    },
  };
}
