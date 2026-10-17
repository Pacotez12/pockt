# Captura por correo (Gmail) Implementation Plan

> **For agentic workers:** implementá tarea por tarea con TDD (`test-driven-development`). Steps con checkbox (`- [ ]`). No commitees: el orquestador revisa y commitea cada tarea.

**Goal:** Leer de Gmail los correos de Itaú (transferencias enviadas/recibidas y pagos de servicios) y convertirlos en movimientos o sugerencias de la bandeja, sin duplicar lo que llega por SMS.

**Architecture:** Plugin Flutter local `packages/pockt_gmail` (Kotlin, `AuthorizationClient` de Play Services + REST de Gmail con `HttpURLConnection`) para que funcione también en el isolate de Workmanager. Dart: parser puro → clasificador puro → `EmailCaptureService` (dedupe, reglas por persona, notificaciones) → bandeja y Ajustes existentes.

**Tech Stack:** Flutter 3.47, Drift (schema v13 → v14), Riverpod 3, Workmanager 0.10.10, Kotlin, `com.google.android.gms:play-services-auth`.

**Spec:** `docs/superpowers/specs/2026-10-17-captura-correo-design.md` (y la de SMS `2026-10-15-captura-sms-design.md` para las reglas compartidas).

## Global Constraints

- Flutter/dart en `~/Proyectos/flutter/bin/` (no están en PATH). Tests: `flutter test --timeout 30s`. Analyze en 0.
- Sin dependencias Dart nuevas en la app (solo la path dependency `pockt_gmail`). En Android solo se suma `play-services-auth`.
- Permiso único `https://www.googleapis.com/auth/gmail.readonly`; consulta siempre `from:info@itau.com.py`.
- La app no lleva client ID ni secretos (Play Services usa paquete + SHA-1).
- Nunca guardar números de cuenta, tokens ni cuerpos completos. Fixtures inventados (JUAN PEREZ, MARIA LOPEZ, `****XXXX`, operaciones en cero). Ningún dato real en tests ni código.
- Interruptor apagado por defecto; con él apagado no se llama a Google.
- No cambiar el modelo de Préstamos: pagos con `LoansRepository.recordPayment`, préstamo dado con `createLoan(direction: lent, recordInitialDisbursement: true)`.
- Textos de UI en español rioplatense, mismos tokens/íconos (`uiIcon`) que el resto; `tokens_test` y `ui_icons_used_test` en verde.
- Migraciones: tests con `greaterThanOrEqualTo` en la versión.
- Sin `dart format` de carpetas enteras. NO usar el teléfono (el orquestador prueba en el A54).

## Review Focus

1. Correo cuyo HTML trae `&nbsp;`, `<br>` o celdas vacías (ej. "Concepto de la Transferencia: | |") → el parser lee igual monto y persona; concepto vacío queda `null`. Test en Task 1.
2. Mismo pago llega por SMS y por correo con minutos de diferencia y en cualquier orden → un solo movimiento. Test en Task 5 (ambos órdenes).
3. Google revoca el acceso con la lectura en segundo plano → sin excepción no manejada, `needsReconnect` guardado y una sola notificación (no una cada 15 min). Test en Task 5.
4. Regla recordada que apunta a un préstamo borrado o cerrado → vuelve a la bandeja, nunca crea un pago huérfano. Test en Task 4.
5. Muchos correos en la primera lectura (fecha de 30 días atrás) → paginación completa, orden por fecha, `emailLastAt` = el más nuevo procesado. Test en Task 5 con 120 correos falsos.

---

### Task 1: Parser de correos Itaú

**Files:**
- Create: `lib/features/capture/domain/itau_email_parser.dart`
- Test: `test/features/capture/itau_email_parser_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum EmailCaptureKind { transferOut, transferIn, servicePayment, ignored, unrecognized }
  class EmailCapture {
    final EmailCaptureKind kind; final String messageId;
    final int? amount; final DateTime? occurredAt; final bool hasTime;
    final String? counterparty; final String? payer; final String? entity; final String? concept;
    final String? operationId; final String sanitizedRawText;
    String get fingerprint => 'email:$messageId';
  }
  EmailCapture parseItauEmail({required String messageId, required String subject, required String bodyText, required DateTime receivedAt});
  String normalizePersonKey(String name); // mayúsculas, sin tildes, espacios simples
  ```

