# Pockt web, etapa 2: la app sincroniza con la nube

> **Para quien implementa:** TDD en cada tarea (test que falla, verlo fallar,
> implementar, verlo pasar). No commitear: el orquestador revisa y commitea.
> Reporte final corto. Nunca tocar la app real del teléfono ni usar
> `flutter drive` con el applicationId real.

**Objetivo:** la app de Pockt guarda sus datos en una base PowerSync (sigue
funcionando igual sin conexión y sin sesión) y, si el usuario inicia sesión con
Google y activa "Sincronizar con la web", sube y baja cambios al instante.

**Arquitectura:** una sola forma de guardar: la base pasa a ser la de PowerSync
para todos (con o sin sesión). Drift sigue siendo la capa de acceso a través de
`drift_sqlite_async`; repositorios, cálculos y pantallas no cambian salvo por
las tablas que necesitan `id`. Al actualizar la app, los datos de la base Drift
actual se copian una vez a la base nueva, con copia de respaldo previa. La
conexión con la nube solo se abre con sesión y el interruptor activo.

**Stack:** Flutter 3.47 (`~/Proyectos/flutter/bin`), Drift 2.35, `powersync`
2.5.0, `drift_sqlite_async` 0.3.1, `supabase_flutter`, inicio de sesión nativo
de Google (Credential Manager / `google_sign_in`) con el cliente web
`Pockt Web (Supabase)` como audiencia del token.

**Spec:** `docs/superpowers/specs/2026-10-29-pockt-web-design.md` (secciones 3,
4, 6, 8, 10). **Base técnica:** `docs/superpowers/notes/2026-10-29-prueba-powersync.md`
y el código de `spike/powersync_drift/` (conexión, `transformTableUpdates`,
migración).

## Restricciones globales

- Rama `father`. Repo público: ninguna llave privada ni dato real. Las URLs y la
  llave pública de Supabase y la URL de PowerSync van por `--dart-define`
  (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `POWERSYNC_URL`, `GOOGLE_WEB_CLIENT_ID`),
  nunca escritas en el código; valores locales en un `.env` ignorado.
- Toda tabla de la base tiene una columna `id` texto única (PowerSync lo exige,
  también para las tablas solo locales).
- Tablas que viajan: `transactions`, `categories`, `loans`, `loan_installments`,
  `goals`, `goal_contributions`, `budgets`, `recurring_rules`,
  `income_schedules`, `salary_deductions`, `events`, `settings`. Solo locales:
  `suggested_transactions`, `merchant_memory`, `category_keywords`,
  `counterparty_rules`, `entry_shortcuts`, `day_marks`.
- Los borrados viajan como borrados de PowerSync (no hace falta borrado
  lógico); los borrados en cascada (cuotas al borrar un préstamo) los hace la
  app.
- Sin sesión o con el interruptor apagado, la app no abre ninguna conexión de red.
- Suite completa en verde y `flutter analyze` 0 en cada tarea.

## Foco de revisión

1. **Datos reales intactos al actualizar:** conteos y sumas por tabla iguales
   antes y después de la migración, copia `.pre-sync.bak` creada, y la app
   abre igual si la migración se corta a mitad (vuelve a intentar, no duplica)
   (tarea 2.3).
2. **Tareas en segundo plano:** Workmanager (correo, recordatorios, copias)
   abre la misma base desde otro isolate sin bloquearla ni perder escrituras
   (tarea 2.3).
3. **Primera sincronización de un usuario con datos:** al activar, sube todo lo
   local; si ya hay datos en la nube de ese usuario (otro teléfono), no se
   duplican categorías de fábrica ni ajustes (mismos ids) (tarea 2.4).
4. **Sesión vencida o sin red:** los cambios quedan en cola y suben al volver;
   nada se pierde ni se muestra error alarmante (tarea 2.4 y 2.5).
5. **Cerrar sesión:** deja de sincronizar y los datos locales quedan en el
   teléfono (no se borran) (tarea 2.5).

---

### Tarea 2.1: ids en las tablas que no lo tienen (agy)

**Archivos:** `lib/core/db/tables.dart`, `lib/core/db/app_database.dart`
(migración v16 a v17), repositorios que usan esas tablas, tests.

- `LoanInstallments`: `id` = `'<loanId>:<number>'`, clave `id`.
- `Settings`: `id` = la clave, clave `id` (se mantiene `key`).
- `DayMarks`: `id` = la fecha `yyyy-MM-dd`, clave `id`.
- `MerchantMemory`: `id` = `'<merchantKey>|<categoryId>'`, clave `id`.

- [ ] Tests que fallan: migración v16 a v17 sobre una base v16 de demo deja
  cada fila con su `id` derivado y conserva conteos; los repositorios
  (`SettingsRepository`, `DayMarksRepository`, préstamos con cronograma,
  memoria de comercios) siguen pasando sus tests actuales sin aflojarlos.
- [ ] Implementar y ver pasar.

