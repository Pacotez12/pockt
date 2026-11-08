import React, { createContext, useContext, useEffect, useState, useRef } from 'react';
import type { Session, User } from '@supabase/supabase-js';
import { supabase } from './supabase';

export interface LogoutOptions {
  force?: boolean;
  maxWaitMs?: number;
}

export interface AuthContextValue {
  session: Session | null;
  user: User | null;
  loading: boolean;
  logout: (options?: LogoutOptions) => Promise<void>;
  pendingLogout?: { count: number } | null;
  cancelLogout?: () => void;
  confirmLogout?: () => Promise<void>;
  isSyncingLogout?: boolean;
}

export const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [pendingLogout, setPendingLogout] = useState<{ count: number } | null>(null);
  const [isSyncingLogout, setIsSyncingLogout] = useState(false);
  const previousUserIdRef = useRef<string | null>(null);

  useEffect(() => {
    let mounted = true;

    // Check initial session
    supabase.auth.getSession().then(({ data }) => {
      if (!mounted) return;
      previousUserIdRef.current = data.session?.user?.id ?? null;
      setSession(data.session);
      setLoading(false);
    });

    // Listen to changes
    const { data: authListener } = supabase.auth.onAuthStateChange(
      async (_event, nextSession) => {
        if (!mounted) return;

        const nextUserId = nextSession?.user?.id ?? null;
        const prevUserId = previousUserIdRef.current;

        // If user changed to a different user without a logout in between (e.g. login in another tab)
        if (prevUserId && nextUserId && prevUserId !== nextUserId) {
          try {
            const { disconnectPowerSync } = await import('./powersync/db');
            await disconnectPowerSync();
          } catch (e) {
            console.warn('Error disconnecting PowerSync on user switch:', e);
          }
          if (typeof window !== 'undefined' && typeof window.location?.reload === 'function') {
            window.location.reload();
            return;
          }
        }

        previousUserIdRef.current = nextUserId;
        setSession(nextSession);
        setLoading(false);
      }
    );

    return () => {
      mounted = false;
      authListener.subscription.unsubscribe();
    };
  }, []);

  const executeLogout = async () => {
    try {
      const { disconnectAndClearPowerSync } = await import('./powersync/db');
      await disconnectAndClearPowerSync();
    } catch (e) {
      console.warn('Error clearing PowerSync db on logout:', e);
    }
    try {
      const { error } = await supabase.auth.signOut({ scope: 'local' });
      if (error) {
        console.warn('Error during supabase.auth.signOut:', error);
      }
    } catch (e) {
      console.warn('Exception during supabase.auth.signOut:', e);
    }
    previousUserIdRef.current = null;
    setSession(null);
    setPendingLogout(null);
    setIsSyncingLogout(false);
  };

  const cancelLogout = () => {
    setPendingLogout(null);
    setIsSyncingLogout(false);
  };

  const confirmLogout = async () => {
    await executeLogout();
  };

  const logout = async (options?: LogoutOptions) => {
    const force = options?.force ?? false;
    if (force) {
      await executeLogout();
      return;
    }

    let dbInstance: any = null;
    try {
      const { getActivePowerSyncDatabase } = await import('./powersync/db');
      dbInstance = getActivePowerSyncDatabase();
    } catch (_) {}

    if (!dbInstance || typeof dbInstance.getUploadQueueStats !== 'function') {
      await executeLogout();
      return;
    }

    try {
      let stats = await dbInstance.getUploadQueueStats();
      if (!stats || stats.count === 0) {
        await executeLogout();
        return;
      }

      // Si no hay conexión, mostrar confirmación directo sin esperar
      const isOnline = typeof navigator === 'undefined' ? true : navigator.onLine;
      if (!isOnline) {
        setPendingLogout({ count: stats.count });
        return;
      }

      // Si hay conexión, intentar subir esperando hasta 10s (o maxWaitMs) a que la cola llegue a 0
      const defaultMaxWait =
        typeof process !== 'undefined' && process.env.NODE_ENV === 'test' ? 100 : 10000;
      const maxWaitMs = options?.maxWaitMs ?? defaultMaxWait;

      setIsSyncingLogout(true);
      const start = Date.now();
      const pollInterval = Math.min(250, maxWaitMs);

      while (Date.now() - start < maxWaitMs) {
        await new Promise((r) => setTimeout(r, pollInterval));
        stats = await dbInstance.getUploadQueueStats();
        if (!stats || stats.count === 0) {
          setIsSyncingLogout(false);
          await executeLogout();
          return;
        }
      }

      setIsSyncingLogout(false);
      // Sigue con count > 0: mostrar confirmación
      setPendingLogout({ count: stats.count });
    } catch (err) {
      console.warn('Error checking upload queue stats before logout:', err);
      setIsSyncingLogout(false);
      await executeLogout();
    }
  };

  const user = session?.user ?? null;

  return (
    <AuthContext.Provider
      value={{
        session,
        user,
        loading,
        logout,
        pendingLogout,
        cancelLogout,
        confirmLogout,
        isSyncingLogout,
      }}
    >
      {children}

      {/* Confirmation Dialog when changes are pending upload */}
      {pendingLogout && (
        <div
          role="alertdialog"
          aria-modal="true"
          aria-labelledby="logout-confirm-title"
          aria-describedby="logout-confirm-desc"
          data-testid="logout-confirmation-modal"
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm select-none animate-in fade-in duration-150"
        >
          <div className="w-full max-w-[420px] rounded-3xl bg-sheet-surface border border-glass-border p-6 shadow-2xl space-y-4">
            <h2 id="logout-confirm-title" className="text-[18px] font-bold text-text-primary tracking-tight">
              Cambios sin guardar
            </h2>
            <p id="logout-confirm-desc" className="text-[14px] text-text-secondary leading-relaxed">
              Tenés {pendingLogout.count} {pendingLogout.count === 1 ? 'cambio' : 'cambios'} sin subir. Si cerrás sesión ahora se pierden.
            </p>
            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                type="button"
                onClick={cancelLogout}
                className="px-5 py-2.5 min-h-[40px] rounded-xl font-bold text-[13.5px] text-white shadow-sm transition-transform active:scale-95 cursor-pointer"
                style={{
                  background: 'linear-gradient(90deg, var(--brand-start), var(--brand-end))',
                }}
              >
                Cancelar
              </button>
              <button
                type="button"
                onClick={() => void confirmLogout()}
                className="px-4 py-2.5 min-h-[40px] rounded-xl border border-danger/40 text-danger text-[13px] font-semibold hover:bg-danger/10 transition-colors cursor-pointer"
              >
                Cerrar sesión igual
              </button>
            </div>
          </div>
        </div>
      )}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