- [ ] **Step 1: Tests que fallan** con los 3 fixtures de la spec §3 (copiarlos tal cual, sanitizados):
  - `transferencia enviada` → `transferOut`, `amount == 15000`, `occurredAt == DateTime(2026,10,10,12,47)`, `hasTime`, `counterparty == 'PEDRO GOMEZ'`, `payer == 'JUAN PEREZ'`, `entity == 'BANCO EJEMPLO SAECA'`, `concept == null`.
  - `transferencia recibida` → `transferIn`, `amount == 30000` (de `PYG 30,000`), `occurredAt == DateTime(2026,10,10,12,47,20)`, `counterparty == 'MARIA LOPEZ'`, `concept == '/BNF/'`.
  - `pago de servicios` → `servicePayment`, `amount == 95000`, `hasTime == false`, `occurredAt == receivedAt`, `concept == 'Claro - Pago de factura con CI'`; variante `1,200,500` → `1200500`.
  - asunto `Tu código de seguridad` → `ignored`; asunto `Aviso de transferencia enviada` sin "Moneda y Monto" → `unrecognized`.
  - celdas con `&nbsp;`/espacios dobles (Review Focus 1) parsean igual.
  - `sanitizedRawText` no contiene la palabra "cuenta" seguida de dígitos ni `****XXXX`; contiene persona, monto y fecha.
  - `normalizePersonKey('  María  López ') == 'MARIA LOPEZ'`.
- [ ] **Step 2:** `flutter test test/features/capture/itau_email_parser_test.dart` → FAIL (no existe).
- [ ] **Step 3:** Implementar. Campos por regex `Etiqueta:\s*\|\s*(.*?)\s*\|` sobre el texto plano; monto: quitar `Gs.`, `PYG`, `.` y `,` → `int`; fecha `dd/MM/yyyy( HH:mm(:ss)?)?`. Asuntos reconocidos (sin distinguir mayúsculas): `Aviso de transferencia enviada`, `Aviso de transferencia recibida`, `AVISO DE PAGO DE SERVICIOS`.
- [ ] **Step 4:** test → PASS.

### Task 2: Plugin `pockt_gmail` + `EmailSource` + prueba de segundo plano

**Files:**
- Create: `packages/pockt_gmail/pubspec.yaml`, `packages/pockt_gmail/lib/pockt_gmail.dart`, `packages/pockt_gmail/android/build.gradle(.kts)`, `packages/pockt_gmail/android/src/main/kotlin/io/github/pacotez12/pockt_gmail/PocktGmailPlugin.kt`
- Create: `lib/features/capture/data/email_source.dart`
- Modify: `pubspec.yaml` (path dependency `pockt_gmail: {path: packages/pockt_gmail}`)
- Modify: `lib/features/capture/ui/capture_settings_screen.dart` (tile solo `kDebugMode`, ver Step 4)
- Modify: `lib/core/background/background_tasks.dart` (tarea one-off `pockt-email-probe`, solo debug)
- Test: `test/features/capture/email_source_test.dart`

**Interfaces:**
- Plugin (MethodChannel `pockt/gmail`, `FlutterPlugin` + `ActivityAware`, así se registra solo en cualquier engine):
  - `authorize` → `'connected' | 'cancelled'` (lanza el `PendingIntent` de `AuthorizationClient` desde la Activity si hace falta).
  - `fetchSince({sinceMillis: int})` → `List<Map>` `{id, internalDate (int ms), subject, bodyText}`. Token con `Identity.getAuthorizationClient(applicationContext).authorize(...)`; si `hasResolution()` → error `PlatformException(code: 'needsReconnect')` sin abrir nada. `messages.list` (`q=from:info@itau.com.py after:<epochSeconds>`, todas las páginas) + `messages.get?format=full`; cuerpo: parte `text/html` (o `text/plain`) decodificada base64url y pasada a texto con `Html.fromHtml(..., FROM_HTML_MODE_COMPACT)`, celdas `<td>` separadas por ` | ` antes de convertir para conservar el formato "Campo: | Valor |".
  - `disconnect` → `revokeAccess` + `clearToken`.
