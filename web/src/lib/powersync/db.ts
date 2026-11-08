import { PowerSyncDatabase } from '@powersync/web';
import { AppSchema } from './schema';
import { PocktSupabaseConnector, createSupabaseBackend } from './connector';
import { supabase } from '../supabase';

let activeDatabase: PowerSyncDatabase | null = null;
let currentUserId: string | null = null;

export function getActivePowerSyncDatabase(): PowerSyncDatabase | null {
  return activeDatabase;
}

export function getPowerSyncDatabase(userId: string): PowerSyncDatabase {
  if (activeDatabase && currentUserId === userId) {
    return activeDatabase;
  }

  if (activeDatabase) {
    void activeDatabase.close().catch(console.error);
  }

  currentUserId = userId;
  activeDatabase = new PowerSyncDatabase({
    schema: AppSchema,
    database: { dbFilename: `pockt-${userId}.db` },
  });

  return activeDatabase;
}

export async function connectPowerSync(
  db: PowerSyncDatabase,
  endpoint: string = import.meta.env.VITE_POWERSYNC_URL || ''
): Promise<void> {
  const backend = createSupabaseBackend(supabase);
  const connector = new PocktSupabaseConnector(backend, endpoint);
  await db.connect(connector);
}

export async function disconnectAndClearPowerSync(db?: PowerSyncDatabase | null): Promise<void> {
  const target = db || activeDatabase;
  if (target) {
    try {
      await target.disconnectAndClear();
    } catch (e) {
      console.warn('Error during disconnectAndClear:', e);
    }
  }
  activeDatabase = null;
  currentUserId = null;
}
