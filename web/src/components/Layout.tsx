import React from 'react';
import { Outlet } from 'react-router-dom';
import { TopNav } from './TopNav';
import { AuroraShader } from './AuroraShader';

export function Layout() {
  return (
    <div className="min-h-screen relative isolate flex flex-col">
      {/* Fondo vivo muy tenue detrás de las pantallas privadas */}
      <AuroraShader opacity={0.35} interactive={false} />
      <TopNav />
      <main className="flex-1 w-full max-w-[1180px] mx-auto px-4 sm:px-8 pt-24 pb-16">
        <Outlet />
      </main>
    </div>
  );
}