- Dart (`email_source.dart`):
  ```dart
  class RawEmail { final String id; final DateTime receivedAt; final String subject; final String bodyText; }
  class GmailReconnectRequired implements Exception {}
  abstract class EmailSource {
    Future<bool> authorize();                 // true si quedó conectado
    Future<List<RawEmail>> fetchSince(DateTime since); // lanza GmailReconnectRequired
    Future<void> disconnect();
  }
  class AndroidEmailSource implements EmailSource { ... }   // usa pockt_gmail
  class FakeEmailSource implements EmailSource { List<RawEmail> inbox; bool connected; bool requireReconnect; int fetchCalls; }
  ```

- [ ] **Step 1:** Test `FakeEmailSource`: `fetchSince` filtra por fecha, lanza `GmailReconnectRequired` si `requireReconnect`; `AndroidEmailSource` mapea `internalDate` ms → `DateTime` local y `PlatformException('needsReconnect')` → `GmailReconnectRequired` (con `TestDefaultBinaryMessengerBinding` mockeando el canal).
- [ ] **Step 2:** FAIL. **Step 3:** implementar plugin y fuentes. **Step 4:** PASS + `flutter analyze` 0 + `flutter build apk --debug -PpocktDemo` compila.
- [ ] **Step 5 (prueba de segundo plano, para el orquestador):** tile `if (kDebugMode)` "Gmail: probar" en Captura: llama `authorize()`, luego `fetchSince(now − 7 días)` y muestra la cantidad; además registra `Workmanager().registerOneOffTask('pockt-email-probe', 'pockt-email-probe', initialDelay: 1 min)` cuyo handler en `callbackDispatcher` hace `fetchSince(now − 7 días)` y publica una notificación local `Gmail en segundo plano: N correos` (o `…: necesita reconectar`). Reportar al orquestador y no seguir con Task 6 hasta que confirme el resultado en el A54. Este tile y la tarea probe se borran en Task 6.

### Task 3: Migración v14 y ajustes

**Files:**
- Modify: `lib/core/db/tables.dart`, `lib/core/db/app_database.dart` (`schemaVersion => 14`, bloque `if (from < 14)`), `lib/core/settings/settings_repository.dart`
- Create: `lib/features/capture/data/counterparty_rules_repository.dart`
- Test: `test/core/db/migration_v14_test.dart`, `test/features/capture/counterparty_rules_repository_test.dart`

**Interfaces:**
- Tabla `CounterpartyRules`: `id` text PK, `nameKey` text, `direction` textEnum `TransferDirection {incoming, outgoing}`, `action` textEnum `CounterpartyAction {income, expense, loanRepayment, loanLent, loanPayment, ignore}`, `categoryId` text? → Categories, `loanId` text? → Loans, `autoApply` bool default false, `updatedAt` dateTime; unique (`nameKey`, `direction`).
- `SuggestedTransactions.captureMeta` text nullable (JSON: `{"channel":"sms|email","kind":"transferOut|transferIn|servicePayment|debit","person":String?,"operationId":String?,"concept":String?}`).
- SettingsKeys: `captureEmailEnabled = 'capture.emailEnabled'`, `captureEmailSince = 'capture.emailSince'`, `captureEmailLastAt = 'capture.emailLastAt'`, `captureEmailOwnerName = 'capture.emailOwnerName'`, `captureEmailUnrecognized = 'capture.emailUnrecognized'`, `captureEmailNeedsReconnect = 'capture.emailNeedsReconnect'` + providers stream como los de SMS.
- `CounterpartyRulesRepository(db)`: `Future<CounterpartyRule?> find(String nameKey, TransferDirection d)`, `Future<void> upsert({nameKey, direction, action, categoryId, loanId, autoApply})`, `Stream<List<CounterpartyRule>> watchAll()`, `Future<void> delete(String id)`.

