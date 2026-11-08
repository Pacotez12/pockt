import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import React from 'react';
import { LoginRoute } from './login';
import { supabase } from '@/lib/supabase';

vi.mock('@/lib/supabase', () => ({
  supabase: {
    auth: {
      signInWithOAuth: vi.fn().mockResolvedValue({ error: null }),
    },
  },
  isSupabaseConfigured: true,
}));

describe('LoginRoute', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders login screen according to propuesta-2b-login with meta description', () => {
    render(<LoginRoute />);

    expect(screen.getByText('Pockt')).toBeInTheDocument();
    expect(screen.getByText(/Tu plata/i)).toBeInTheDocument();
    expect(screen.getByText(/pantalla grande/i)).toBeInTheDocument();
    expect(screen.getByText(/Gastado en noviembre/i)).toBeInTheDocument();
    expect(screen.getByText('Café Martínez')).toBeInTheDocument();
    expect(screen.getByText('Préstamo Itaú')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Continuar con Google/i })).toBeInTheDocument();
    expect(
      screen.getByText('Solo vos ves tus datos. Esta página no aparece en buscadores.')
    ).toBeInTheDocument();

    const meta = document.querySelector('meta[name="description"]');
    expect(meta).not.toBeNull();
    expect(meta?.getAttribute('content')).toContain('Pockt');
    expect(document.title).toBe('Entrar · Pockt');
  });

  it('triggers signInWithOAuth when clicking Continuar con Google', async () => {
    render(<LoginRoute />);

    const button = screen.getByRole('button', { name: /Continuar con Google/i });
    fireEvent.click(button);

    expect(supabase.auth.signInWithOAuth).toHaveBeenCalledWith({
      provider: 'google',
      options: {
        redirectTo: expect.stringMatching(/\/$/),
      },
    });
  });

  it('shows configuration error message when Supabase environment variables are missing', async () => {
    const supabaseModule = await import('@/lib/supabase');
    const origConfigured = supabaseModule.isSupabaseConfigured;
    (supabaseModule as any).isSupabaseConfigured = false;

    render(<LoginRoute />);

    expect(
      screen.getByText(/Falta configurar las variables de entorno de Supabase/i)
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Continuar con Google/i })).not.toBeInTheDocument();

    (supabaseModule as any).isSupabaseConfigured = origConfigured;
  });

  it('hides decorative floating cards on mobile viewports (< 768px)', () => {
    render(<LoginRoute />);
    const floatingContainer = screen.getByTestId('login-floating-cards');
    expect(floatingContainer).toHaveClass('hidden');
    expect(floatingContainer).toHaveClass('md:block');
  });
});
