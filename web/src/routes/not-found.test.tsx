import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import React from 'react';
import { NotFoundRoute } from './not-found';

describe('NotFoundRoute', () => {
  it('renders 404 message and links to home and movements', () => {
    render(
      <MemoryRouter>
        <NotFoundRoute />
      </MemoryRouter>
    );

    expect(screen.getByText('404')).toBeInTheDocument();
    expect(screen.getByText('Esta página no existe')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Volver al Inicio' })).toHaveAttribute('href', '/');
    expect(screen.getByRole('link', { name: 'Ver movimientos' })).toHaveAttribute('href', '/movimientos');
    expect(document.title).toBe('Página no encontrada · Pockt');
  });
});
