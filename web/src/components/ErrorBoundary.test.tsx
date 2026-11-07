import React, { useState } from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { ErrorBoundary } from './ErrorBoundary';

function BuggyComponent({ shouldThrow }: { shouldThrow: boolean }) {
  if (shouldThrow) {
    throw new Error('Test crash in child component');
  }
  return <div>Componente sano y salvo</div>;
}

function WrapperWithReset() {
  const [shouldThrow, setShouldThrow] = useState(true);
  return (
    <MemoryRouter>
      <ErrorBoundary onReset={() => setShouldThrow(false)}>
        <BuggyComponent shouldThrow={shouldThrow} />
      </ErrorBoundary>
    </MemoryRouter>
  );
}

describe('ErrorBoundary', () => {
  let consoleErrorSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    // Suppress React's default error output in test console
    consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    consoleErrorSpy.mockRestore();
  });

  it('renders children when there is no error', () => {
    render(
      <MemoryRouter>
        <ErrorBoundary>
          <div>Contenido normal</div>
        </ErrorBoundary>
      </MemoryRouter>
    );
    expect(screen.getByText('Contenido normal')).toBeInTheDocument();
  });

  it('catches render error, displays "Algo salió mal", "Reintentar" and "Ir al Inicio"', () => {
    render(
      <MemoryRouter>
        <ErrorBoundary>
          <BuggyComponent shouldThrow={true} />
        </ErrorBoundary>
      </MemoryRouter>
    );

    expect(screen.getByText('Algo salió mal')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /reintentar/i })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /ir al inicio/i })).toBeInTheDocument();
  });

  it('clicking "Reintentar" resets error boundary and remounts child', () => {
    render(<WrapperWithReset />);

    expect(screen.getByText('Algo salió mal')).toBeInTheDocument();

    const retryBtn = screen.getByRole('button', { name: /reintentar/i });
    fireEvent.click(retryBtn);

    expect(screen.queryByText('Algo salió mal')).not.toBeInTheDocument();
    expect(screen.getByText('Componente sano y salvo')).toBeInTheDocument();
  });

  it('logs error to console without sensitive user data', () => {
    render(
      <MemoryRouter>
        <ErrorBoundary>
          <BuggyComponent shouldThrow={true} />
        </ErrorBoundary>
      </MemoryRouter>
    );

    expect(consoleErrorSpy).toHaveBeenCalled();
    const calls = consoleErrorSpy.mock.calls.flat();
    const joined = calls.join(' ');
    expect(joined).toContain('Test crash in child component');
    // Ensure no auth tokens or emails are being logged
    expect(joined).not.toContain('password');
    expect(joined).not.toContain('token');
  });
});
