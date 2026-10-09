# Pockt — Plan 4: backup cifrado, restauración, bloqueo y primer uso

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pockt v1.0.0: backup cifrado automático (día de por medio, con WiFi) en una carpeta visible del Google Drive del usuario, restauración con vista previa y vuelta atrás, bloqueo opcional con huella y la experiencia de primer uso.

**Architecture:** El backup se arma en capas probables por separado: (1) **instantánea** de la base con `VACUUM INTO`; (2) **formato** `.pockt` = encabezado + gzip + AES-256-GCM con clave Argon2id; (3) **destino** detrás de una interfaz `BackupStore` con dos implementaciones, `DriveBackupStore` (Google Drive, scope `drive.file`) y `MemoryBackupStore` (tests). La orquestación (`BackupService`) no conoce Drive. Así todo se prueba sin red ni cuenta de Google; solo la última milla (login y subida real) necesita la configuración del autor.

**Tech Stack:** los de los planes 1–3 + `cryptography` 2.9.0, `flutter_secure_storage` 11.2.0, `google_sign_in` 7.2.0, `googleapis` 17.0.0, `extension_google_sign_in_as_googleapis_auth` 3.0.0, `local_auth` 3.0.2 (y `workmanager` del plan 3).

**Spec:** `docs/superpowers/specs/2026-10-08-nucleo-design.md` §5.11 (primer uso), §7 (backup, cifrado, restauración, seguridad local), §8 (errores). Planes 1–3: sus Global Constraints siguen vigentes.

## Global Constraints

- Todas las de los planes anteriores (migraciones con test sobre base con datos, `t.runAsync`, solo tokens e íconos de `lib/core/design`, nunca `flutter drive` con el applicationId real, implementador sin commits).
- **Repo público:** nunca commitear el client ID de OAuth, `google-services.json`, keystores ni contraseñas. El client ID de Android **no es secreto** (se identifica por package + SHA-1), pero igual se configura fuera del código (Google Cloud Console), sin archivos en el repo.
- Carpeta de Drive: **"Pockt · Backups"** (nombre configurable en Ajustes). Archivos: `pockt-AAAAMMDD-HHMMSS.pockt`. Se conservan las **últimas 7** copias.
- Formato `.pockt`: magic `POCKT1` (6 bytes) + versión de formato (1 byte) + sal Argon2id (16 bytes) + nonce (12 bytes) + texto cifrado AES-256-GCM (incluye el tag de 16 bytes) del contenido gzip de la base. Argon2id: memoria 64 MiB, 3 iteraciones, paralelismo 1, salida 32 bytes.
- La **contraseña de respaldo nunca se guarda**; la clave derivada sí, en `flutter_secure_storage` (Android Keystore). Al restaurar en otro teléfono se pide la contraseña.
- Automático **cada 2 días con WiFi** (`workmanager`, `NetworkType.unmetered`) y después de confirmar una tanda de sugeridos; aviso en el Inicio si pasan **5 días** sin backup exitoso.
- Restauración: **siempre** se guarda una copia local de la base actual antes de reemplazar; si algo falla, se vuelve a esa copia.
- Bloqueo: desactivado por defecto; se pide al abrir y al volver después de **1 minuto** en segundo plano; con bloqueo activo, `FLAG_SECURE`.

## Review Focus

1. **Contraseña incorrecta al restaurar:** mensaje claro, nada se reemplaza, se puede reintentar. → Task 1 y Task 5.
2. **Backup mientras se escribe un gasto:** `VACUUM INTO` produce una copia consistente; el gasto queda en la base y entra en el próximo backup. → Task 2.
3. **Restaurar un backup de un esquema más viejo** (por ejemplo v4 en una app v5): se migra al abrir, igual que una actualización. → Task 5.
4. **Carpeta borrada a mano en Drive:** el próximo backup la recrea; la poda de copias viejas no falla. → Task 3.
5. **Huella cancelada o sin huella registrada en el teléfono:** se ofrece el PIN del teléfono; si el dispositivo no tiene ningún bloqueo, la opción no se puede activar y se explica por qué. → Task 6.

