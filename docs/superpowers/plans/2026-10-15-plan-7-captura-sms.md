# Pockt — Plan 7: Captura automática de SMS de Itaú

Spec: `docs/superpowers/specs/2026-10-15-captura-sms-design.md` (citada como §n).

**Restricciones globales:** TDD (test que falla primero), `flutter test --timeout 30s`, `flutter analyze` en 0, sin `dart format` de carpetas enteras, íconos Phosphor (sin emojis), paleta §6.2b de la spec núcleo. Migraciones de Drift con test desde el schema actual sin pérdida de datos (los tests de migración viejos usan `greaterThanOrEqualTo`). Ajustes nuevos con valores por defecto que no cambian nada (captura apagada). Fixtures sanitizados: nunca números de cuenta ni nombres reales. No commitear, no usar el teléfono, no revertir archivos ajenos. Skills: `test-driven-development`, `systematic-debugging`, `emil-design-eng`, `ui-ux-pro-max` (flutter), `impeccable`.

**Orden:** después del plan 6 (pulido visual).

### Task 1: Parser puro (§3, §4.2)
**Files:** `lib/features/capture/domain/itau_sms_parser.dart`, `test/features/capture/itau_sms_parser_test.dart`.
- `parseItauSms(String body) → CaptureResult?` con `debit`, `salaryCredit`, `ignored`, `unrecognized`.
- Tests con todas las muestras de §3 sanitizadas: relleno `*` variable (`Gs.**1.200.500`, `Gs.******7.162`), referencias numéricas finales, descripción cortada, acreditación sin monto, SMS de TC/promos ignorados, débito con formato roto → `unrecognized`.

### Task 2: Clasificador (§4.3)
**Files:** `lib/features/capture/domain/capture_classifier.dart` + test.
- Entrada: `CaptureResult` + datos (memoria de comercios, recurrentes, préstamos activos, sugerencias de cobro pendientes). Salida: qué sugerencia crear o qué confirmar.
- Tests: comercio conocido/desconocido; `Pago de factura` ↔ recurrente (±10 %, ±5 días) reemplaza su sugerencia; `Pago de Prestamos` ↔ préstamo (±5 %); `Pago de tarjeta` → transferencia; sueldo confirma la sugerencia del esquema (±3 días) o crea una de ingreso.

### Task 3: Modelo y migración (§5)
**Files:** `lib/core/db/tables.dart`, `app_database.dart`, migración + test.
- Tipo transferencia para pagos de tarjeta (decidir: `TxType.transfer` vs columna `kind`); excluirlo de todos los totales (gastado, presupuestos, reportes, calendario, quedan, saldo arrastrado, Podés gastar hoy, CSV con columna tipo). Tests que lo prueben en cada cálculo.
- `autoConfirm` por comercio; clave de duplicado única en `suggested_transactions.fingerprint`.

### Task 4: Duplicados y servicio de captura (§4.4)
**Files:** `lib/features/capture/data/capture_service.dart`, interfaz `SmsSource` (falsa en tests) + test.
- `ingest(List<RawSms>)`: parsea, clasifica, deduplica (fingerprint; manual ±2 h → "posible duplicado"), crea sugerencias o confirma; respeta `capture.since` y actualiza `capture.lastSmsAt`; notificación "Tenés N movimientos por confirmar".

### Task 5: Canal nativo Android (§4.1)
**Files:** `android/.../SmsCapture.kt` (receptor `SMS_RECEIVED` + lectura de `content://sms/inbox` por remitente y fecha), `MainActivity.kt` (canal `pockt/sms`), `AndroidManifest.xml` (`RECEIVE_SMS`, `READ_SMS`), `lib/features/capture/data/android_sms_source.dart`.
- El receptor guarda en la base aunque la app esté cerrada (isolate de fondo como `background_tasks.dart`, con `tz.initializeTimeZones()`).
- Relectura al abrir/volver a la app (`app.dart`, junto a `SuggestionGenerator`).
- Sin permiso o con la captura apagada: no hace nada.

### Task 6: Bandeja y Ajustes (§4.5, §4.6)
**Files:** `inbox_screen.dart` (ícono `chat-text`, "Ver mensaje", "posible duplicado" con Es el mismo / Es otro, "Confirmar siempre este comercio"), `settings_screen.dart` (Tu dinero → Captura automática: interruptor con explicación y pedido de permisos, estado, comercios automáticos, leer desde), Movimientos con estilo neutro para transferencias.
- Tests de widgets: confirmar, posible duplicado, auto-confirmación por comercio, interruptor apagado no pide permisos.

### Task 7: Verificación en el A54 (orquestador)
- Demo con la captura activada: relectura del buzón real desde el 15/10, revisar sugerencias contra los SMS, probar un SMS nuevo en vivo. Nunca en la app real hasta que el usuario lo apruebe.