- [ ] **Step 1:** Test migración desde un archivo v13 creado con `sqlite3` (patrón de `migration_v13_test.dart`): tras abrir, existen `counterparty_rules` y `suggested_transactions.capture_meta`, los datos previos siguen, `user_version >= 14`. Test repo: `upsert` dos veces mismo (`nameKey`, `direction`) deja una fila con la última acción.
- [ ] **Step 2:** FAIL. **Step 3:** implementar + `build_runner`. **Step 4:** PASS.

### Task 4: Clasificador de correos

**Files:**
- Create: `lib/features/capture/domain/email_classifier.dart`
- Test: `test/features/capture/email_classifier_test.dart`

**Interfaces:**
- Consumes: `EmailCapture` (Task 1), `classifyCapture` y candidatos existentes de `capture_classifier.dart`, `CounterpartyAction`/`TransferDirection` (Task 3).
- Produces:
  ```dart
  enum EmailOutcomeKind { autoApply, inbox, serviceClassified, ignored, unrecognized }
  class EmailRuleView { final CounterpartyAction action; final String? categoryId; final String? loanId; final bool autoApply; }
  class EmailClassification {
    final EmailOutcomeKind kind;
    final CounterpartyAction? suggestedAction; final String? categoryId; final String? loanId;
    final CaptureClassification? service; // solo servicePayment
  }
  EmailClassification classifyEmail(EmailCapture c, {
    EmailRuleView? rule, Set<String> activeLoanIds = const {}, String? ownerNameKey,
    /* para servicePayment, mismos parámetros que classifyCapture: */
    Map<String,String> merchantMemory = const {}, List<CaptureRecurringCandidate> recurringRules = const [],
    List<CaptureLoanCandidate> activeLoans = const [], String? loansCategoryId, String? cardsCategoryId,
  });
  ```
- [ ] **Step 1: Tests**
  - recibida sin regla → `inbox`, `suggestedAction == income`.
  - recibida con regla `autoApply` `income`/cat X → `autoApply`, `categoryId == X`.
  - regla `loanRepayment` con `loanId` fuera de `activeLoanIds` → `inbox` (Review Focus 4).
  - recibida o enviada con `normalizePersonKey(counterparty) == ownerNameKey` → `inbox`, `suggestedAction == ignore`.
  - enviada con regla `autoApply: true` (no debería existir) → igual `inbox`, precargada con la acción de la regla.
  - servicePayment `Claro - Pago de factura con CI` con recurrente de 95.000 → `serviceClassified` y `service.kind == recurringServicePayment`; `Bancop - Pago de tarjeta con cédula` → `service.kind == cardPaymentTransfer` (gasto en Tarjetas, como el SMS).
- [ ] **Step 2:** FAIL. **Step 3:** implementar; para servicios construir un `CaptureResult(kind: debit, amount, description: concept con ' - ' → ' ', merchantKey, occurredAt)` y delegar en `classifyCapture`. **Step 4:** PASS.

### Task 5: `EmailCaptureService` (lectura, dedupe, reglas)

**Files:**
- Create: `lib/features/capture/data/email_capture_service.dart`
- Modify: `lib/features/capture/data/capture_service.dart` (SMS: unión con captura de correo, ver Step 3), providers (`emailCaptureServiceProvider`)
- Test: `test/features/capture/email_capture_service_test.dart`

**Interfaces:**
- Consumes: Tasks 1–4, `SuggestionsRepository`, `LoansRepository`, `TransactionsRepository`, `Notifier`.
- Produces:
  ```dart
  class EmailCaptureService {
    EmailCaptureService({required AppDatabase db, required Notifier notifier, required EmailSource source, DateTime Function()? clock});
    Future<int> sync({bool notify = true}); // no-op si capture.emailEnabled != 'true'; devuelve sugerencias pendientes nuevas
    Future<int> ingest(List<RawEmail> emails, {bool notify = true});
    Future<bool> connect({required DateTime since}); // authorize + guarda enabled/since/ownerName vacío
    Future<void> disconnect();                        // source.disconnect + enabled=false
  }
  ```
