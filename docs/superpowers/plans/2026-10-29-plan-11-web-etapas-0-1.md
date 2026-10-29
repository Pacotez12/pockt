# Pockt web, etapas 0 y 1: prueba técnica y backend (Supabase + PowerSync)

> **Para quien implementa:** cada tarea se hace con TDD (test que falla, verlo
> fallar, implementar, verlo pasar). No commitear: el orquestador revisa y
> commitea. Reporte final corto (archivos tocados y resultado de tests).

**Objetivo:** probar que Drift + PowerSync + Supabase funcionan juntos con la
base real de Pockt (etapa 0) y dejar listo el backend con esquema, seguridad
por usuario, reglas de sync y login con Google (etapa 1).

**Arquitectura:** Supabase (Postgres + Auth) es la fuente en la nube; PowerSync
Service sincroniza cada usuario con la SQLite local del teléfono y del
navegador; el teléfono sigue usando Drift a través de `drift_sqlite_async`.
Todo se prueba primero en local con Docker; la nube se configura al final con
el usuario presente.

**Stack:** Docker, Supabase CLI (vía `npx supabase`, no instalada global),
PowerSync Service (imagen Docker oficial), Flutter 3.47 en
`~/Proyectos/flutter/bin` (no está en PATH), Drift 2.35, paquetes `powersync`
y `drift_sqlite_async`, Node 24 + Vite + React para la mini web de la prueba.

**Spec:** `docs/superpowers/specs/2026-10-29-pockt-web-design.md` (secciones 3,
4, 6, 9 y 10).

## Restricciones globales

- Rama `father`. No tocar `main`.
- Repo público: nada de llaves privadas, `.env` ignorado por git; solo
  `.env.example` con nombres de variables y valores falsos.
- Ningún dato real: fixtures y datos de prueba inventados.
- La app real del teléfono no se toca en estas etapas (ni instalaciones ni
  `flutter drive`). Pruebas en Linux de escritorio o con tests.
- La etapa 0 vive en `spike/` y es descartable: no se importa desde `lib/` ni
  `web/`.
- Ids: texto, UUID v4 generado en el cliente. PowerSync no admite claves
  compuestas.
- Fechas como en Drift hoy: entero con segundos Unix. Booleanos como entero
  0/1. Enums como texto.
- Toda tabla sincronizada en Postgres tiene `user_id uuid not null default
  auth.uid()` y RLS activa.

## Foco de revisión

1. **Otro usuario no ve tus filas:** un JWT de un segundo usuario no lee ni
   escribe filas ajenas, ni por Postgres ni por PowerSync (tarea 1.1 y 1.2).
2. **Migración sin pérdida:** los conteos y sumas de una base Drift v16 antes
   y después de pasarla a PowerSync son idénticos (tarea 0.3).
3. **Los streams de Drift siguen disparando** cuando el cambio llega por
   sincronización, no solo cuando lo escribe la app (tarea 0.2): es el bug
   clásico de esta integración.
4. **Sin conexión:** una escritura hecha sin red queda en la cola y sube al
   volver, sin duplicarse (tarea 0.2).
5. **Fechas y montos no cambian de forma** al ida y vuelta (segundos Unix y
   enteros en guaraníes, sin decimales ni zonas horarias corridas) (tarea 0.2).

---

## Etapa 0: prueba técnica (descartable)

### Tarea 0.1: entorno local Supabase + PowerSync (codex)

**Archivos:**
- Crear: `spike/infra/docker-compose.yml`, `spike/infra/powersync.yaml`,
  `spike/infra/sync-rules.yaml`, `spike/infra/README.md`, `spike/infra/.env.example`
- Crear: `spike/infra/supabase/` (salida de `npx supabase init`)
- Crear: `spike/infra/supabase/migrations/0001_spike.sql`

