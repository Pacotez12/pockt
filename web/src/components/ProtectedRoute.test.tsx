import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import React from 'react';
import { ProtectedRoute } from './ProtectedRoute';
import { AuthContext, type AuthContextValue } from '@/lib/auth';
import { usePowerSync } from '@powersync/react';

vi.mock('@/lib/powersync/db', () => ({
  getPowerSyncDatabase: () => ({ fake: 'db' }),
  connectPowerSync: () => Promise.resolve(),
}));

// Una pantalla privada que, como Inicio, necesita la base local al dibujarse.
function NeedsDb() {
  const db = usePowerSync();
  if (!db) throw new Error('PowerSync not configured');
  return <div>Contenido Privado</div>;
}

describe('ProtectedRoute', () => {
  const renderWithAuth = (authValue: AuthContextValue, initialPath = '/protected') => {
    return render(
      <AuthContext.Provider value={authValue}>
        <MemoryRouter initialEntries={[initialPath]}>
          <Routes>
            <Route path="/login" element={<div>Pantalla Login</div>} />
            <Route element={<ProtectedRoute />}>
              <Route path="/protected" element={<NeedsDb />} />
            </Route>
          </Routes>
        </MemoryRouter>
      </AuthContext.Provider>
    );
  };

  it('shows loading indicator while checking auth session', () => {
    renderWithAuth({
      session: null,
      user: null,
      loading: true,
      logout: vi.fn(),
    });

    expect(screen.getByTestId('auth-loading')).toBeInTheDocument();
    expect(screen.queryByText('Contenido Privado')).not.toBeInTheDocument();
  });

  it('redirects to /login when there is no active session', () => {
    renderWithAuth({
      session: null,
      user: null,
      loading: false,
      logout: vi.fn(),
    });

    expect(screen.getByText('Pantalla Login')).toBeInTheDocument();
    expect(screen.queryByText('Contenido Privado')).not.toBeInTheDocument();
  });

  it('renders protected content when user has active session', async () => {
    renderWithAuth({
      session: { user: { id: 'usr-1' } } as any,
      user: { id: 'usr-1' } as any,
      loading: false,
      logout: vi.fn(),
    });

    expect(await screen.findByText('Contenido Privado')).toBeInTheDocument();
    expect(screen.queryByText('Pantalla Login')).not.toBeInTheDocument();
  });
});
