# Pockt web, etapa 3: web base

> **Para quien implementa:** TDD donde haya lógica (Vitest). No commitear: el
> orquestador revisa y commitea. Reporte final corto. Ningún dato real.

**Objetivo:** una web local (`web/`, `npm run dev` en `localhost:5173`) con la
identidad de Pockt, login con Google, barra superior, estado de sincronización,
404 y skeletons, conectada en vivo a los datos del usuario por PowerSync.
Al final se ve una lista de solo lectura de los últimos movimientos, para
comprobar que los datos llegan y se actualizan solos.

**Spec:** `docs/superpowers/specs/2026-10-29-pockt-web-design.md` (secciones 2,
3, 6, 7, 8 y etapa 3 de la sección 9). **Bocetos aprobados:**
`.superpowers/brainstorm/171364-1793283290/content/web-shell.html`,
`web-topnav.html`, `web-pantallas.html` (Inicio, Movimientos),
`web-pantallas-2.html` (Login, 404, modo claro).

**Stack:** Vite + React + TypeScript + Tailwind + shadcn/ui + Motion,
`@powersync/web` y `@supabase/supabase-js`, Vitest + Testing Library.
Versiones exactas fijadas en `package.json` (sin `^`).

## Restricciones globales

- Carpeta `web/` del repo. Repo público: en el código solo URL de Supabase,
  llave pública y URL de PowerSync, leídas de `import.meta.env`
  (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_POWERSYNC_URL`);
  valores en `web/.env.local` ignorado por git (agregar `web/**/.env*` al
  `.gitignore`, salvo `.env.example` con valores de ejemplo).
- Identidad de la app (valores de `lib/core/design/tokens.dart`): fondo
  `#000000` oscuro / `#F7F7F8` claro, superficie de hoja `#18181B` / `#FFFFFF`,
  marca `#FF8A3D` a `#FF3D7F` solo en botones y acentos, positivo `#4AD496` /
  `#008856`, aviso `#F7B83D` / `#B07100`, peligro `#F4514F` / `#CC272E`,
  Inter con números tabulares, vidrio y aurora de fondo. Tokens como variables
  CSS, modo claro y oscuro (sigue al sistema, con opción).
- Prohibido: degradé violeta a azul, texto con degradé, emojis (solo íconos SVG),
  rayas largas, "Podés gastar hoy".
- `robots.txt` con `Disallow: /`, `<meta name="robots" content="noindex">` en
  todas las páginas, sin sitemap. Título único por página ("Movimientos ·
  Pockt"); metadescripción solo en el login; favicon con el ícono de la app.
- Skeletons del mismo tamaño que el contenido con brillo suave; spinner solo en
  acciones chicas. Inputs con label arriba, placeholder con formato, ayuda
  siempre visible, campo activo con borde y label de marca.
- Skills: `apple-design` (principal), `emil-design-eng`, `animate`,
  `fixing-accessibility`, `fixing-motion-performance`, `web-design-guidelines`.

## Foco de revisión

1. Ninguna llave privada ni dato real en `web/` (revisar `.env.example`, tests).
2. El esquema de PowerSync de la web coincide columna por columna con
   `backend/powersync/sync-streams.yaml` (las 12 tablas sincronizadas).
3. Sin sesión, ninguna ruta privada se muestra (redirige a `/login`).
4. "Reducir movimiento": la barra cambia sin animación.
5. Cerrar sesión desconecta PowerSync y borra la base local del navegador.

---

### Tarea 3.1: proyecto, tokens y páginas fijas

**Archivos:** `web/` (Vite), `web/src/styles/tokens.css`, `web/public/robots.txt`,
`web/public/favicon.svg`, `web/index.html`, `web/.env.example`, `.gitignore`.

- [ ] Proyecto Vite React TS con Tailwind y shadcn/ui; Inter con
  `font-variant-numeric: tabular-nums` en montos.
- [ ] Tokens CSS claro/oscuro con los valores de arriba y selector de tema
  (sistema / claro / oscuro) guardado en `localStorage`.
- [ ] `robots.txt`, `noindex`, favicon desde `assets/` de la app.
- [ ] Página 404 según el boceto, con salida al Inicio.
- [ ] Vitest configurado; test: el formateo de guaraníes (`Gs. 1.234.567`, sin
  decimales, punto de miles) coincide con la app.

### Tarea 3.2: login y PowerSync

**Archivos:** `web/src/lib/supabase.ts`, `web/src/lib/powersync/schema.ts`,
`web/src/lib/powersync/connector.ts`, `web/src/lib/powersync/db.ts`,
`web/src/routes/login.tsx`, guardia de rutas.

- [ ] Login con Google por OAuth de Supabase (`signInWithOAuth`, redirect a
  `http://localhost:5173/`), pantalla según el boceto, metadescripción.
- [ ] Esquema PowerSync web con las 12 tablas y columnas exactas de
  `backend/powersync/sync-streams.yaml`. Test: cada tabla y columna del YAML
  existe en el esquema (parsear el YAML en el test).
- [ ] Conector: `fetchCredentials` con el token de la sesión de Supabase;
  `uploadData` igual que la app (`lib/core/sync/supabase_connector.dart`):
  PUT = upsert `onConflict: 'user_id,id'` sin mandar `user_id`, PATCH =
  update por `id`, DELETE = delete por `id`; códigos 22*/23* se registran
  (tabla y código) y se descartan; cualquier otro error se reintenta. Tests
  con un cliente falso para los tres tipos y los dos casos de error.
- [ ] Guardia: sin sesión, toda ruta privada va a `/login`. Cerrar sesión:
  `disconnectAndClear()` y vuelve al login. Test de la guardia.

### Tarea 3.3: barra superior y estado de sync

**Archivos:** `web/src/components/TopNav.tsx`, `web/src/components/SyncStatus.tsx`,
`web/src/components/Skeleton.tsx`, layout.

- [ ] `TopNav` según `web-topnav.html`: arriba a lo ancho y transparente; al
  hacer scroll se vuelve píldora de vidrio centrada con un spring de Motion;
  con `prefers-reduced-motion` cambia sin animación; por debajo de 768 px pasa
  a menú. Links: Inicio, Movimientos, Reportes, Préstamos, Metas; botón
  principal "Cargar" (deshabilitado hasta la etapa 4, con tooltip).
- [ ] `SyncStatus` en la barra: Sincronizado / Subiendo / Sin conexión, desde
  `db.currentStatus` y `statusStream`. Test de los tres estados.
- [ ] `Skeleton` con brillo suave (respeta reducir movimiento).

### Tarea 3.4: prueba de datos en vivo

**Archivos:** `web/src/routes/inicio.tsx`, `web/src/routes/movimientos.tsx`.

- [ ] Inicio: solo el encabezado del mes y "Gastado en <mes>" (suma de
  `transactions` tipo `expense` del mes calendario, sin `deleted_at`), con
  skeleton mientras carga. Sin "Podés gastar hoy".
- [ ] Movimientos: tabla de solo lectura con los últimos 50 movimientos
  (fecha, comercio o nota, categoría con su color, monto con signo), usando
  `useQuery` de PowerSync para que se actualice sola. Sin filtros ni edición
  (etapa 4).
- [ ] Test: el cálculo de "Gastado en el mes" con movimientos inventados.

## Verificación final (orquestador)

`npm run build` y `npm test` en verde; `npm run dev`, login con la cuenta del
usuario, la lista coincide con el teléfono y un movimiento cargado en el
teléfono aparece en la web sin recargar.
