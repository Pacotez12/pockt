import { describe, it, expect, vi, beforeEach } from 'vitest';
import { supabase } from './supabase';
import * as powersyncDb from './powersync/db';
import { AuthProvider, useAuth } from './auth';
import { renderHook, act } from '@testing-library/react';
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
  connectPowerSync: vi.fn(),
}));

describe('AuthContext logout', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('calls disconnectAndClearPowerSync and supabase.auth.signOut on logout', async () => {
    const wrapper = ({ children }: { children: React.ReactNode }) => (
      <AuthProvider>{children}</AuthProvider>
    );

    const { result } = renderHook(() => useAuth(), { wrapper });

    await act(async () => {
      await Promise.resolve();
    });

    await act(async () => {
      await result.current.logout();
    });

    expect(powersyncDb.disconnectAndClearPowerSync).toHaveBeenCalled();
    expect(supabase.auth.signOut).toHaveBeenCalled();
    expect(result.current.session).toBeNull();
  });
});
