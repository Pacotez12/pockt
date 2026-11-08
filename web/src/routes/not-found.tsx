import React, { useEffect } from 'react';
import { Link } from 'react-router-dom';
import { AuroraBackground } from '@/components/AuroraBackground';

export function NotFoundRoute() {
  useEffect(() => {
    document.title = 'Página no encontrada · Pockt';
  }, []);

  return (
    <div className="min-h-screen flex items-center justify-center p-6 relative">
      <AuroraBackground />
      <div className="text-center max-w-[380px] w-full">
        <div className="text-[96px] font-extrabold leading-none tracking-tight text-white/15 dark:text-white/12 select-none">
          404
        </div>
        <h1 className="text-[22px] font-extrabold mt-2 tracking-tight text-text-primary">
          Esta página no existe
        </h1>
        <p className="text-[14px] leading-relaxed mt-2 text-text-secondary">
          Puede que el enlace esté mal o que la hayas borrado. Tus datos están bien.
        </p>
        <div className="flex items-center justify-center gap-3 mt-6">
          <Link
            to="/"
            className="min-h-[40px] inline-flex items-center justify-center px-5 py-2.5 rounded-full font-bold text-[13.5px] text-white shadow-lg shadow-brand-end/20 transition-transform active:scale-95"
            style={{
              background: 'linear-gradient(90deg, var(--brand-start), var(--brand-end))',
            }}
          >
            Volver al Inicio
          </Link>
          <Link
            to="/movimientos"
            className="min-h-[40px] inline-flex items-center justify-center px-4 py-2.5 rounded-full font-semibold text-[13px] border border-glass-border bg-glass-fill text-text-secondary hover:text-text-primary transition-colors active:scale-95"
          >
            Ver movimientos
          </Link>
        </div>
      </div>
    </div>
  );
}