---

## Estructura de archivos

```
lib/features/backup/domain/backup_format.dart      (encabezado, gzip, AES-GCM, Argon2id)
lib/features/backup/data/snapshot.dart             (VACUUM INTO a un archivo temporal)
lib/features/backup/data/backup_store.dart         (interfaz BackupStore + MemoryBackupStore)
lib/features/backup/data/drive_backup_store.dart   (Google Drive, drive.file)
lib/features/backup/data/key_storage.dart          (clave derivada en flutter_secure_storage)
lib/features/backup/domain/backup_service.dart     (orquestación, poda, estado)
lib/features/backup/domain/restore_service.dart    (vista previa, copia previa, reemplazo, vuelta atrás)
lib/features/backup/ui/backup_screen.dart          (Ajustes → Backup)
lib/features/backup/ui/restore_flow.dart
lib/features/security/app_lock.dart                (local_auth + ciclo de vida + FLAG_SECURE)
lib/features/onboarding/ui/onboarding_flow.dart
docs/backup-setup.md                                (guía para configurar Google Cloud)
```

---

### Task 1: Formato `.pockt` (cifrado y descifrado)

**Files:** Create `lib/features/backup/domain/backup_format.dart`; Test `test/features/backup/backup_format_test.dart`.

**Interfaces:**
- `Future<SecretKey> deriveKey(String password, List<int> salt)` (Argon2id con los parámetros de Global Constraints).
- `Future<List<int>> encodeBackup(List<int> sqliteBytes, SecretKey key, List<int> salt)` → bytes `.pockt`.
- `Future<List<int>> decodeBackup(List<int> pocktBytes, {required Future<SecretKey> Function(List<int> salt) keyFor})` → bytes SQLite; lanza `WrongPasswordException` si el tag no valida y `BadBackupFormatException` si el magic o la versión no coinciden.
- `List<int> readSalt(List<int> pocktBytes)`.

- [ ] **Step 1:** Tests que fallan: ida y vuelta devuelve los mismos bytes; contraseña incorrecta → `WrongPasswordException`; un byte alterado → `WrongPasswordException`; magic inválido → `BadBackupFormatException`; dos backups con la misma clave tienen nonces distintos. (Para que el test corra rápido, `deriveKey` acepta parámetros de memoria/iteraciones opcionales solo usados por tests.)
- [ ] **Step 2–4.** **Step 5:** Checkpoint. `feat: formato de backup cifrado`.

### Task 2: Instantánea de la base y almacenamiento de la clave

**Files:** Create `lib/features/backup/data/snapshot.dart`, `lib/features/backup/data/key_storage.dart`; Test `test/features/backup/snapshot_test.dart`, `test/features/backup/key_storage_test.dart`.

**Interfaces:**
- `Future<List<int>> snapshotDatabase(AppDatabase db)` — `VACUUM INTO` a un archivo temporal, lee los bytes y borra el temporal.
- `class KeyStorage { Future<void> saveKey(List<int> keyBytes, List<int> salt); Future<({List<int> key, List<int> salt})?> load(); Future<void> clear(); }` con `flutter_secure_storage` (en tests, un falso en memoria).

- [ ] **Step 1:** Tests que fallan: la instantánea abierta como base nueva tiene los mismos movimientos; un gasto escrito justo antes aparece; `KeyStorage` guarda, carga y borra.
- [ ] **Step 2–4.** **Step 5:** Checkpoint. `feat: instantánea de la base y almacenamiento seguro de la clave`.

### Task 3: BackupStore (interfaz, memoria y Google Drive)

