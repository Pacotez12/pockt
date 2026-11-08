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
  beforeEach(() => {
    vi.clearAllMocks();
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
});