- Reglas que fijan los tests:
  - lee desde `max(emailSince, emailLastAt)`; `emailLastAt` = `receivedAt` más nuevo procesado.
  - fingerprint `email:<id>` existente → saltar.
  - `inbox` → `SuggestionsRepository.createIfAbsent` con `source: capture`, `fingerprint`, `rawText = sanitizedRawText`, `captureMeta` (channel `email`), tipo `income` para entrada y `expense` para salida, `categoryId` precargado.
  - `autoApply` → ejecuta la acción (income → `TransactionsRepository` normal; `loanRepayment` → `recordPayment`) y notifica `Ingreso registrado: <persona> Gs. <monto>`.
  - `serviceClassified` → mismo camino que el SMS para esa clasificación (extraer a una función compartida de `CaptureService` si hace falta, sin cambiar su comportamiento).
  - unión SMS↔correo: si existe sugerencia o movimiento con `captureMeta.channel == 'sms'` (o `fingerprint` `sms:`), mismo `type`, mismo `amount`, mismo día local → no crear; completar su `captureMeta` con `operationId`/`concept`. Simétrico en `CaptureService.ingest` del SMS contra `channel == 'email'`.
  - manual duplicado: misma regla y ventana que SMS (±2 h; día completo si `!hasTime`) → sugerencia `posible duplicado`.
  - `GmailReconnectRequired` → guardar `captureEmailNeedsReconnect = 'true'`, notificar "Volvé a conectar Gmail" solo si antes era `false`, devolver 0. `connect` exitoso lo limpia.
  - primera transferencia enviada procesada fija `captureEmailOwnerName` con `normalizePersonKey` del pagador si estaba vacío (el pagador de una enviada es el titular).
  - `unrecognized` → `captureEmailUnrecognized + 1`.
- [ ] **Step 1: Tests** (DB en memoria + `FakeEmailSource`): interruptor apagado → `fetchCalls == 0`; mismo correo dos veces → 1 sugerencia; recibida con regla → movimiento + notificación, sin sugerencia; correo→SMS y SMS→correo del mismo pago (95.000, mismo día) → 1 sola entrada en ambos órdenes (Review Focus 2); manual 95.000 a la 1 h → `posible duplicado`; reconexión dos syncs seguidos → 1 notificación (Review Focus 3); 120 correos en 3 "páginas" desordenadas → 120 procesados y `emailLastAt` el más nuevo (Review Focus 5); ownerName se fija con la primera enviada.
- [ ] **Step 2:** FAIL. **Step 3:** implementar. **Step 4:** PASS + suite completa de `test/features/capture/` en verde (los tests de SMS no cambian).

### Task 6: Lectura al abrir y cada 15 minutos

**Files:**
- Modify: `lib/app.dart` (junto a `_runSmsCaptureSync`), `lib/core/background/background_tasks.dart`, `lib/features/capture/ui/capture_settings_screen.dart` (borrar tile debug), `lib/main.dart` si registra tareas
- Test: `test/core/background/background_tasks_test.dart` (o el existente más cercano)

**Interfaces:**
- `callbackDispatcher` distingue `task == 'pockt-email'` → construye `EmailCaptureService(db, LocalNotifier(), AndroidEmailSource())` y llama `sync()`; el resto de tareas sin cambios. Borrar `pockt-email-probe`.
- `initBackgroundTasks()` registra además `registerPeriodicTask('pockt-email','pockt-email', frequency: 15 min, existingWorkPolicy: keep, constraints: Constraints(networkType: NetworkType.connected))`.
- [ ] **Step 1:** Test de la función pura que elige qué correr por nombre de tarea (extraer `Future<bool> runBackgroundTask(String task, BackgroundDeps deps)` si hace falta para testear): `'pockt-email'` llama solo a email sync; `'pockt-daily'` no lo llama.
- [ ] **Step 2–4:** FAIL → implementar → PASS. Al abrir la app: `unawaited(ref.read(emailCaptureServiceProvider).sync().catchError((_) => 0))`.

### Task 7: Bandeja: confirmación de correos

