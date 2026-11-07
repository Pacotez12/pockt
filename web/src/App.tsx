import React, { Suspense, lazy } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider } from '@/lib/theme';
import { AuthProvider } from '@/lib/auth';
import { ProtectedRoute } from '@/components/ProtectedRoute';
import { Layout } from '@/components/Layout';
import { ErrorBoundary } from '@/components/ErrorBoundary';
import { LoginRoute } from '@/routes/login';
import { InicioRoute } from '@/routes/inicio';
import { MovimientosRoute } from '@/routes/movimientos';
// Reportes trae three.js y jspdf: se carga solo al entrar a la ruta.
const ReportesRoute = lazy(() =>
  import('@/routes/reportes').then((m) => ({ default: m.ReportesRoute })),
);
import { PrestamosRoute } from '@/routes/prestamos';
import { PrestamoDetalleRoute } from '@/routes/prestamo-detalle';
import { MetasRoute } from '@/routes/metas';
import { PresupuestosRoute } from '@/routes/presupuestos';
import { NotFoundRoute } from '@/routes/not-found';

export function App() {
  return (
    <ThemeProvider>
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route
              path="/login"
              element={
                <ErrorBoundary>
                  <LoginRoute />
                </ErrorBoundary>
              }
            />

            <Route element={<ProtectedRoute />}>
              <Route element={<Layout />}>
                <Route path="/" element={<InicioRoute />} />
                <Route path="/inicio" element={<Navigate to="/" replace />} />
                <Route path="/movimientos" element={<MovimientosRoute />} />
                <Route
                  path="/reportes"
                  element={
                    <Suspense fallback={null}>
                      <ReportesRoute />
                    </Suspense>
                  }
                />
                <Route path="/prestamos" element={<PrestamosRoute />} />
                <Route path="/prestamos/:id" element={<PrestamoDetalleRoute />} />
                <Route path="/metas" element={<MetasRoute />} />
                <Route path="/presupuestos" element={<PresupuestosRoute />} />
              </Route>
            </Route>

            <Route path="*" element={<NotFoundRoute />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </ThemeProvider>
  );
}
