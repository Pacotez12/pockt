# Backend local · Tarea 1.1

Proyecto generado con `npx supabase init`, project_id `pockt-backend`.
Es independiente del spike: no comparte base, red ni puertos.

Desde la raíz del repo:

```bash
cd backend
npx --yes supabase start
npx --yes supabase migration up --local
npx --yes supabase test db
# Para bajar únicamente este stack, conservando datos:
npx --yes supabase stop
```

Puertos: API/Auth `55321`, Postgres `55322`, Studio `55323`, correo `55324`,
analytics `55327`; shadow DB `55320`, pooler deshabilitado reservado en `55329`,
inspector de funciones `18083`. No detener stacks ajenos para liberarlos.
No se necesita `.env` para migrar ni para ejecutar pgTAP. Si se necesitan
credenciales locales, copiarlas de `npx supabase status -o env` a un `.env`
ignorado; `backend/.env.example` contiene solo placeholders y conexión local.

## Contrato de esquema

`0001_init.sql` crea las 12 tablas sincronizadas de la spec, con nombres
verificados contra `lib/core/db/tables.dart` y `app_database.g.dart`:

- PK `(user_id, id)` en las 12 tablas, aplicada por
  `0002_user_scoped_ids.sql` sin resetear ni borrar filas. `id` sigue siendo
  texto y puede repetirse entre usuarios. En cuotas se valida
  `id = loan_id || ':' || number`; en settings se conserva `key` de Drift
  y se valida `id = key`. Ambos campos deben enviarse en el insert.
- Enteros y fechas como `bigint` (segundos Unix); booleanos como `integer`
  con CHECK 0/1; enums y JSON serializado como `text`. Se conservan defaults
  y nulabilidad de Drift. No hay columnas `real` en estas tablas actuales.
- Se agrega `updated_at bigint` donde Drift aún no lo tiene; su default es
  el segundo Unix actual. En tablas que ya tenían `updated_at`, se conserva
  el campo obligatorio sin default. Las actualizaciones deben enviar el
  timestamp del cambio; no hay triggers que reescriban fechas del cliente.
- `transactions.deleted_at` mantiene los borrados lógicos existentes.
- `user_id uuid NOT NULL DEFAULT auth.uid()`, RLS y políticas separadas
  SELECT/INSERT/UPDATE/DELETE para `authenticated`. UPDATE comprueba tanto
  la propiedad anterior como la nueva. `anon` no recibe permisos; a
  `authenticated` se le otorga solo CRUD (sin TRUNCATE).
- Sin foreign keys, incluso para `user_id`; los índices no exigen orden de
  subida. `REPLICA IDENTITY FULL` y publicación `powersync` limitada a estas
  12 tablas. Las reglas y el chequeo de aislamiento están en
  `backend/powersync/` (Tarea 1.2).

## Pruebas

`tests/rls_test.sql` contrasta columnas, tipos, PK, RLS, ausencia de foreign
keys y tablas publicadas. Para cada tabla prueba operaciones propias,
`user_id` por defecto, y deniega lectura, modificación, borrado, inserción
ajena y transferencia de propiedad entre A y B. Las operaciones usan el rol
real `authenticated` y claims `auth.uid()` con UUIDs inventados. No se
necesitan contraseñas ni cuentas persistentes. Todo termina con ROLLBACK.

TDD: el primer `npx supabase test db` falló sin la migración; tras aplicar
`0001_init.sql`, la suite completa pasó. La corrección de PK también se verificó roja/verde:
B puede insertar categorías de fábrica y settings con los mismos ids de A
sin alterar los valores ni la visibilidad de A (335 pruebas en total).
