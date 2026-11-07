import React, { useEffect, useState } from 'react';
import { motion, useReducedMotion } from 'motion/react';
import { AuroraShader } from '@/components/AuroraShader';
import { CountUp } from '@/components/CountUp';
import { supabase } from '@/lib/supabase';

export function LoginRoute() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const prefersReduced = useReducedMotion();

  useEffect(() => {
    document.title = 'Entrar · Pockt';

    let meta = document.querySelector('meta[name="description"]');
    let created = false;
    if (!meta) {
      meta = document.createElement('meta');
      meta.setAttribute('name', 'description');
      document.head.appendChild(meta);
      created = true;
    }
    meta.setAttribute(
      'content',
      'Pockt web: tus finanzas personales sincronizadas en vivo con tu teléfono. Cargá, editá y descargá reportes desde la compu.'
    );

    return () => {
      if (created && meta && meta.parentNode) {
        meta.parentNode.removeChild(meta);
      }
    };
  }, []);

  const handleGoogleLogin = async () => {
    setLoading(true);
    setError(null);
    try {
      const redirectUrl =
        typeof window !== 'undefined'
          ? `${window.location.origin}/`
          : 'http://localhost:5173/';

      const { error: signInError } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: redirectUrl,
        },
      });

      if (signInError) throw signInError;
    } catch (err: any) {
      setError(err?.message || 'Error al iniciar sesión con Google');
      setLoading(false);
    }
  };

  const springTransition = prefersReduced
    ? { duration: 0 }
    : {
        type: 'spring' as const,
        stiffness: 260,
        damping: 24,
      };

  return (
    <div className="min-h-screen relative isolate overflow-hidden bg-black text-white flex flex-col justify-between selection:bg-brand-start/20">
      {/* Background WebGL Shader & Vignette */}
      <AuroraShader opacity={1} interactive />

      {/* Top brand */}
      <header className="pt-8 px-8 sm:px-14 flex items-center gap-3 relative z-10">
        <img
          src="/pockt-icon.svg"
          alt=""
          width={38}
          height={38}
          className="rounded-[11px] shadow-lg shadow-brand-end/30"
        />
        <span className="font-extrabold text-[19px] tracking-tight text-white">Pockt</span>
      </header>

      {/* Main split grid */}
      <main className="flex-1 max-w-[1240px] w-full mx-auto px-6 sm:px-14 py-8 sm:py-12 grid grid-cols-1 lg:grid-cols-[1.15fr_0.85fr] items-center gap-10 lg:gap-14 relative z-10">
        {/* Left column: hero + floating cards */}
        <div>
          <h1 className="text-[42px] sm:text-[56px] lg:text-[58px] font-black leading-[1.03] tracking-[-0.035em] text-white">
            Tu plata,<br />
            ahora también<br />
            en <span className="text-[#FF8A3D]">pantalla grande.</span>
          </h1>

          <p className="mt-4 sm:mt-5 text-[16px] sm:text-[17px] leading-relaxed text-white/70 max-w-[480px]">
            Lo mismo que cargás en el teléfono, en la compu y al instante. Más reportes, más
            detalle, descargas en Excel y PDF.
          </p>

          {/* Floating cards stack */}
          <div className="relative h-[250px] mt-8 max-w-[520px]">
            {/* Card 1: Gastado en noviembre */}
            <motion.div
              initial={prefersReduced ? false : { opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ ...springTransition, delay: 0.35 }}
              className="absolute left-0 top-2.5 w-[250px] rounded-[18px] p-4 bg-[#121214]/65 backdrop-blur-md border border-white/10 shadow-2xl shadow-black/50"
            >
              <small className="text-white/45 text-[11.5px] block font-medium">
                Gastado en noviembre
              </small>
              <b className="text-[22px] font-extrabold tracking-tight whitespace-nowrap block mt-0.5">
                <CountUp value={1240500} />
              </b>
              {/* Spark bars */}
              <div className="flex items-end gap-1 h-[34px] mt-2">
                {[40, 65, 35, 80, 55, 95, 60].map((h, i) => (
                  <motion.i
                    key={i}
                    initial={prefersReduced ? false : { scaleY: 0 }}
                    animate={{ scaleY: 1 }}
                    transition={{
                      delay: prefersReduced ? 0 : 0.45 + i * 0.05,
                      duration: prefersReduced ? 0 : 0.6,
                      ease: [0.2, 0.9, 0.25, 1.2],
                    }}
                    style={{
                      height: `${h}%`,
                      background: 'linear-gradient(180deg, var(--brand-end), var(--brand-start))',
                      transformOrigin: 'bottom',
                    }}
                    className="flex-1 rounded-[3px] block"
                  />
                ))}
              </div>
            </motion.div>

            {/* Card 2: Café Martínez */}
            <motion.div
              initial={prefersReduced ? false : { opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ ...springTransition, delay: 0.51 }}
              className="absolute left-[160px] sm:left-[205px] top-[92px] w-[300px] sm:w-[320px] rounded-[18px] p-3.5 sm:p-4 bg-[#121214]/65 backdrop-blur-md border border-white/10 shadow-2xl shadow-black/50"
            >
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-[10px] grid place-items-center bg-brand-start/15 text-brand-start shrink-0">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M3 11h18M5 11V8a7 7 0 0 1 14 0v3M6 11l1 9h10l1-9" />
                  </svg>
                </div>
                <div className="flex-1 min-w-0">
                  <div className="font-semibold text-[14px] text-white truncate">Café Martínez</div>
                  <div className="flex items-center gap-1.5 text-[12px] text-white/65">
                    <span className="w-2 h-2 rounded-full bg-positive shrink-0 animate-pulse" />
                    <span className="truncate">Desde el teléfono · recién</span>
                  </div>
                </div>
                <b className="text-[16px] font-extrabold whitespace-nowrap text-white">Gs. 45.000</b>
              </div>
            </motion.div>

            {/* Card 3: Préstamo Itaú */}
            <motion.div
              initial={prefersReduced ? false : { opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ ...springTransition, delay: 0.67 }}
              className="absolute left-8 sm:left-10 top-[168px] w-[230px] rounded-[18px] p-3.5 sm:p-4 bg-[#121214]/65 backdrop-blur-md border border-white/10 shadow-2xl shadow-black/50"
            >
              <small className="text-white/45 text-[11.5px] block font-medium">Préstamo Itaú</small>
              <b className="text-[17px] font-extrabold tracking-tight block mt-0.5">Cuota 4 de 36</b>
              <div className="h-1.5 rounded-full bg-white/10 mt-2.5 overflow-hidden">
                <div
                  className="w-[11%] h-full rounded-full"
                  style={{
                    background: 'linear-gradient(90deg, var(--brand-start), var(--brand-end))',
                  }}
                />
              </div>
            </motion.div>
          </div>
        </div>

        {/* Right column: login action card */}
        <motion.div
          initial={prefersReduced ? false : { opacity: 0, y: 18, scale: 0.985 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={{ ...springTransition, delay: 0.15 }}
          className="lg:justify-self-end w-full max-w-[380px] p-7 sm:p-8 rounded-[26px] bg-[#101012]/60 backdrop-blur-xl border border-white/10 shadow-2xl shadow-black/60"
        >
          <h2 className="text-[24px] font-bold tracking-tight text-white">Entrá a Pockt</h2>
          <p className="text-[14px] leading-relaxed text-white/65 mt-2">
            Usá la misma cuenta de Google que en la app.
          </p>

          {error && (
            <div
              role="alert"
              className="mt-4 p-3 rounded-xl text-[12.5px] border border-danger/30 bg-danger/10 text-danger"
            >
              {error}
            </div>
          )}

          <button
            type="button"
            disabled={loading}
            onClick={handleGoogleLogin}
            className="w-full mt-6 flex items-center justify-center gap-2.5 px-4 py-3.5 rounded-[15px] bg-white text-[#111] font-bold text-[15px] transition-all hover:-translate-y-0.5 hover:shadow-lg hover:shadow-white/15 active:scale-[0.98] disabled:opacity-60 cursor-pointer"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" aria-hidden="true">
              <path
                fill="#4285F4"
                d="M22 12.2c0-.7-.1-1.4-.2-2H12v3.8h5.6a4.8 4.8 0 0 1-2.1 3.1v2.6h3.4c2-1.8 3.1-4.5 3.1-7.5z"
              />
              <path
                fill="#34A853"
                d="M12 22c2.8 0 5.2-.9 6.9-2.5l-3.4-2.6c-.9.6-2.1 1-3.5 1-2.7 0-5-1.8-5.8-4.3H2.7v2.7A10 10 0 0 0 12 22z"
              />
              <path
                fill="#FBBC05"
                d="M6.2 13.6a6 6 0 0 1 0-3.8V7.1H2.7a10 10 0 0 0 0 9.2z"
              />
              <path
                fill="#EA4335"
                d="M12 5.9c1.5 0 2.9.5 4 1.5l3-3A10 10 0 0 0 2.7 7.1l3.5 2.7C7 7.7 9.3 5.9 12 5.9z"
              />
            </svg>
            {loading ? 'Conectando…' : 'Continuar con Google'}
          </button>

          <div className="text-[12.5px] text-white/45 mt-2.5 text-center">
            Si todavía no activaste "Sincronizar con la web" en la app, hacelo primero.
          </div>

          <div className="h-px bg-white/10 my-5" />

          <div className="flex items-start gap-2.5 text-[12.5px] text-white/65 leading-relaxed">
            <svg
              className="w-4 h-4 text-brand-start shrink-0 mt-0.5"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
            >
              <rect x="5" y="11" width="14" height="9" rx="2" />
              <path d="M8 11V8a4 4 0 0 1 8 0v3" />
            </svg>
            <span>Solo vos ves tus datos. Esta página no aparece en buscadores.</span>
          </div>
        </motion.div>
      </main>

      {/* Footer */}
      <footer className="pb-6 px-8 sm:px-14 flex flex-col sm:flex-row justify-between items-center gap-2 text-[12px] text-white/45 relative z-10">
        <span>Pockt · finanzas personales</span>
        <span>Sincroniza con la app al instante</span>
      </footer>
    </div>
  );
}
