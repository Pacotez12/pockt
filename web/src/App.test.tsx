import { describe, it, expect, vi } from 'vitest';
import { render } from '@testing-library/react';
import React from 'react';
import { App } from './App';

vi.mock('@/lib/supabase', () => ({
  supabase: {
    auth: {
      getSession: vi.fn().mockResolvedValue({ data: { session: null } }),
      onAuthStateChange: vi.fn().mockReturnValue({
        data: { subscription: { unsubscribe: vi.fn() } },
      }),
      signInWithOAuth: vi.fn(),
    },
  },
  isSupabaseConfigured: true,
}));

describe('App', () => {
  it('renders without throwing', () => {
    const { container } = render(<App />);
    expect(container).toBeInTheDocument();
  });
});
