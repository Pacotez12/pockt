import { describe, it, expect, vi, beforeEach } from 'vitest';
import { supabase } from './supabase';
import * as powersyncDb from './powersync/db';
import { AuthProvider, useAuth } from './auth';
import { render, screen, fireEvent, act, waitFor } from '@testing-library/react';
import React from 'react';

vi.mock('./supabase', () => ({
  supabase: {
    auth: {
      getSession: vi.fn().mockResolvedValue({
        data: {
          session: {
            access_token: 'fake-token',
            user: { id: 'usr-123', email: 'test@example.com' },
          },
        },
      }),
      onAuthStateChange: vi.fn().mockReturnValue({
        data: {
          subscription: {
            unsubscribe: vi.fn(),
          },
        },
      }),
      signOut: vi.fn().mockResolvedValue({ error: null }),
    },
  },
}));

vi.mock('./powersync/db', () => ({
  disconnectPowerSync: vi.fn().mockResolvedValue(undefined),
  disconnectAndClearPowerSync: vi.fn().mockResolvedValue(undefined),
  getPowerSyncDatabase: vi.fn(),
  getActivePowerSyncDatabase: vi.fn(),
  connectPowerSync: vi.fn(),
}));

function LogoutTester() {
  const { logout, session } = useAuth();
  return (
    <div>
      <div data-testid="session-status">{session ? 'logged-in' : 'logged-out'}</div>
      <button type="button" onClick={() => void logout({ maxWaitMs: 30 })}>
        Logout Button
      </button>
    </div>
  );
}

