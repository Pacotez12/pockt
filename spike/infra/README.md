# Spike local: Supabase + PowerSync

Solo datos inventados. Requisitos: Docker con Compose, Node/npm (`npx`),
Bash, curl y jq. No hace falta instalar Supabase
ni psql: se usa `npx supabase` y el psql del contenedor.

API: http://localhost:54321; Postgres: localhost:54322 (postgres/postgres);
PowerSync: http://localhost:18080 (puerto del host configurable con
`PS_HOST_PORT` en `.env`; puerto interno 8080). Usar un puerto libre, sin
detener contenedores de otros proyectos. `check.sh` usa la misma variable.

## Levantar

Desde la raíz del repo:

```bash
cd spike/infra
npx --yes supabase start
# En una base existente, aplicar nuevas migraciones sin resetear datos:
npx --yes supabase migration up --local
cp .env.example .env
chmod 600 .env
# Inventar PS_STORAGE_PASSWORD y SPIKE_TEST_PASSWORD en .env.
# Copiar ANON_KEY y SERVICE_ROLE_KEY de este comando a las variables
# SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY de .env:
npx --yes supabase status -o env
docker compose up -d --wait
./check.sh
./token.sh a@test.local
./token.sh b@test.local
```

`supabase/` fue generado con `npx supabase init`; el directorio de trabajo
es `spike/infra` (la CLI encuentra `supabase/config.toml`). En el primer
arranque se aplica `0001_spike.sql`. No ejecutar `db reset` sobre datos que
se quieran conservar. No sobrescribir `.env` al volver a levantar.

`token.sh <email>` acepta las dos cuentas anteriores. Si no puede iniciar
sesión, crea esa cuenta confirmada mediante `/auth/v1/admin/users` con la
contraseña inventada de `.env`; luego inicia sesión y valida el JWT con
`/auth/v1/user`. stdout contiene solo el access token; errores van a stderr.
No cambiar la contraseña en `.env` para usuarios ya creados.

`check.sh` verifica la sonda HTTP y consulta `pg_class.relrowsecurity` mediante
psql dentro de `supabase_db_pockt-spike`. Sale con código distinto de cero si
falta el servicio, la tabla o RLS. Liveness no prueba sincronización de un SDK;
ese recorrido corresponde a las siguientes tareas del plan.

## Bajar (conservar datos)

```bash
cd spike/infra
docker compose down
npx --yes supabase stop
```

Los datos del storage PowerSync quedan en el volumen de Compose y Supabase
conserva los suyos. No usar `down -v` ni `stop --no-backup` si se quieren guardar.

## Configuración

La publicación `powersync` incluye únicamente `spike_tx`. RLS permite leer y
escribir solo `user_id = auth.uid()`, con el mismo control en `WITH CHECK`.
El servicio de replicación usa el administrador **local** de Postgres para
este spike descartable. Los clientes escriben por Supabase con su JWT.
PowerSync filtra los buckets por el `sub` del token; no aplica las políticas
RLS de Postgres al replicar, por eso las reglas de sync también son necesarias.

Los contenedores se conectan por `supabase_network_pockt-spike`; PowerSync
valida los JWT de Supabase mediante el JWKS local de Kong y audience
`authenticated`. Bucket storage usa un Postgres separado, sin puerto expuesto.
PowerSync se publica solo en loopback. `.env`, `.temp`, `.branches` y
`node_modules` están ignorados; nunca copiar llaves de nube aquí.

Se usa la imagen oficial `journeyapps/powersync-service:1.27.2`, fijada también
por digest para reproducir esta prueba. Config
basada en [desarrollo local Supabase](https://docs.powersync.com/integrations/supabase/local-development),
[demo oficial](https://github.com/powersync-ja/self-host-demo/tree/main/demos/supabase)
y [configuración del servicio](https://docs.powersync.com/configuration/powersync-service/self-hosted-instances).
Las reglas usan buckets por usuario del plan (Sync Rules), soportadas por
esta versión aunque el servicio las marca como deprecadas. Los montajes
`:ro,z` permiten que el contenedor lea los YAML también en hosts con SELinux.
