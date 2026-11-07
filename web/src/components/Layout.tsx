import React from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import { TopNav } from './TopNav';
import { AuroraShader } from './AuroraShader';
import { ErrorBoundary } from './ErrorBoundary';

export function Layout() {
  const location = useLocation();
  return (
    <div className="min-h-screen relative isolate flex flex-col">
      {/* Fondo vivo muy tenue detrás de las pantallas privadas */}
      <AuroraShader opacity={0.35} interactive={false} />
      <TopNav />
      <main className="flex-1 w-full max-w-[1180px] mx-auto px-4 sm:px-8 pt-24 pb-16">
        {/* key: al cambiar de pantalla el error se limpia solo */}
        <ErrorBoundary key={location.pathname}>
          <Outlet />
        </ErrorBoundary>
      </main>
    </div>
  );
}
