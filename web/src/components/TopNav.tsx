import React, { useEffect, useState } from 'react';
import { NavLink, Link } from 'react-router-dom';
import { motion, useReducedMotion } from 'motion/react';
import { SyncStatus } from './SyncStatus';
import { useAuth } from '@/lib/auth';
import { useTheme } from '@/lib/theme';
import { cn } from '@/lib/utils';

export function TopNav() {
  const [isScrolled, setIsScrolled] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const prefersReducedMotion = useReducedMotion();
  const { logout } = useAuth();
  const { theme, setTheme } = useTheme();

  const handleCreateMovement = () => {
    window.dispatchEvent(new CustomEvent('pockt:open-create-movement'));
  };

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 24);
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const navLinks = [
    { name: 'Inicio', path: '/' },
    { name: 'Movimientos', path: '/movimientos' },
    { name: 'Reportes', path: '/reportes' },
    { name: 'Préstamos', path: '/prestamos' },
    { name: 'Metas', path: '/metas' },
    { name: 'Presupuestos', path: '/presupuestos' },
  ];

  return (
    <>
      <motion.nav
        role="navigation"
        aria-label="Navegación principal"
        initial={false}
        animate={
          isScrolled
            ? {
                top: 14,
                width: 'min(940px, calc(100% - 32px))',
                height: 54,
                paddingLeft: 18,
                paddingRight: 10,
                borderRadius: 999,
                backgroundColor: 'var(--glass-fill)',
                borderColor: 'var(--glass-border)',
                backdropFilter: 'blur(18px) saturate(1.4)',
                boxShadow: '0 12px 40px rgba(0,0,0,0.45)',
              }
            : {
                top: 0,
                width: '100%',
                height: 68,
                paddingLeft: 32,
                paddingRight: 32,
                borderRadius: 0,
                backgroundColor: 'transparent',
                borderColor: 'transparent',
                backdropFilter: 'none',
                boxShadow: 'none',
              }
        }
        transition={
          prefersReducedMotion
            ? { duration: 0 }
            : {
                type: 'spring',
                stiffness: 280,
                damping: 30,
                mass: 0.8,
              }
        }
        className={cn(
          'fixed left-1/2 -translate-x-1/2 z-40 flex items-center justify-between border select-none transition-colors duration-200'
        )}
      >
        {/* Brand logo */}
        <Link
          to="/"
          className="flex items-center gap-2 font-extrabold text-[17px] tracking-tight text-text-primary hover:opacity-90 active:scale-95 transition-transform"
        >
          <img src="/pockt-icon.svg" alt="" width={24} height={24} className="w-6 h-6 rounded-lg block" />
          <span>Pockt</span>
        </Link>

        {/* Desktop nav links */}
        <div className="hidden md:flex items-center gap-0.5">
          {navLinks.map((link) => (
            <NavLink
              key={link.path}
              to={link.path}
              end={link.path === '/'}
              className={({ isActive }) =>
                cn(
                  'px-3.5 py-2 rounded-full text-[13.5px] font-semibold transition-all duration-150',
                  isActive
                    ? 'active-nav-link text-text-primary bg-white/10 shadow-sm'
                    : 'text-text-secondary hover:text-text-primary hover:bg-white/5'
                )
              }
            >
              {link.name}
            </NavLink>
          ))}
        </div>

        {/* Right tools and actions */}
        <div className="flex items-center gap-2 sm:gap-2.5">
          {/* Sync status (hides label on compact desktop pill) */}
          <div className={cn('hidden sm:flex transition-opacity duration-200')}>
            <SyncStatus />
          </div>

          {/* Settings / theme menu toggle */}
          <div className="relative">
            <button
              type="button"
              onClick={() => setSettingsOpen(!settingsOpen)}
              aria-label="Opciones de tema y cuenta"
              className="w-10 h-10 min-w-[40px] min-h-[40px] rounded-full grid place-items-center bg-glass-fill border border-glass-border text-text-secondary hover:text-text-primary transition-colors cursor-pointer"
            >
              <svg
                className="w-4 h-4"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
              >
                <circle cx="12" cy="12" r="3" />
                <path d="M12 3v2.5M12 18.5V21M3 12h2.5M18.5 12H21M5.6 5.6l1.8 1.8M16.6 16.6l1.8 1.8M5.6 18.4l1.8-1.8M16.6 7.4l1.8-1.8" />
              </svg>
            </button>

            {settingsOpen && (
              <div
                className="absolute right-0 top-12 w-48 rounded-2xl bg-sheet-surface border border-glass-border p-2 shadow-2xl z-50 animate-in fade-in zoom-in-95 duration-150"
                onClick={() => setSettingsOpen(false)}
              >
                <div className="px-2 py-1 text-[11px] font-bold text-text-tertiary uppercase tracking-wider">
                  Tema
                </div>
                <div className="flex gap-1 p-1 bg-white/5 rounded-xl border border-glass-border mb-2">
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      setTheme('system');
                    }}
                    className={cn(
                      'flex-1 min-h-[36px] py-1 rounded-lg text-[12px] font-medium transition-colors flex items-center justify-center',
                      theme === 'system' ? 'bg-white/15 text-text-primary font-bold' : 'text-text-tertiary hover:text-text-primary'
                    )}
                  >
                    Auto
                  </button>
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      setTheme('light');
                    }}
                    className={cn(
                      'flex-1 min-h-[36px] py-1 rounded-lg text-[12px] font-medium transition-colors flex items-center justify-center',
                      theme === 'light' ? 'bg-white/15 text-text-primary font-bold' : 'text-text-tertiary hover:text-text-primary'
                    )}
                  >
                    Claro
                  </button>
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      setTheme('dark');
                    }}
                    className={cn(
                      'flex-1 min-h-[36px] py-1 rounded-lg text-[12px] font-medium transition-colors flex items-center justify-center',
                      theme === 'dark' ? 'bg-white/15 text-text-primary font-bold' : 'text-text-tertiary hover:text-text-primary'
                    )}
                  >
                    Oscuro
                  </button>
                </div>

                <div className="h-px bg-glass-border my-1" />

                <button
                  type="button"
                  onClick={() => void logout()}
                  className="w-full text-left min-h-[40px] flex items-center px-2.5 py-1.5 rounded-xl text-[12.5px] font-medium text-danger hover:bg-danger/10 transition-colors cursor-pointer"
                >
                  Cerrar sesión
                </button>
              </div>
            )}
          </div>

          {/* Primary CTA button: "Cargar" */}
          <Link
            to="/movimientos?crear=1"
            onClick={handleCreateMovement}
            className="min-h-[40px] flex items-center gap-1.5 px-3.5 py-2 rounded-full font-bold text-[13px] text-white select-none shadow-sm active:scale-95 transition-transform cursor-pointer"
            style={{
              background: 'linear-gradient(90deg, var(--brand-start), var(--brand-end))',
            }}
          >
            <svg
              className="w-3.5 h-3.5"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.5"
              strokeLinecap="round"
            >
              <path d="M12 5v14M5 12h14" />
            </svg>
            <span>Cargar</span>
          </Link>

          {/* Mobile hamburger button (< 768px) */}
          <button
            type="button"
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            aria-label="Abrir menú de navegación"
            className="md:hidden w-10 h-10 min-w-[40px] min-h-[40px] rounded-full grid place-items-center bg-glass-fill border border-glass-border text-text-secondary hover:text-text-primary transition-colors cursor-pointer"
          >
            <svg
              className="w-4 h-4"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
            >
              {mobileMenuOpen ? (
                <path d="M18 6L6 18M6 6l12 12" />
              ) : (
                <path d="M4 6h16M4 12h16M4 18h16" />
              )}
            </svg>
          </button>
        </div>
      </motion.nav>

      {/* Mobile Drawer Overlay */}
      {mobileMenuOpen && (
        <div
          data-testid="mobile-menu"
          className="fixed inset-0 z-30 bg-background/80 backdrop-blur-md pt-20 px-6 pb-8 flex flex-col md:hidden animate-in fade-in duration-200"
        >
          <div className="flex flex-col gap-1 mt-4">
            {navLinks.map((link) => (
              <NavLink
                key={link.path}
                to={link.path}
                end={link.path === '/'}
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  cn(
                    'px-4 py-3 rounded-2xl text-[16px] font-semibold transition-colors',
                    isActive
                      ? 'bg-white/10 text-text-primary'
                      : 'text-text-secondary hover:text-text-primary'
                  )
                }
              >
                {link.name}
              </NavLink>
            ))}
          </div>

          <div className="mt-auto pt-6 border-t border-glass-border flex flex-col gap-4">
            <div className="flex items-center justify-between">
              <span className="text-[13px] text-text-tertiary">Estado:</span>
              <SyncStatus />
            </div>

            <button
              type="button"
              onClick={() => {
                setMobileMenuOpen(false);
                void logout();
              }}
              className="w-full py-3 rounded-xl border border-danger/30 text-danger text-[14px] font-bold text-center hover:bg-danger/10 transition-colors"
            >
              Cerrar sesión
            </button>
          </div>
        </div>
      )}
    </>
  );
}