**Files:** Create `lib/features/backup/data/backup_store.dart`, `lib/features/backup/data/drive_backup_store.dart`, `docs/backup-setup.md`; Test `test/features/backup/backup_store_test.dart`.

**Interfaces:**
- `class RemoteBackup { String id; String name; DateTime createdAt; int sizeBytes; }`
- `abstract class BackupStore { Future<void> upload(String name, List<int> bytes); Future<List<RemoteBackup>> list(); Future<List<int>> download(String id); Future<void> delete(String id); }`
- `MemoryBackupStore implements BackupStore` (tests).
- `DriveBackupStore` con `google_sign_in` (scope `https://www.googleapis.com/auth/drive.file`) + `googleapis` `drive/v3`: busca la carpeta por nombre entre los archivos que la app creó; si no existe, la crea; `list` ordena por fecha descendente.
- `docs/backup-setup.md`: guía paso a paso para el autor: crear proyecto en Google Cloud, pantalla de consentimiento en modo "En pruebas" con su cuenta como usuario de prueba, habilitar Drive API, crear credencial OAuth "Android" con `io.github.pacotez12.pockt` y el SHA-1 de su keystore de release (cómo sacarlo con `keytool`). Sin valores reales.

- [ ] **Step 1:** Tests que fallan sobre `MemoryBackupStore` (contrato: subir, listar ordenado, descargar, borrar). `DriveBackupStore` no tiene test automático (requiere cuenta real); se verifica en Task 8.
- [ ] **Step 2–4.** **Step 5:** Checkpoint. `feat: almacenamiento de backups en Google Drive`.

### Task 4: BackupService y Ajustes → Backup

**Files:** Create `lib/features/backup/domain/backup_service.dart`, `lib/features/backup/ui/backup_screen.dart`; Modify `lib/core/background/background_tasks.dart` (tarea `pockt-backup` cada 48 h, `NetworkType.unmetered`), `lib/features/recurring/...` (backup después de confirmar 3 o más sugerencias seguidas), `home_screen.dart` (aviso de 5 días), `settings_screen.dart`; Test `test/features/backup/backup_service_test.dart`, `test/features/backup/backup_screen_test.dart`.

**Interfaces:**
- `BackupService(AppDatabase db, BackupStore store, KeyStorage keys, SettingsRepository settings, {DateTime Function()? clock})`:
  - `Future<void> setPassword(String password)` (genera sal, deriva, guarda la clave).
  - `Future<BackupResult> backupNow()` — instantánea → formato → subida → poda a 7 → guarda `backup.lastSuccessAt`; errores tipados (`noPassword`, `notSignedIn`, `network`, `unknown`) guardados en `backup.lastError`.
  - `Stream<BackupStatus> watchStatus()` (último éxito, último error, `isOverdue` si pasaron 5 días).
- Pantalla: estado ("Último backup: hoy 08:12"), "Respaldar ahora" con progreso, cuenta de Google conectada / conectar, carpeta, cambiar contraseña de respaldo (advertencia), restaurar.

- [ ] **Step 1:** Tests que fallan (con `MemoryBackupStore`): `backupNow` sube un `.pockt` que se descifra a la misma base; con 8 backups previos quedan 7 (se borra el más viejo); sin contraseña → `noPassword` sin subir nada; `isOverdue` a los 5 días; un error se muestra en la pantalla.
- [ ] **Step 2–4.** **Step 5:** Checkpoint. `feat: backup automático cifrado y pantalla de backup`.

### Task 5: Restauración

**Files:** Create `lib/features/backup/domain/restore_service.dart`, `lib/features/backup/ui/restore_flow.dart`; Test `test/features/backup/restore_service_test.dart`, `test/features/backup/restore_flow_test.dart`.

