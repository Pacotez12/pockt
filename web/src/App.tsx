import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider } from '@/lib/theme';
import { AuthProvider } from '@/lib/auth';
import { ProtectedRoute } from '@/components/ProtectedRoute';
import { Layout } from '@/components/Layout';
import { LoginRoute } from '@/routes/login';
import { InicioRoute } from '@/routes/inicio';
import { MovimientosRoute } from '@/routes/movimientos';
import { SectionPlaceholderRoute } from '@/routes/section-placeholder';
import { NotFoundRoute } from '@/routes/not-found';

export function App() {
  return (
    <ThemeProvider>
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route path="/login" element={<LoginRoute />} />

            <Route element={<ProtectedRoute />}>
              <Route element={<Layout />}>
                <Route path="/" element={<InicioRoute />} />
                <Route path="/inicio" element={<Navigate to="/" replace />} />
                <Route path="/movimientos" element={<MovimientosRoute />} />
                <Route
                  path="/reportes"
                  element={<SectionPlaceholderRoute title="Reportes" stage="etapa 5" />}
                />
                <Route
                  path="/prestamos"
                  element={<SectionPlaceholderRoute title="Préstamos" stage="etapa 6" />}
                />
                <Route
                  path="/metas"
                  element={<SectionPlaceholderRoute title="Metas" stage="etapa 6" />}
                />
              </Route>
            </Route>

            <Route path="*" element={<NotFoundRoute />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </ThemeProvider>
  );
}
