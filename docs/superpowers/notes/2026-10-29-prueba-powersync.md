# Prueba técnica PowerSync + Drift + Supabase (etapa 0)

Fecha: 2026-10-29 · Rama `father` · Plan: `docs/superpowers/plans/2026-10-29-plan-11-web-etapas-0-1.md`

## Decisión

**Seguir** con Supabase + PowerSync + Drift (`drift_sqlite_async`). Los riesgos
de la spec (beta de `drift_sqlite_async`, migrar una base Drift existente,
streams de Drift con cambios que llegan por sync) quedaron cubiertos por tests.

## Qué se probó (todo en local, datos inventados)

| Prueba | Dónde | Resultado |
|---|---|---|
| Entorno Supabase + PowerSync con RLS y JWT de prueba | `spike/infra/check.sh` | PASS |
| App a nube, nube a app con `watch()` de Drift, sin conexión sin duplicar, aislamiento entre usuarios | `spike/powersync_drift/integration_test/sync_test.dart` (Linux) | 4/4 PASS |
| Migrar una base Pockt v16 (demo) a PowerSync: mismas filas y sumas por tabla, copia `.pre-sync.bak`, id de `loan_installments` | `spike/powersync_drift/test/migrate_test.dart` | PASS |
| Web en vivo (login, sync en los dos sentidos, aislamiento A/B) | `spike/web` (Vitest 2/2 + prueba manual en Chrome) | PASS |
| Esquema real con RLS y claves `(user_id, id)` | `backend/supabase/tests/rls_test.sql` | 335/335 PASS |
| Reglas de sync: cada usuario recibe solo sus filas en las 12 tablas, ids repetidos entre usuarios | `backend/powersync/check-isolation.sh` | PASS |

## Versiones

PowerSync Service 1.27.2 (Docker, imagen fijada por digest), `powersync`
2.5.0, `drift_sqlite_async` 0.3.1, `sqlite_async` 0.14.7, `@powersync/web`
2.5.0, `@supabase/supabase-js` 2.118.0, Postgres 17.

## Aprendizajes para la etapa 2 (app)

1. `loan_installments`: PK compuesta pasa a `id` texto `<loanId>:<number>`.
2. `settings`: PK `key` pasa a `id` = clave.
3. Tablas solo locales (`suggested_transactions`, `merchant_memory`,
   `category_keywords`, `counterparty_rules`, `entry_shortcuts`, `day_marks`)
   se declaran `localOnly` en el schema de PowerSync.
4. PowerSync no aplica claves foráneas ni `ON DELETE CASCADE` en el cliente:
   los borrados en cascada (por ejemplo cuotas al borrar un préstamo) los
   hace la app explícitamente.
5. Los streams de Drift necesitan `transformTableUpdates` para enterarse de
   los cambios que llegan por sync (`ps_data__<tabla>` a `<tabla>`).
6. En Postgres la clave es `(user_id, id)`: las categorías de fábrica tienen
   ids fijos iguales en toda instalación y `settings` usa la clave como id.

## Entorno local

Puertos 8080 y 8090 ocupados por otro proyecto: PowerSync de la prueba en
18080, el del backend real en 18081; Supabase de la prueba 54321/54322, el del
backend 55321/55322. Cómo levantar y bajar: `spike/infra/README.md`,
`backend/supabase/README.md`, `backend/powersync/README.md`.