**Files:**
- Modify: `lib/features/recurring/ui/suggestion_card.dart`, `lib/features/recurring/ui/suggestion_card_parts.dart`
- Create: `lib/features/capture/ui/transfer_confirm_sheet.dart`
- Modify: `lib/core/design/icons.dart` (agregar `envelope-simple` si falta)
- Test: `test/features/capture/transfer_confirm_sheet_test.dart`

**Interfaces:**
- Consumes: `captureMeta` (Task 3), `CounterpartyRulesRepository` (Task 3), `LoansRepository`, `SuggestionsRepository.confirm/dismiss`.
- `showTransferConfirmSheet(BuildContext, SuggestedTransaction s)`. Opciones según `captureMeta.kind`:
  - `transferIn`: **Ingreso** (picker de categoría de ingreso), **Me pagaron un préstamo** (préstamos `lent` activos), **No contar**.
  - `transferOut`: **Gasto** (categoría de gasto), **Le presté a alguien** (crea `lent` con `name` = persona, `totalAmount` = monto, `recordInitialDisbursement: true`), **Pagué una deuda** (préstamos `owe` activos → `recordPayment`), **No contar**.
  - Opción preseleccionada = la de la sugerencia (`categoryId` / acción en `captureMeta`).
- Al confirmar: ejecutar la acción, marcar la sugerencia confirmada (o `dismiss` para No contar) y `upsert` de la regla: entrada → `autoApply: true`; salida → `autoApply: false`.
- Tarjeta: ícono `envelope-simple` para `channel == 'email'`, "Ver mensaje" con `rawText`.
- [ ] **Step 1: Tests de widget:** recibida → 3 opciones, elegir Ingreso + categoría → existe movimiento y regla `autoApply: true`; enviada → 4 opciones, "Le presté a alguien" → préstamo `lent` nuevo y gasto en Préstamos; "No contar" → sin movimiento y sugerencia descartada; tarjeta de correo muestra el ícono de sobre.
- [ ] **Step 2–4:** FAIL → implementar → PASS (skills `emil-design-eng`, `impeccable`: mismo estilo que las hojas existentes).

### Task 8: Ajustes → Captura → Correo

**Files:**
- Modify: `lib/features/capture/ui/capture_settings_screen.dart` (sección nueva; si pasa ~400 líneas, mover la sección a `lib/features/capture/ui/email_capture_section.dart`)
- Test: `test/features/capture/capture_ui_test.dart` (agregar casos)

**Interfaces:**
- Consumes: `emailCaptureServiceProvider.connect/disconnect`, providers de Task 3, `CounterpartyRulesRepository.watchAll/delete`.
- Contenido (spec §4.8): interruptor **Leer correos de Itaú (Gmail)** → hoja explicativa ("Solo se leen los correos de info@itau.com.py, en modo lectura. Todo queda en tu teléfono.") → `connect(since:)` con selector de fecha (por defecto 15/10/2026); estado (último leído, capturados este mes, no reconocidos); aviso si `needsReconnect` con botón **Volver a conectar**; lista **Personas recordadas** (persona, acción) con quitar; **Desconectar Gmail**.
- [ ] **Step 1: Tests:** apagado por defecto; activar con `FakeEmailSource(connected: true)` guarda enabled y since; cancelar la ventana deja apagado; quitar una persona la borra; `needsReconnect` muestra el aviso.
- [ ] **Step 2–4:** FAIL → implementar → PASS. Suite completa + analyze 0.

### Task 9: Verificación en el A54 y README (orquestador)

- [ ] Demo: conectar Gmail, leer desde 7 días atrás, confirmar una recibida (queda regla), ver que la siguiente se registra sola, confirmar una enviada, ver que el pago de servicios no se duplica con el SMS.
- [ ] Forzar la tarea periódica con la app cerrada (`adb shell cmd jobscheduler run -f io.github.pacotez12.pockt.demo <jobId>`) y ver la notificación.
- [ ] README: sección de captura (correo) y privacidad.
- [ ] Instalar la real con `install -r` cuando el usuario lo pida; el interruptor lo activa el usuario.