**Interfaces:**
- Produce: Postgres local en `localhost:54322`, API de Supabase en
  `localhost:54321`, PowerSync en `localhost:18080`; tabla `spike_tx(id text
  primary key, user_id uuid not null default auth.uid(), amount integer not
  null, note text, occurred_at bigint not null, updated_at bigint not null,
  deleted_at bigint)` con RLS `user_id = auth.uid()`; script
  `spike/infra/token.sh <email>` que imprime un JWT válido de un usuario de
  prueba.

- [ ] **Paso 1:** `spike/infra/check.sh` que falla si no responde
  `curl -sf localhost:18080/probes/liveness` o si `psql` no ve la tabla
  `spike_tx` con RLS activa (`relrowsecurity = true`).
- [ ] **Paso 2:** correr `check.sh` y verlo fallar.
- [ ] **Paso 3:** levantar Supabase (`npx supabase start` en
  `spike/infra/supabase`) y PowerSync (docker compose), con la publicación
  `powersync` sobre `spike_tx` y reglas de sync con un bucket por usuario:
  `SELECT * FROM spike_tx WHERE user_id = request.user_id()`.
- [ ] **Paso 4:** correr `check.sh` y verlo pasar; `token.sh a@test.local`
  devuelve un JWT.

### Tarea 0.2: app Flutter mínima con Drift sobre PowerSync (agy)

**Archivos:**
- Crear: proyecto `spike/powersync_drift/` (Flutter, escritorio Linux habilitado)
- Test: `spike/powersync_drift/integration_test/sync_test.dart`

**Interfaces:**
- Consume: entorno de la tarea 0.1 y `token.sh`.
- Produce: `class SpikeDb extends _$SpikeDb` (Drift) sobre
  `SqliteAsyncDriftConnection(powerSyncDb)`, tabla Drift `SpikeTx` con las
  mismas columnas que `spike_tx`; `Future<void> connectAs(String jwt)`.

- [ ] **Paso 1: tests que fallan** en `sync_test.dart`:
  - `app -> nube`: insertar con Drift una fila (`amount: 184000`,
    `occurred_at: 1793260800`) y en menos de 10 s verla en Postgres con los
    mismos valores.
  - `nube -> app`: insertar en Postgres (como el mismo usuario) y que un
    `select(spikeTx).watch()` de Drift emita la fila en menos de 10 s.
  - `sin conexión`: desconectar, insertar, reconectar: la fila llega a
    Postgres una sola vez.
  - `otro usuario`: conectado como `b@test.local`, la fila de `a@test.local`
    no aparece localmente.
- [ ] **Paso 2:** correr
  `~/Proyectos/flutter/bin/flutter test integration_test -d linux` y verlos fallar.
- [ ] **Paso 3:** implementar con `powersync` + `drift_sqlite_async` según el
  ejemplo oficial `supabase-todolist-drift`; si el stream no dispara con
  cambios de sync, usar `transformTableUpdates` de la conexión.
- [ ] **Paso 4:** correr los tests y verlos pasar.

### Tarea 0.3: migrar una base Drift existente (agy)

**Archivos:**
- Crear: `spike/powersync_drift/lib/migrate_from_drift.dart`
- Test: `spike/powersync_drift/test/migrate_test.dart`
- Fixture: generar una base v16 de Pockt con datos inventados usando
  `seedDemoData` del repo (sin copiar datos reales).

**Interfaces:**
- Produce: `Future<MigrationReport> migrateFromDrift(String oldDbPath, PowerSyncDatabase target)`
  con `MigrationReport { Map<String,int> rowsByTable; Map<String,int> amountSumByTable; }`.

- [ ] **Paso 1: test que falla:** sobre la fixture, el reporte de origen y el
  de destino son iguales tabla por tabla (conteo de filas y suma de `amount`
  donde exista), y `loan_installments` queda con `id = '<loanId>:<number>'`.
- [ ] **Paso 2:** correrlo y verlo fallar.
- [ ] **Paso 3:** implementar copiando fila por fila dentro de una transacción
  de PowerSync, para las tablas sincronizadas de la spec (sección 4); antes de
  migrar copiar el archivo original a `<path>.pre-sync.bak`.
- [ ] **Paso 4:** correrlo y verlo pasar.

