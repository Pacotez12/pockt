import React, { useEffect, useState } from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { PowerSyncContext } from '@powersync/react';
import type { PowerSyncDatabase } from '@powersync/web';
import { useAuth } from '@/lib/auth';
import { getPowerSyncDatabase, connectPowerSync } from '@/lib/powersync/db';

export function ProtectedRoute() {
  const { session, user, loading } = useAuth();
  const [db, setDb] = useState<PowerSyncDatabase | null>(null);

  useEffect(() => {
    if (!user) {
      setDb(null);
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

  if (loading) {
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

  const content = <Outlet />;

  if (db) {
    return <PowerSyncContext.Provider value={db as any}>{content}</PowerSyncContext.Provider>;
  }

  return content;
}
