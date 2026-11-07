import React, { Component, ErrorInfo, ReactNode } from 'react';
import { Link } from 'react-router-dom';

export interface ErrorBoundaryProps {
  children: ReactNode;
  fallback?: ReactNode;
  onReset?: () => void;
}

interface ErrorBoundaryState {
  hasError: boolean;
  errorKey: number;
}

export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  public state: ErrorBoundaryState = {
    hasError: false,
    errorKey: 0,
  };

  public static getDerivedStateFromError(): Partial<ErrorBoundaryState> {
    return { hasError: true };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
    // Registra en consola el mensaje y stack técnico sin datos personales del usuario
    console.error('[Pockt ErrorBoundary] Error capturado:', error.message, {
      componentStack: errorInfo.componentStack,
    });
  }

  private handleRetry = (): void => {
    if (this.props.onReset) {
      this.props.onReset();
    }
    this.setState((prev) => ({
      hasError: false,
      errorKey: prev.errorKey + 1,
    }));
  };

  public render(): ReactNode {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback;
      }

      return (
        <div
          role="alert"
          className="w-full min-h-[360px] flex flex-col items-center justify-center p-8 text-center select-none"
        >
          <div className="w-full max-w-md p-8 rounded-3xl bg-sheet-surface/80 backdrop-blur-xl border border-glass-border shadow-2xl flex flex-col items-center">
            {/* Logo Pockt */}
            <div
              className="w-12 h-12 rounded-2xl flex items-center justify-center mb-6 shadow-lg shadow-brand-end/20"
              style={{
                background: 'linear-gradient(135deg, var(--brand-start), var(--brand-end))',
              }}
            >
              <svg
                className="w-6 h-6 text-white"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <circle cx="12" cy="12" r="10" />
                <line x1="12" y1="8" x2="12" y2="12" />
                <line x1="12" y1="16" x2="12.01" y2="16" />
              </svg>
            </div>

            <h2 className="text-2xl font-extrabold tracking-tight text-text-primary mb-2">
              Algo salió mal
            </h2>
            <p className="text-sm text-text-secondary leading-relaxed mb-6">
              Ocurrió un problema inesperado al cargar esta sección. Tus datos están a salvo.
            </p>

            <div className="flex flex-wrap items-center justify-center gap-3 w-full">
              <button
                type="button"
                onClick={this.handleRetry}
                className="px-5 py-2.5 rounded-full font-bold text-sm text-white cursor-pointer transition-transform active:scale-95 shadow-md hover:opacity-95"
                style={{
                  background: 'linear-gradient(90deg, var(--brand-start), var(--brand-end))',
                }}
              >
                Reintentar
              </button>

              <Link
                to="/"
                onClick={this.handleRetry}
                className="px-5 py-2.5 rounded-full font-semibold text-sm text-text-primary bg-glass-fill border border-glass-border hover:bg-white/10 transition-colors"
              >
                Ir al Inicio
              </Link>
            </div>
          </div>
        </div>
      );
    }

    return (
      <React.Fragment key={this.state.errorKey}>
        {this.props.children}
      </React.Fragment>
    );
  }
}
