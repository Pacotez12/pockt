# Pockt web, etapa 7: rendimiento, seguridad, accesibilidad y publicación

> **Para quien implementa:** TDD donde haya lógica. No commitear. Reporte final
> corto. Datos inventados en tests. No iniciar sesión con la cuenta del
> usuario. No publicar nada: el despliegue lo hace el orquestador.

**Objetivo:** dejar la web lista para publicarse en Vercel. Tiene que cargar
rápido, tener las cabeceras de seguridad, no indexarse y poder usarse con
teclado y lector de pantalla.

**Spec:** `docs/superpowers/specs/2026-10-29-pockt-web-design.md` (secciones 3,
6, 7 y etapa 7).

## Restricciones globales

- Las de los planes 13 a 16. No tocar `lib/` (la app).
- Sin dependencias nuevas salvo que una tarea lo diga.
- Ninguna llave privada en el repo. En `web/` solo la llave pública de
  Supabase y las URLs, leídas de variables `VITE_*`.

## Foco de revisión

1. El primer ingreso (login) no descarga three.js, jspdf ni exceljs.
2. La CSP no rompe nada: login con Google, sync de PowerSync (wss), el worker
   y el wasm de PowerSync, el shader WebGL, las fuentes y las descargas.
3. Recargar una ruta profunda (`/prestamos/<id>`) en Vercel no da 404.
4. Ninguna página se indexa.
5. Todo se puede usar con teclado y el foco siempre se ve.

---

### Tarea 7.1: rendimiento

- [ ] Medí el bundle actual (`npm run build`): el chunk principal pesa
  1,8 MB.
- [ ] Carga diferida por ruta con `lazy` + `Suspense` para todas las
  pantallas privadas, no solo Reportes. Fallback: el skeleton de cada
  pantalla o el spinner del ProtectedRoute.
- [ ] `exceljs` y `jspdf` se importan con `import()` dentro del handler de
  descarga, no arriba del archivo.
- [ ] Objetivo: chunk de entrada (login) menor a 350 kB sin gzip, sin
  three/jspdf/exceljs. Test que lo verifique sobre `dist/` (script de
  Node en `web/scripts/check-bundle.mjs`, corrido desde `npm run build`) o,
  si no, reportar los tamaños antes y después.

### Tarea 7.2: cabeceras y despliegue estático

- [ ] `web/vercel.json`:
  - Rewrite de todas las rutas a `/index.html` (SPA).
  - Cabeceras para todo:
    - `Content-Security-Policy` con lo mínimo que use la web, deducido del
      código y de las variables `VITE_SUPABASE_URL` y `VITE_POWERSYNC_URL`:
      `default-src 'self'`, `connect-src` a Supabase (https y wss) y
      PowerSync (https y wss), `worker-src 'self' blob:`,
      `script-src 'self' 'wasm-unsafe-eval'`, `img-src 'self' data: blob:` y
      `lh3.googleusercontent.com` si se muestra la foto de Google, fuentes
      según lo que cargue `index.html`, `frame-ancestors 'none'`.
    - `X-Frame-Options: DENY`.
    - `X-Content-Type-Options: nosniff`.
    - `Referrer-Policy: strict-origin-when-cross-origin`.
    - `Permissions-Policy` sin cámara, micrófono ni ubicación.
    - `X-Robots-Tag: noindex, nofollow`.
  - Cache larga e inmutable para `/assets/*`.
- [ ] Verificá que `robots.txt` diga `Disallow: /` y que `index.html` tenga
  `<meta name="robots" content="noindex">`.
- [ ] Probá la CSP localmente con `npm run build && npx vite preview` y las
  mismas cabeceras (por ejemplo con un `preview.headers` en
  `vite.config.ts` leyendo `vercel.json`). En la consola no puede quedar
  ningún error de CSP al entrar, sincronizar, abrir Reportes 3D y descargar
  el PDF.
- [ ] La app no se rompe si falta una variable `VITE_*`: muestra el error de
  configuración que ya existe.

### Tarea 7.3: accesibilidad

- [ ] Con las skills `fixing-accessibility` y `web-design-guidelines`, revisá
  todas las pantallas:
  - foco visible en todos los controles;
  - botones de solo ícono con `aria-label`;
  - popovers y paneles que atrapan el foco y lo devuelven al cerrar;
  - contraste AA en oscuro y en claro (en especial `text-tertiary` sobre
    vidrio);
  - el mapa 2D de Tus días navegable con teclado (flechas + Enter abre el
    día);
  - `prefers-reduced-motion` respetado en todo.
- [ ] Tests de los que tengan lógica (atrapar y devolver el foco, teclado en
  Tus días).

### Tarea 7.4: publicación (orquestador, con el usuario)

- [ ] Login en Vercel por código de dispositivo, aprobado por el usuario.
- [ ] Proyecto con raíz `web/`. Variables `VITE_SUPABASE_URL`,
  `VITE_SUPABASE_ANON_KEY` y `VITE_POWERSYNC_URL` en Vercel.
- [ ] La URL de Vercel en las redirecciones permitidas de Supabase Auth (lo
  hace el usuario).
- [ ] Prueba en producción: login, sync, crear y borrar un movimiento de
  prueba, cabeceras con `curl -I`.
- [ ] Auditoría de seguridad final de la web publicada.

## Verificación final (orquestador)

`npm test` y `npm run build` en verde, tamaños del bundle, cero errores de CSP
en la consola y capturas de las pantallas con el build de producción.