**Interfaces:**
- `class RestorePreview { DateTime createdAt; int transactionCount; int schemaVersion; }`
- `RestoreService(...)`: `Future<RestorePreview> preview(String backupId, String password)` (descarga, descifra a un temporal, abre de solo lectura y cuenta); `Future<void> restore(String backupId, String password)` (copia local previa → reemplaza el archivo de la base → reabre → si falla, vuelve a la copia y relanza el error).
- Flujo: lista de backups → contraseña → vista previa "Backup del 24/10 · 1.243 movimientos" → confirmar → la app se reinicia sobre la base restaurada.

- [ ] **Step 1:** Tests que fallan: restaurar reemplaza los movimientos por los del backup; contraseña incorrecta no toca nada; un backup con esquema v4 se migra al reabrir; si el reemplazo falla a mitad, la base original queda intacta.
- [ ] **Step 2–4.** **Step 5:** Checkpoint. `feat: restauración de backups con vuelta atrás`.

### Task 6: Bloqueo con huella

**Files:** Create `lib/features/security/app_lock.dart`; Modify `lib/app.dart`, `MainActivity.kt` (`FLAG_SECURE` controlado desde Flutter por un `MethodChannel` `pockt/secure`), `settings_screen.dart`; Test `test/features/security/app_lock_test.dart`.

**Interfaces:**
- `class AppLockController` (con `LocalAuthentication` inyectable y reloj inyectable): `bool get locked`; `Future<bool> unlock()`; `void onPaused()`; `void onResumed()` (bloquea si pasó ≥ 1 min); `Future<AppLockAvailability> availability()` (`ready` | `noDeviceLock` | `unsupported`).
- Ajuste `security.lock` (`on`/`off`). Pantalla de bloqueo: orbe + "pockt", botón "Desbloquear"; con `biometricOnly: false` (permite PIN del teléfono).

- [ ] **Step 1:** Tests que fallan: con bloqueo activo, arrancar muestra la pantalla de bloqueo; volver a los 30 s no bloquea, a los 61 s sí; unlock cancelado mantiene bloqueado; sin bloqueo de dispositivo, el interruptor queda deshabilitado con la explicación.
- [ ] **Step 2–4.** **Step 5:** Checkpoint. `feat: bloqueo opcional con huella`.

### Task 7: Primer uso

**Files:** Create `lib/features/onboarding/ui/onboarding_flow.dart`; Modify `lib/app.dart` (si `onboarding.done` no está, mostrar el flujo); Test `test/features/onboarding/onboarding_flow_test.dart`.

Tres pasos, todos salteables, con el logotipo "pockt" arriba y la transición de la apertura (plan 3, Task 7b) llevando al primero: 1) **esquema de cobro** (reusa la pantalla del plan 2/3, con sueldo mensual y reparto); 2) **presupuestos** (sugerencia de 3 categorías con montos editables); 3) **backup** (conectar Google y elegir la contraseña de respaldo con la advertencia). Al terminar o saltear, `onboarding.done = true`. Una base con movimientos (app ya en uso) **no** muestra el primer uso.

- [ ] **Step 1:** Tests que fallan: base vacía → aparece el primer uso; con movimientos → no; saltear los 3 pasos lleva al Inicio y no vuelve a aparecer.
- [ ] **Step 2–4.** **Step 5:** Checkpoint. `feat: primer uso`.

### Task 8: Verificación final y v1.0.0 (con el autor)

- [ ] **Step 1** (autor + orquestador): seguir `docs/backup-setup.md` con la cuenta del autor; crear el keystore de release propio (fuera del repo) y registrar su SHA-1.
- [ ] **Step 2:** instalar release sobre la app real (`adb install -r`), activar backup, "Respaldar ahora", verificar el archivo en "Pockt · Backups" en Drive.
- [ ] **Step 3:** restaurar en Pockt Demo (otro applicationId) el backup real con la contraseña → vista previa correcta.
- [ ] **Step 4:** bloqueo con huella; primer uso en una instalación limpia de la demo.
- [ ] **Step 5:** README (estado: todos los planes ✅, privacidad) y tag `v1.0.0`.
