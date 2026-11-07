import React, { createContext, useContext, useEffect, useState } from 'react';

export type Theme = 'system' | 'light' | 'dark';

export interface ThemeContextValue {
  theme: Theme;
  resolvedTheme: 'light' | 'dark';
  setTheme: (theme: Theme) => void;
}

export const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

const STORAGE_KEY = 'pockt_theme';

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(() => {
    if (typeof localStorage === 'undefined') return 'system';
    const saved = localStorage.getItem(STORAGE_KEY) as Theme | null;
    if (saved === 'light' || saved === 'dark' || saved === 'system') {
      return saved;
    }
    return 'system';
  });

  const [resolvedTheme, setResolvedTheme] = useState<'light' | 'dark'>(() => {
    if (theme === 'system') {
      return typeof window !== 'undefined' && window.matchMedia?.('(prefers-color-scheme: dark)')?.matches
        ? 'dark'
        : 'light';
    }
    return theme;
  });

  useEffect(() => {
    const media =
      typeof window !== 'undefined' && window.matchMedia
        ? window.matchMedia('(prefers-color-scheme: dark)')
        : null;

    const updateResolved = () => {
      const isDark = media?.matches ?? true;
      const active = theme === 'system' ? (isDark ? 'dark' : 'light') : theme;
      setResolvedTheme(active);
      const root = document.documentElement;
      root.classList.remove('light', 'dark');
      root.classList.add(active);
      root.style.colorScheme = active;
    };

    updateResolved();

    const listener = () => {
      if (theme === 'system') {
        updateResolved();
      }
    };

    media?.addEventListener?.('change', listener);
    return () => media?.removeEventListener?.('change', listener);
  }, [theme]);

  const setTheme = (next: Theme) => {
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem(STORAGE_KEY, next);
    }
    setThemeState(next);
  };

  return (
    <ThemeContext.Provider value={{ theme, resolvedTheme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme(): ThemeContextValue {
  const context = useContext(ThemeContext);
  if (!context) {
    return {
      theme: 'system',
      resolvedTheme: 'dark',
      setTheme: () => {},
    };
  }
  return context;
}
