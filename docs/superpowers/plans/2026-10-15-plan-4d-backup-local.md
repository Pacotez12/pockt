# Pockt — Plan 4d: Backup local automático + compartir (sin Google Drive)

**Spec:** §7 (decisión 2026-10-15). **Global Constraints:** las de los planes anteriores; TDD donde hay lógica; datos reales del autor desde el 2026-10-15 (instalar siempre con `install -r`).

### Task 1: Archivos en Documentos/Pockt (Android)
`MainActivity.kt`: canal `pockt/backup_files` con `save(name, bytes)` (MediaStore `Documents/Pockt`, API ≥ 29; en 26–28 carpeta externa de la app), `list()` (id, nombre, tamaño, fecha; solo `.pockt` propios), `read(id)`, `delete(id)` y `pickFile()` (`ACTION_OPEN_DOCUMENT`, devuelve bytes y nombre). `LocalBackupStore` (Dart) implementa `BackupStore` sobre ese canal; `backupStoreProvider` lo usa (hoy usaba `MemoryBackupStore`: los backups no se guardaban). Tests con el canal simulado.

### Task 2: Backup automático en primer plano y aviso
`BackupService.backupIfDue()` (contraseña configurada y último éxito ≥ 48 h o nunca) llamado al abrir y al volver a la app; se cancela la tarea `pockt-backup` de Workmanager. `isOverdue` también cuando nunca hubo backup. Se quitan los errores de Drive (`notSignedIn`) y `network` pasa a `storage`. Tests.

### Task 3: Exportar y restaurar desde archivo
Exportar: `.pockt` nuevo → menú de compartir. Restaurar: lista local + "Elegir archivo…" (`RestoreService.restoreFromBytes`). Pantalla de backup sin textos de Drive. Tests.

### Task 4: Quitar Drive
Borrar `drive_backup_store.dart`, sus tests, `docs/backup-setup.md`, la clave `backup.googleAccount` y las dependencias de Google. Suite y analyze en verde; prueba en el A54 (backup, archivo en Documentos/Pockt, exportar, restaurar desde archivo).
