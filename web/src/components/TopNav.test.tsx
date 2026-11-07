import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import React from 'react';
import { TopNav } from './TopNav';
import { AuthContext } from '@/lib/auth';
import { ThemeProvider } from '@/lib/theme';

describe('TopNav', () => {
  const mockLogout = vi.fn();

  const renderTopNav = (initialPath = '/') => {
    return render(
      <AuthContext.Provider
        value={{
          session: { user: { id: 'u1', email: 'test@example.com' } } as any,
          user: { id: 'u1', email: 'test@example.com' } as any,
          loading: false,
          logout: mockLogout,
        }}
      >
        <ThemeProvider>
          <MemoryRouter initialEntries={[initialPath]}>
            <TopNav />
          </MemoryRouter>
        </ThemeProvider>
      </AuthContext.Provider>
    );
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders logo, navigation links, and "+ Cargar" button disabled with tooltip', () => {
    renderTopNav('/movimientos');

    expect(screen.getByText('Pockt')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Inicio' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Movimientos' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Reportes' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Préstamos' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Metas' })).toBeInTheDocument();

    const ctaButton = screen.getByRole('button', { name: /Cargar/i });
    expect(ctaButton).toBeDisabled();
    expect(ctaButton).toHaveAttribute('title', expect.stringContaining('etapa 4'));
  });

  it('highlights the active link according to current location', () => {
    renderTopNav('/movimientos');

    const movLink = screen.getByRole('link', { name: 'Movimientos' });
    expect(movLink.className).toContain('active-nav-link');
  });

  it('renders mobile menu button on small screens and allows opening drawer', () => {
    renderTopNav('/');

    const menuButton = screen.getByLabelText('Abrir menú de navegación');
    expect(menuButton).toBeInTheDocument();

    fireEvent.click(menuButton);
    expect(screen.getByTestId('mobile-menu')).toBeInTheDocument();
  });
});
