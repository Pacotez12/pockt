# PowerSync backend local · Tarea 1.2

Requisitos: Docker con Compose, Node 24 y npm/npx. El chequeo usa únicamente
APIs estándar de Node; no necesita instalar paquetes ni SDKs.

Stack independiente: proyecto Compose `pockt-backend-sync`, storage Postgres
propio, PowerSync oficial 1.27.2 fijado por digest y conexión a
`supabase_network_pockt-backend`. No comparte configuración, volumen ni
puertos con `spike/infra`. No detener contenedores ajenos.

## Levantar

Desde la raíz del repo:

```bash
cd backend
npx --yes supabase start
npx --yes supabase migration up --local
npx --yes supabase test db
cd powersync
cp .env.example .env
chmod 600 .env
# Inventar PS_STORAGE_PASSWORD; no usar una contraseña de nube.
# Desde backend/, consultar `npx --yes supabase status -o env` y copiar
# ANON_KEY y SERVICE_ROLE_KEY locales a SUPABASE_ANON_KEY y
# SUPABASE_SERVICE_ROLE_KEY de este .env.
docker compose up -d --wait
./check-isolation.sh
```

No sobrescribir `.env` al volver a levantar. Las credenciales están ignoradas
por `backend/**/.env`. El servicio recibe solo las variables de sus conexiones;
la llave admin se usa exclusivamente en el chequeo para crear/borrar usuarios.
La conexión de replicación usa el administrador del Postgres **local**.

PowerSync: http://localhost:18081 (solo loopback). Su puerto interno sigue
siendo 8080. Supabase backend: API/Auth 55321 y Postgres 55322. Si 18081 está
ocupado, elegir otro puerto libre y ajustar tanto `PS_HOST_PORT` como
`POWERSYNC_URL` en `.env`. Los puertos 8080/8090/18080 no se usan en el host.
El storage no publica ningún puerto.

## Reglas e identidad

`sync-rules.yaml` define un único bucket lógico `user_data` con parámetro
`SELECT request.user_id() AS user_id`: la identidad viene del `sub` del JWT
Supabase, verificado con su JWKS local y audience `authenticated`.

Las doce consultas filtran `user_id = bucket.user_id`, equivalente al filtro
por `request.user_id()` solicitado. Proyectan explícitamente las columnas
sin `user_id`, que se usa para filtrar pero no se entrega al cliente.
PowerSync no aplica RLS al replicar: las reglas protegen las descargas y RLS
protege las escrituras por Supabase; ambos controles son necesarios.

Postgres usa PK `(user_id, id)` en las doce tablas tras
`supabase/migrations/0002_user_scoped_ids.sql`. PowerSync entrega `id` como
identidad del cliente dentro de su bucket: categorías de fábrica y settings
pueden compartir ids entre usuarios. El conector de subida debe tomar el
usuario de la sesión y usar la PK `(user_id, id)` para upserts
(`onConflict: 'user_id,id'`), o dejar que Postgres aplique `auth.uid()` en
inserciones. La RLS rechaza cualquier dueño ajeno. Los valores de `id`,
`loan_id` y las claves settings no se transforman para sincronizar.

Se mantienen Sync Rules según el plan; esta versión del servicio las admite
pero avisa que están deprecadas. No se cambió el plan a Sync Streams.

## Qué prueba check-isolation.sh

1. Comprueba liveness y rechaza URLs de servicios que no sean loopback.
2. Crea dos usuarios confirmados nuevos por ejecución mediante Auth admin
   local y obtiene JWTs reales con login por contraseña inventada al vuelo.
3. Inserta por Supabase, bajo RLS, dos filas por tabla y por usuario: una de
   id privado y otra cuyo id es igual para A/B. Los valores difieren entre
   usuarios. No requiere filas relacionadas ni desactiva RLS.
4. Lee `/sync/stream` con cada JWT. Comprueba **todos** los PUT recibidos:
   tabla e id esperados, valores propios exactos y ausencia de `user_id`.
   No aprueba hasta recibir un checkpoint completo con las 24 filas propias.
   Inserta primero A y luego B, y comprueba B antes que A: al completar B,
   las filas anteriores de A ya debieron pasar por replicación.
5. Elimina sus filas y usuarios en `finally`, también ante errores. No usa
   cuentas ni borra datos anteriores de otras pruebas. No imprime tokens,
   llaves ni contraseñas. Ante un fallo corta con salida distinta de cero;
   el timeout del stream es 30 segundos por usuario.

El chequeo pasó con 24 filas propias y cero ajenas por usuario en las 12
tablas, incluidos ids compartidos con valores diferentes. Verifica la
respuesta real del servicio; no sustituye pruebas de integración de cada SDK.

## Bajar solo PowerSync backend

```bash
cd backend/powersync
docker compose down
```

Se conserva el volumen de storage. Para bajar también **este** Supabase,
ejecutar `npx --yes supabase stop` desde `backend/`. No usar `down -v` si se
quieren conservar sus datos. El spike y los otros proyectos quedan corriendo.

Referencias oficiales: [Data Queries y selección de columnas](https://docs.powersync.com/sync/rules/data-queries),
[desarrollo local Supabase](https://docs.powersync.com/integrations/supabase/local-development),
[protocolo y checkpoints](https://docs.powersync.com/architecture/powersync-protocol).

## Producción (PowerSync Cloud)

La instancia en la nube usa el formato nuevo **Sync Streams** (`config.edition: 3`),
guardado en `sync-streams.yaml`: las mismas 12 consultas que `sync-rules.yaml`,
filtradas con `auth.user_id()` y sin bajar `user_id`. Se cargó desde el panel de
PowerSync (Sync Streams → Deploy). La conexión a Supabase usa un rol de
replicación propio con SSL `verify-full`, y las sesiones se validan con el JWKS
HTTPS de Supabase. `sync-rules.yaml` queda para el entorno local.
