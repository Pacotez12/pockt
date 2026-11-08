import React, { createContext, useContext, useEffect, useState, useRef } from 'react';
import type { Session, User } from '@supabase/supabase-js';
import { supabase } from './supabase';

export interface LogoutOptions {
  force?: boolean;
  maxWaitMs?: number;
}

export interface PendingLogoutInfo {
  count?: number;
  message?: string;
}

export interface AuthContextValue {
  session: Session | null;
  user: User | null;
  loading: boolean;
  logout: (options?: LogoutOptions) => Promise<void>;
  pendingLogout?: PendingLogoutInfo | null;
  cancelLogout?: () => void;
  confirmLogout?: () => Promise<void>;
  isSyncingLogout?: boolean;
  logoutError?: string | null;
  clearLogoutError?: () => void;
}

export const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [pendingLogout, setPendingLogout] = useState<PendingLogoutInfo | null>(null);
  const [isSyncingLogout, setIsSyncingLogout] = useState(false);
  const [logoutError, setLogoutError] = useState<string | null>(null);
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
    setLogoutError(null);
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

    // Step 3: Verify that session was actually cleared with getSession()
    try {
      const { data: postSignOut } = await supabase.auth.getSession();
      if (postSignOut?.session) {
        // Session remained! Clean up storage keys sb-*-auth-token
        if (typeof localStorage !== 'undefined') {
          const keysToRemove: string[] = [];
          for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (key && key.startsWith('sb-') && key.endsWith('-auth-token')) {
              keysToRemove.push(key);
            }
          }
          keysToRemove.forEach((k) => localStorage.removeItem(k));
        }

        const storageKey = (supabase.auth as any)?.storageKey;
        if (storageKey && typeof localStorage !== 'undefined') {
          localStorage.removeItem(storageKey);
        }

        const { data: finalCheck } = await supabase.auth.getSession();
        if (finalCheck?.session) {
          setLogoutError(
            'No se pudo cerrar la sesión completamente. Por favor intentá de nuevo.'
          );
          setIsSyncingLogout(false);
          setPendingLogout(null);
          return;
        }
      }
    } catch (e) {
      console.warn('Exception during session clearance verification:', e);
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
    setLogoutError(null);
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

    // FAIL CLOSED: si getUploadQueueStats no existe o no es función
    if (!dbInstance || typeof dbInstance.getUploadQueueStats !== 'function') {
      setPendingLogout({
        message:
          'No pudimos comprobar si hay cambios sin subir. Si cerrás sesión ahora podrían perderse.',
      });
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
      // FAIL CLOSED: si getUploadQueueStats falla, mostrar advertencia en vez de borrar
      setPendingLogout({
        message:
          'No pudimos comprobar si hay cambios sin subir. Si cerrás sesión ahora podrían perderse.',
      });
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
        logoutError,
        clearLogoutError: () => setLogoutError(null),
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
              {pendingLogout.message ||
                `Tenés ${pendingLogout.count} ${pendingLogout.count === 1 ? 'cambio' : 'cambios'} sin subir. Si cerrás sesión ahora se pierden.`}
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

      {/* Logout error banner when incomplete */}
      {logoutError && (
        <div
          role="alert"
          data-testid="logout-error-banner"
          className="fixed bottom-4 right-4 z-50 p-4 rounded-2xl bg-danger/10 border border-danger/30 text-danger text-sm font-semibold shadow-lg flex items-center gap-3 animate-in fade-in"
        >
          <span>{logoutError}</span>
          <button
            type="button"
            onClick={() => setLogoutError(null)}
            className="text-xs underline cursor-pointer ml-2"
          >
            Cerrar
          </button>
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
