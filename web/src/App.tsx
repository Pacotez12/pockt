import React, { Suspense, lazy } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider } from '@/lib/theme';
import { AuthProvider } from '@/lib/auth';
import { ErrorBoundary } from '@/components/ErrorBoundary';
import { RouteSpinner } from '@/components/RouteSpinner';
const LoginRoute = lazy(() =>
  import('@/routes/login').then((m) => ({ default: m.LoginRoute }))
);

const ProtectedRoute = lazy(() =>
  import('@/components/ProtectedRoute').then((m) => ({ default: m.ProtectedRoute }))
);
const Layout = lazy(() =>
  import('@/components/Layout').then((m) => ({ default: m.Layout }))
);

const InicioRoute = lazy(() =>
  import('@/routes/inicio').then((m) => ({ default: m.InicioRoute }))
);
const MovimientosRoute = lazy(() =>
  import('@/routes/movimientos').then((m) => ({ default: m.MovimientosRoute }))
);
const ReportesRoute = lazy(() =>
  import('@/routes/reportes').then((m) => ({ default: m.ReportesRoute }))
);
const PrestamosRoute = lazy(() =>
  import('@/routes/prestamos').then((m) => ({ default: m.PrestamosRoute }))
);
const PrestamoDetalleRoute = lazy(() =>
  import('@/routes/prestamo-detalle').then((m) => ({ default: m.PrestamoDetalleRoute }))
);
const MetasRoute = lazy(() =>
  import('@/routes/metas').then((m) => ({ default: m.MetasRoute }))
);
const PresupuestosRoute = lazy(() =>
  import('@/routes/presupuestos').then((m) => ({ default: m.PresupuestosRoute }))
);
const NotFoundRoute = lazy(() =>
  import('@/routes/not-found').then((m) => ({ default: m.NotFoundRoute }))
);

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
                  <Suspense fallback={<RouteSpinner />}>
                    <LoginRoute />
                  </Suspense>
                </ErrorBoundary>
              }
            />

            <Route
              element={
                <Suspense fallback={<RouteSpinner />}>
                  <ProtectedRoute />
                </Suspense>
              }
            >
              <Route
                element={
                  <Suspense fallback={<RouteSpinner />}>
                    <Layout />
                  </Suspense>
                }
              >
                <Route path="/" element={<InicioRoute />} />
                <Route path="/inicio" element={<Navigate to="/" replace />} />
                <Route path="/movimientos" element={<MovimientosRoute />} />
                <Route path="/reportes" element={<ReportesRoute />} />
                <Route path="/prestamos" element={<PrestamosRoute />} />
                <Route path="/prestamos/:id" element={<PrestamoDetalleRoute />} />
                <Route path="/metas" element={<MetasRoute />} />
                <Route path="/presupuestos" element={<PresupuestosRoute />} />
              </Route>
            </Route>

            <Route
              path="*"
              element={
                <Suspense fallback={<RouteSpinner />}>
                  <NotFoundRoute />
                </Suspense>
              }
            />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </ThemeProvider>
  );
}
