import React, { useEffect, useState } from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { PowerSyncContext } from '@powersync/react';
import type { PowerSyncDatabase } from '@powersync/web';
import { useAuth } from '@/lib/auth';
import { getPowerSyncDatabase, connectPowerSync, disconnectPowerSync } from '@/lib/powersync/db';

export function ProtectedRoute() {
  const { session, user, loading } = useAuth();
  const [db, setDb] = useState<PowerSyncDatabase | null>(null);

  useEffect(() => {
    if (!user) {
      setDb(null);
      void disconnectPowerSync().catch((err) => {
        console.warn('PowerSync disconnect warning on user null:', err);
      });
      return;
    }

    try {
      const database = getPowerSyncDatabase(user.id);
      setDb(database);
      void connectPowerSync(database).catch((err) => {
        console.warn('PowerSync connection warning:', err);
      });
    } catch (e) {
      console.warn('Failed to initialize PowerSync database:', e);
    }
  }, [user]);

  // Hasta tener la base local las pantallas no pueden consultar: sin esto useQuery
  // lanza "PowerSync not configured" y la página queda en negro.
  if (loading || (session && !db)) {
    return (
      <div
        data-testid="auth-loading"
        className="min-h-screen flex items-center justify-center p-6 text-text-tertiary"
      >
        <div className="w-8 h-8 rounded-full border-2 border-glass-border border-t-brand-start animate-spin" />
      </div>
    );
  }

  if (!session) {
    return <Navigate to="/login" replace />;
  }

  return (
    <PowerSyncContext.Provider key={user?.id} value={db as any}>
      <Outlet key={user?.id} />
    </PowerSyncContext.Provider>
  );
}