describe('AuthContext logout', () => {
  let currentSession: any;

  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
    currentSession = {
      access_token: 'fake-token',
      user: { id: 'usr-123', email: 'test@example.com' },
    };
    vi.mocked(supabase.auth.getSession).mockImplementation(async () => ({
      data: { session: currentSession },
      error: null,
    }));
    vi.mocked(supabase.auth.signOut).mockImplementation(async () => {
      currentSession = null;
      return { error: null };
    });
  });

  it('con count 0, cierra directo sin mostrar confirmación', async () => {
    vi.mocked(powersyncDb.getActivePowerSyncDatabase).mockReturnValue({
      getUploadQueueStats: vi.fn().mockResolvedValue({ count: 0 }),
    } as any);

    render(
      <AuthProvider>
        <LogoutTester />
      </AuthProvider>
    );

    // Esperar a que cargue sesión
    await act(async () => {
      await Promise.resolve();
    });

    const btn = screen.getByRole('button', { name: 'Logout Button' });
    await act(async () => {
      fireEvent.click(btn);
    });

    expect(powersyncDb.disconnectAndClearPowerSync).toHaveBeenCalled();
    expect(supabase.auth.signOut).toHaveBeenCalled();
    expect(screen.queryByText(/cambios sin subir/i)).not.toBeInTheDocument();
  });

  it('con count > 0 que no baja, muestra la confirmación y Cancelar no borra nada', async () => {
    vi.mocked(powersyncDb.getActivePowerSyncDatabase).mockReturnValue({
      getUploadQueueStats: vi.fn().mockResolvedValue({ count: 2 }),
    } as any);

    render(
      <AuthProvider>
        <LogoutTester />
      </AuthProvider>
    );

    await act(async () => {
      await Promise.resolve();
    });

    const btn = screen.getByRole('button', { name: 'Logout Button' });
    fireEvent.click(btn);

    // Debe mostrar la confirmación con el texto requerido
    await waitFor(() => {
      expect(
        screen.getByText('Tenés 2 cambios sin subir. Si cerrás sesión ahora se pierden.')
      ).toBeInTheDocument();
    });
    expect(screen.getByRole('button', { name: 'Cancelar' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Cerrar sesión igual' })).toBeInTheDocument();

    // Cancelar no debe borrar la base ni desloguear
    const cancelBtn = screen.getByRole('button', { name: 'Cancelar' });
    fireEvent.click(cancelBtn);

    await waitFor(() => {
      expect(screen.queryByText(/cambios sin subir/i)).not.toBeInTheDocument();
    });

    expect(powersyncDb.disconnectAndClearPowerSync).not.toHaveBeenCalled();
    expect(supabase.auth.signOut).not.toHaveBeenCalled();
    expect(screen.getByTestId('session-status')).toHaveTextContent('logged-in');
  });

  it('con count > 0, "Cerrar sesión igual" sí borra y desloguea', async () => {
    vi.mocked(powersyncDb.getActivePowerSyncDatabase).mockReturnValue({
      getUploadQueueStats: vi.fn().mockResolvedValue({ count: 1 }),
    } as any);

    render(
      <AuthProvider>
        <LogoutTester />
      </AuthProvider>
    );

    await act(async () => {
      await Promise.resolve();
    });

    const btn = screen.getByRole('button', { name: 'Logout Button' });
    fireEvent.click(btn);

    await waitFor(() => {
      expect(
        screen.getByText('Tenés 1 cambio sin subir. Si cerrás sesión ahora se pierden.')
      ).toBeInTheDocument();
    });

    const forceBtn = screen.getByRole('button', { name: 'Cerrar sesión igual' });
    fireEvent.click(forceBtn);

    await waitFor(() => {
      expect(powersyncDb.disconnectAndClearPowerSync).toHaveBeenCalled();
      expect(supabase.auth.signOut).toHaveBeenCalled();
      expect(screen.queryByText(/cambios sin subir/i)).not.toBeInTheDocument();
      expect(screen.getByTestId('session-status')).toHaveTextContent('logged-out');
    });
  });

  it('logout usa scope local y borra sesión local aunque falle supabase', async () => {
    vi.mocked(powersyncDb.getActivePowerSyncDatabase).mockReturnValue({
      getUploadQueueStats: vi.fn().mockResolvedValue({ count: 0 }),
    } as any);
    vi.mocked(supabase.auth.signOut).mockImplementationOnce(async () => {
      currentSession = null;
      return { error: new Error('Server 500 error') as any };
    });

    render(
      <AuthProvider>
        <LogoutTester />
      </AuthProvider>
    );

    await act(async () => {
      await Promise.resolve();
    });

    const btn = screen.getByRole('button', { name: 'Logout Button' });
    await act(async () => {
      fireEvent.click(btn);
    });

    expect(supabase.auth.signOut).toHaveBeenCalledWith({ scope: 'local' });
    expect(screen.getByTestId('session-status')).toHaveTextContent('logged-out');
  });

  it('si getUploadQueueStats falla, falla en cerrado y muestra confirmación con mensaje de advertencia', async () => {
    vi.mocked(powersyncDb.getActivePowerSyncDatabase).mockReturnValue({
      getUploadQueueStats: vi.fn().mockRejectedValue(new Error('Queue stats error')),
    } as any);

    render(
      <AuthProvider>
        <LogoutTester />
      </AuthProvider>
    );

    await act(async () => {
      await Promise.resolve();
    });

    const btn = screen.getByRole('button', { name: 'Logout Button' });
    await act(async () => {
      fireEvent.click(btn);
    });

    expect(screen.getByTestId('logout-confirmation-modal')).toBeInTheDocument();
    expect(
      screen.getByText(
        'No pudimos comprobar si hay cambios sin subir. Si cerrás sesión ahora podrían perderse.'
      )
    ).toBeInTheDocument();
    expect(powersyncDb.disconnectAndClearPowerSync).not.toHaveBeenCalled();
    expect(screen.getByTestId('session-status')).toHaveTextContent('logged-in');
  });

  it('si getUploadQueueStats no existe en la base, falla en cerrado y muestra confirmación con mensaje de advertencia', async () => {
    vi.mocked(powersyncDb.getActivePowerSyncDatabase).mockReturnValue({} as any);

    render(
      <AuthProvider>
        <LogoutTester />
      </AuthProvider>
    );

    await act(async () => {
      await Promise.resolve();
    });

    const btn = screen.getByRole('button', { name: 'Logout Button' });
    await act(async () => {
      fireEvent.click(btn);
    });

    expect(screen.getByTestId('logout-confirmation-modal')).toBeInTheDocument();
    expect(
      screen.getByText(
        'No pudimos comprobar si hay cambios sin subir. Si cerrás sesión ahora podrían perderse.'
      )
    ).toBeInTheDocument();
    expect(powersyncDb.disconnectAndClearPowerSync).not.toHaveBeenCalled();
    expect(screen.getByTestId('session-status')).toHaveTextContent('logged-in');
  });

  it('si signOut local deja la sesión pero se limpia al borrar sb-*-auth-token de storage, completa logout', async () => {
    vi.mocked(powersyncDb.getActivePowerSyncDatabase).mockReturnValue({
      getUploadQueueStats: vi.fn().mockResolvedValue({ count: 0 }),
    } as any);

    localStorage.setItem('sb-testref-auth-token', 'stale-token');

    // signOut does not clear session itself
    vi.mocked(supabase.auth.signOut).mockImplementation(async () => {
      return { error: null };
    });

    // getSession checks whether localStorage still has the token
    vi.mocked(supabase.auth.getSession).mockImplementation(async () => {
      const hasToken = localStorage.getItem('sb-testref-auth-token') !== null;
      return {
        data: {
          session: hasToken
            ? ({ access_token: 'stale-token', user: { id: 'usr-123' } } as any)
            : null,
        },
        error: null,
      };
    });

    render(
      <AuthProvider>
        <LogoutTester />
      </AuthProvider>
    );

    await act(async () => {
      await Promise.resolve();
    });

    const btn = screen.getByRole('button', { name: 'Logout Button' });
    await act(async () => {
      fireEvent.click(btn);
    });

    expect(localStorage.getItem('sb-testref-auth-token')).toBeNull();
    expect(screen.getByTestId('session-status')).toHaveTextContent('logged-out');
  });

  it('si signOut local falla y getSession persiste tras borrar storage, muestra error y no aparenta haber cerrado', async () => {
    vi.mocked(powersyncDb.getActivePowerSyncDatabase).mockReturnValue({
      getUploadQueueStats: vi.fn().mockResolvedValue({ count: 0 }),
    } as any);

    // Session stubbornly remains in getSession
    vi.mocked(supabase.auth.signOut).mockImplementation(async () => {
      return { error: null };
    });
    vi.mocked(supabase.auth.getSession).mockResolvedValue({
      data: { session: { access_token: 'fake-token', user: { id: 'usr-123' } } as any },
      error: null,
    });

    render(
      <AuthProvider>
        <LogoutTester />
      </AuthProvider>
    );

    await act(async () => {
      await Promise.resolve();
    });

    const btn = screen.getByRole('button', { name: 'Logout Button' });
    await act(async () => {
      fireEvent.click(btn);
    });

    // Session is NOT cleared
    expect(screen.getByTestId('session-status')).toHaveTextContent('logged-in');
    // Error banner is displayed
    expect(screen.getByRole('alert')).toBeInTheDocument();
    expect(screen.getByText(/no se pudo cerrar la sesión completamente/i)).toBeInTheDocument();
  });

  it('si onAuthStateChange cambia de usuario sin logout, desconecta sin borrar y recarga', async () => {
    let authChangeCallback: any;
    vi.mocked(supabase.auth.onAuthStateChange).mockImplementation((cb: any) => {
      authChangeCallback = cb;
      return { data: { subscription: { unsubscribe: vi.fn() } } } as any;
    });

    const reloadMock = vi.fn();
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: { ...window.location, reload: reloadMock },
    });

    render(
      <AuthProvider>
        <LogoutTester />
      </AuthProvider>
    );

    await act(async () => {
      await Promise.resolve();
    });

    // Simulate login of user B in another tab
    await act(async () => {
      authChangeCallback('SIGNED_IN', {
        access_token: 'new-token',
        user: { id: 'usr-456', email: 'other@example.com' },
      });
    });

    expect(powersyncDb.disconnectPowerSync).toHaveBeenCalled();
    expect(powersyncDb.disconnectAndClearPowerSync).not.toHaveBeenCalled();
    expect(reloadMock).toHaveBeenCalled();
  });
});