### Tarea 0.4: mini web en vivo (codex)

**Archivos:**
- Crear: `spike/web/` (Vite + React + TypeScript, `@powersync/web`, `@supabase/supabase-js`)

**Interfaces:**
- Consume: entorno 0.1 y `token.sh`.

- [ ] **Paso 1:** test con Vitest que falla: la función
  `formatGs(184000) === 'Gs. 184.000'` y el schema de PowerSync declara
  `spike_tx` con `amount` entero.
- [ ] **Paso 2:** verlo fallar, implementar, verlo pasar.
- [ ] **Paso 3:** página que lista `spike_tx` con `useQuery` y un botón que
  inserta una fila. Verificación manual: con la app de la tarea 0.2 abierta,
  un insert en la web aparece en la app y al revés en menos de 5 s.

### Tarea 0.5: informe de la prueba (orquestador)

- Crear: `docs/superpowers/notes/2026-10-29-prueba-powersync.md` con: qué
  funcionó, problemas encontrados, versiones exactas, y decisión
  **seguir / cambiar de camino**. Si no se sigue, alternativas antes de la etapa 1.

---

## Etapa 1: backend (solo si la etapa 0 dice "seguir")

### Tarea 1.1: esquema Postgres y seguridad (agy)

**Archivos:**
- Crear: `backend/supabase/` (`npx supabase init`), `backend/supabase/migrations/0001_init.sql`
- Test: `backend/supabase/tests/rls_test.sql` (pgTAP, `npx supabase test db`)

**Interfaces:**
- Produce: tablas de la sección 4 de la spec con las columnas de
  `lib/core/db/tables.dart` (mismos nombres en snake_case, mismos tipos de
  almacenamiento de Drift), más `user_id` con RLS; publicación `powersync`
  con esas tablas.

- [ ] **Paso 1: tests pgTAP que fallan:** todas las tablas sincronizadas tienen
  RLS activa; el usuario B no lee ni modifica filas del usuario A; un insert
  sin `user_id` queda con el del usuario autenticado; `loan_installments.id`
  es texto.
- [ ] **Paso 2:** `npx supabase test db` falla.
- [ ] **Paso 3:** escribir la migración.
- [ ] **Paso 4:** `npx supabase test db` pasa.

### Tarea 1.2: reglas de sync (codex)

**Archivos:**
- Crear: `backend/powersync/sync-rules.yaml`, `backend/powersync/README.md`

- [ ] Un bucket por usuario con todas las tablas de la tarea 1.1
  (`WHERE user_id = request.user_id()`). Verificación: levantar PowerSync
  local contra `backend/supabase` y repetir el test `otro usuario` de la
  tarea 0.2 apuntando al esquema real.

### Tarea 1.3: login con Google (orquestador con el usuario)

- [ ] Crear cliente OAuth **web** en el proyecto de Google Cloud existente
  (con el usuario presente, él aprueba).
- [ ] Configurar el proveedor Google en Supabase (local en `config.toml` y
  después en la nube) con orígenes permitidos de Vercel y localhost.
- [ ] Verificación: login de Google en local devuelve sesión y `auth.uid()`.

### Tarea 1.4: nube (orquestador con el usuario)

- [ ] El usuario crea las cuentas (Supabase, PowerSync) e inicia sesión.
- [ ] Proyecto Supabase: aplicar migraciones (`npx supabase db push`), correr
  `rls_test.sql` contra la nube.
- [ ] Instancia PowerSync conectada a Supabase con las reglas de la tarea 1.2.
- [ ] Llaves en `backend/.env` (ignorado) y en un gestor del usuario; nunca en
  el repo.
- [ ] Verificación: la mini web de la tarea 0.4 apuntando a la nube sincroniza
  con un usuario de prueba.
- [ ] De la auditoría de la etapa 1 (pendientes de validar en la nube): las
  conexiones de PowerSync a Postgres usan TLS (`sslmode=require` o
  `verify-full`) y el `jwks_uri` es el HTTPS del proyecto Supabase.