### Tarea 2.2: schema de PowerSync que refleja Drift (codex)

**Archivos:** crear `lib/core/sync/powersync_schema.dart`, test
`test/core/sync/powersync_schema_test.dart`.

**Produce:** `const Schema pocktPowerSyncSchema` con las 12 tablas que viajan y
las 6 solo locales (`localOnly: true`), columnas y tipos iguales a los de Drift
(texto, entero, real).

- [ ] Test que falla: para cada tabla de `AppDatabase.allTables`, existe en el
  schema con las mismas columnas (sin `id`, que PowerSync agrega) y el mismo
  carácter local o sincronizado que dice la spec.
- [ ] Implementar y ver pasar.

### Tarea 2.3: abrir la base sobre PowerSync y migrar una vez (agy)

**Archivos:** `lib/core/db/app_database.dart` (`_openConnection`),
crear `lib/core/sync/pockt_powersync.dart` y
`lib/core/sync/migrate_legacy_db.dart`, `lib/core/background/background_tasks.dart`,
`lib/main.dart`; tests.

**Produce:** `Future<PowerSyncDatabase> openPocktPowerSync()`,
`Future<MigrationReport> migrateLegacyDriftDb(...)` (adaptado del spike),
`AppDatabase.powerSync(PowerSyncDatabase db)` con `transformTableUpdates`.

- [ ] Tests que fallan: (a) migración de la base v17 de demo: reportes iguales,
  `.pre-sync.bak` existe, marca de "migrado" guardada y una segunda corrida no
  hace nada; (b) migración cortada a mitad: la siguiente apertura reintenta
  desde la copia y no duplica; (c) un stream `watch()` de Drift sobre
  `transactions` emite tras un cambio escrito por otra conexión; (d) dos
  conexiones (simulando Workmanager) escriben sin perder filas.
- [ ] Implementar y ver pasar. Variante Demo y tests siguen usando la base
  en memoria donde ya lo hacen.

### Tarea 2.4: conector con Supabase (codex)

**Archivos:** crear `lib/core/sync/supabase_connector.dart`, test.

**Produce:** `class PocktSupabaseConnector extends PowerSyncBackendConnector`
con `fetchCredentials()` (token de la sesión de Supabase) y `uploadData()`
(PUT = upsert con `onConflict: 'user_id,id'`, PATCH = update por `id`,
DELETE = delete por `id`; sin enviar `user_id`).

- [ ] Tests con un cliente falso: cada tipo de operación arma la llamada
  correcta; un error de red deja la transacción sin completar (se reintenta);
  un error 4xx de datos inválidos se registra y la cola sigue (no se traba).
- [ ] Implementar y ver pasar.

### Tarea 2.5: inicio de sesión con Google y estado de sync (agy)

**Archivos:** crear `lib/core/sync/auth_service.dart`,
`lib/core/sync/sync_controller.dart`, ajustes en `settings_repository.dart`
(clave `sync.enabled`), tests.

**Produce:** `AuthService.signInWithGoogle()`, `signOut()`, `Stream<Session?>`;
`SyncController` que conecta PowerSync solo con sesión y `sync.enabled = true`,
y expone `Stream<SyncState>` (apagado, conectando, sincronizado, subiendo,
sin conexión, error).

- [ ] Tests que fallan: sin sesión no conecta; activar con sesión conecta;
  cerrar sesión desconecta y conserva los datos locales; apagar el interruptor
  desconecta.
- [ ] Implementar y ver pasar. El token de Google se pide con el cliente web
  como audiencia; en Supabase se agrega ese Client ID a "Client IDs" si hace
  falta (lo hace el orquestador con el usuario).

### Tarea 2.6: pantalla "Sincronizar con la web" (agy, después del boceto)

**Bloqueante:** el boceto se valida con el usuario en el visual companion
antes de implementar (regla del proyecto). Ubicación propuesta: Ajustes,
Privacidad y datos.

- [ ] Tests de widget del boceto aprobado: estados apagado / iniciar sesión /
  sincronizado / sin conexión / error; cerrar sesión con confirmación.
- [ ] Implementar y ver pasar.

### Tarea 2.7: prueba en el teléfono con la variante Demo (orquestador)

- Demo apunta al backend **local** (`backend/`) a través de `adb reverse`, nunca
  a la nube real, para no mezclar datos de demo con los del usuario.
- Verificar: migración al actualizar, login, cambio en la Demo aparece en la
  mini web local y al revés, sin conexión y reconexión.

### Tarea 2.8: actualización de la app real (orquestador con el usuario)

- Antes: el usuario hace la copia cifrada en Drive desde Pockt y se anotan
  conteos y totales del mes.
- Instalar encima (`install -r`), abrir, comparar conteos y totales.
- El usuario inicia sesión y activa la sincronización; verificar en Supabase
  que las filas aparecen con su `user_id`.
- Auditoría rápida de la etapa 2 (Codex con deepsec, agy con la skill de
  Cloudflare) sobre una copia limpia.
