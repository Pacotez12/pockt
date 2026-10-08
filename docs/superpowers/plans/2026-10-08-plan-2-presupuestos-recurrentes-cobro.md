# Pockt — Plan 2: presupuestos, recurrentes, esquema de cobro y bandeja de sugeridos

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pockt v0.2.0: presupuestos mensuales por categoría con alertas al 80 % y 100 %, gastos recurrentes y cobros (quincenal o mensual) que llegan como sugerencias a una bandeja para confirmar, la línea de quincena en el Inicio y un hub de Ajustes.

**Architecture:** Igual que el plan 1: lógica de fechas en funciones puras testeadas (`domain/`), repositorios Drift (`data/`), providers Riverpod y UI con los tokens de `lib/core/design`. Las sugerencias se generan de forma idempotente al abrir la app y al volver a primer plano; las notificaciones pasan por un servicio con interfaz para poder probarlo con un falso.

**Tech Stack:** el del plan 1 + `flutter_local_notifications` 22.3.1.

**Spec:** `docs/superpowers/specs/2026-10-08-nucleo-design.md` (§4 modelo, §5.2 línea de quincena y tarjeta de sugeridos, §5.5 presupuestos, §5.7 bandeja, §5.10 ajustes). Plan anterior: `docs/superpowers/plans/2026-10-08-plan-1-base-carga-inicio.md` (sus Global Constraints siguen vigentes).

## Global Constraints

- Todas las del plan 1 (montos `int` PYG, UTC + zona del teléfono, UUID, sin emojis, solo tokens de `lib/core/design`, íconos de `icons.dart`, mensajes de commit sin atribución, implementador sin commits).
- **La app está instalada con datos reales:** todo cambio de esquema es una migración (v2 → v3) con test que parte de una base v2 con movimientos.
- **Nunca correr `flutter drive` con el applicationId real** (desinstala y borra datos): mediciones solo con `-P pocktPerf=true`.
- Tests de widgets que leen streams de Drift: `t.runAsync(...)`.
- Generación de sugerencias **idempotente**: abrir la app 10 veces el mismo día no crea duplicados.
- Fechas de cobro y recurrentes calculadas en el **día local**; una sugerencia de un día que ya pasó se crea igual (catch-up), con su fecha original.
- En v0.2 las sugerencias se generan al abrir/volver a la app. La generación en segundo plano (sin abrir la app) queda para el plan 3, junto con los recordatorios.

## Review Focus

1. **Fin de mes y febrero:** cobro "último día" en febrero 2027 (28) y 2028 (29); recurrente día 31 en meses de 30 días → último día del mes. → Task 1.
2. **Cobro en fin de semana** con `shiftToPreviousBusinessDay`: 15 cae sábado → viernes 14; cae domingo → viernes 13. → Task 1.
3. **Catch-up después de días sin abrir la app:** se crean todas las sugerencias vencidas, cada una con su fecha, sin duplicar. → Task 3.
4. **Alertas una sola vez por mes:** borrar y volver a cargar un gasto que cruza el 80 % no re-notifica ese mes; el mes siguiente sí. → Task 4.
5. **Confirmar una sugerencia dos veces** (doble toque) crea un único movimiento. → Task 3.

---

## Estructura de archivos

```
lib/core/db/tables.dart, app_database.dart        (v3: índice único de sugerencias)
lib/core/notifications/notifier.dart               (interfaz Notifier + implementación con flutter_local_notifications)
lib/features/income/domain/pay_days.dart           (fechas de cobro)
lib/features/income/data/income_schedule_repository.dart
lib/features/income/ui/income_schedule_screen.dart
lib/features/recurring/domain/recurrence.dart      (próximas ocurrencias)
lib/features/recurring/data/recurring_repository.dart
lib/features/recurring/data/suggestions_repository.dart
lib/features/recurring/domain/suggestion_generator.dart
lib/features/recurring/ui/recurring_screen.dart
lib/features/recurring/ui/inbox_screen.dart
lib/features/budgets/domain/budget_status.dart
lib/features/budgets/data/budgets_repository.dart
lib/features/budgets/ui/budgets_screen.dart
lib/features/settings/ui/settings_screen.dart      (hub)
lib/features/home/ui/home_screen.dart              (línea de quincena + tarjeta de sugeridos)
```

---

### Task 1: Fechas de cobro y de recurrentes (funciones puras)

**Files:**
- Create: `lib/features/income/domain/pay_days.dart`, `lib/features/recurring/domain/recurrence.dart`
- Test: `test/features/income/pay_days_test.dart`, `test/features/recurring/recurrence_test.dart`

**Interfaces:**
- `enum PayMode { biweekly, monthly }`
- `List<DateTime> payDaysInMonth(int year, int month, List<int> payDays, {required bool shiftToPreviousBusinessDay})` — `-1` = último día; días > largo del mes = último día; resultado ordenado, sin repetidos.
- `DateTime? nextPayDay(DateTime fromLocalDay, List<int> payDays, {required bool shiftToPreviousBusinessDay})` — primer día de cobro ≥ `fromLocalDay`.
- `enum RecurrenceFrequency { monthly, weekly, yearly }`
- `DateTime nextOccurrence(DateTime afterLocalDay, {required RecurrenceFrequency frequency, int? dayOfMonth, int? dayOfWeek, int? monthOfYear})` — estrictamente después de `afterLocalDay`; `dayOfMonth` mayor al largo del mes = último día.
- `List<DateTime> dueOccurrences(DateTime nextDueDate, DateTime todayLocal, {required RecurrenceFrequency frequency, int? dayOfMonth, int? dayOfWeek, int? monthOfYear})` — todas las fechas desde `nextDueDate` hasta hoy inclusive.

- [ ] **Step 1: Tests que fallan:**
  - `payDaysInMonth(2026, 10, [15, -1], shift: false)` → 15/10 y 31/10.
  - Febrero: `[15, -1]` en 2027 → 15 y 28; en 2028 → 15 y 29.
  - Corrimiento: noviembre 2026, 15 es domingo → viernes 13; agosto 2026, 15 es sábado → viernes 14; último día de enero 2027 (domingo 31) → viernes 29.
  - Sin corrimiento: `nextPayDay(14/10/2026, [15,-1])` → 15/10; `nextPayDay(16/10/2026, …)` → 31/10. Con corrimiento: `nextPayDay(16/10/2026, …)` → viernes 30/10 (31/10/2026 es sábado); `nextPayDay(1/11/2026, …)` → viernes 13/11.
  - Recurrente mensual día 31 desde 31/1/2027 → 28/2/2027 → 31/3/2027.
  - Semanal `dayOfWeek: 1` (lunes) desde jueves 8/10/2026 → lunes 12/10.
  - Anual 15/3 desde 15/3/2026 → 15/3/2027.
  - `dueOccurrences` mensual día 5, `nextDueDate` 5/8, hoy 8/10 → [5/8, 5/9, 5/10].
- [ ] **Step 2:** FAIL. **Step 3:** Implementar. **Step 4:** PASS.
- [ ] **Step 5:** Checkpoint. Mensaje sugerido: `feat: cálculo de días de cobro y de recurrentes`.

---

### Task 2: Migración v3 y repositorios

**Files:**
- Modify: `lib/core/db/tables.dart`, `lib/core/db/app_database.dart` (`schemaVersion` 3), `lib/core/db/providers.dart`
- Create: `income_schedule_repository.dart`, `recurring_repository.dart`, `suggestions_repository.dart`, `budgets_repository.dart`
- Test: `test/core/db/migration_v3_test.dart`, un test por repositorio

**Interfaces:**
- Migración v3: índice **único** en `suggested_transactions(source, sourceRef, occurredAt)`. Test: base v2 con movimientos, libreta y palabras → tras migrar todo sigue igual.
- `IncomeScheduleRepository`: `Stream<IncomeSchedule?> watchCurrent()` (la de `effectiveFrom` más reciente ≤ hoy); `Future<void> setSchedule({required PayMode mode, required List<int> payDays, required bool shiftToPreviousBusinessDay, int? expectedAmount, required String categoryId})` (inserta fila nueva con `effectiveFrom` = hoy; nunca edita las viejas). `payDays` se guarda como JSON.
- `RecurringRepository`: `watchAll()`, `add(...)`, `update(...)`, `setActive(String id, bool active)`, `delete(String id)`; al crear calcula `nextDueDate` con `nextOccurrence` desde ayer (si hoy coincide, hoy es la primera).
- `SuggestionsRepository`:
  - `Stream<List<SuggestionView>> watchPending()` (con categoría; más viejas primero); `Stream<int> watchPendingCount()`.
  - `Future<bool> createIfAbsent({...})` — usa el índice único; devuelve `false` si ya existía.
  - `Future<String> confirm(String id, {int? amount, String? categoryId, DateTime? occurredAt})` — en **una transacción SQL**: crea el movimiento (`source` según la sugerencia, `suggestionId`), marca `confirmed`, guarda `transactionId`. Si ya estaba confirmada devuelve el `transactionId` existente sin crear otro.
  - `Future<void> dismiss(String id)`.
- `BudgetsRepository`: `watchAll()` (con categoría), `setLimit(String categoryId, int monthlyLimit)` (crea o actualiza), `remove(String categoryId)`, `markAlertSent(String budgetId, {required int threshold, required String yearMonth})`.

- [ ] **Step 1:** Tests que fallan (migración; esquema vigente al cambiar de modo; `createIfAbsent` doble → una fila; `confirm` doble → un movimiento; `dismiss` saca de pendientes). **Step 2:** FAIL. **Step 3:** Implementar + `build_runner`. **Step 4:** PASS.
- [ ] **Step 5:** Checkpoint. Mensaje sugerido: `feat: repositorios de presupuestos, recurrentes, cobro y sugerencias`.

---

### Task 3: Generador de sugerencias

**Files:**
- Create: `lib/features/recurring/domain/suggestion_generator.dart`
- Modify: `lib/app.dart` (correr al iniciar y en `AppLifecycleState.resumed`)
- Test: `test/features/recurring/suggestion_generator_test.dart`

**Interfaces:**
- `class SuggestionGenerator { SuggestionGenerator(AppDatabase db, Notifier notifier, {DateTime Function()? clock}); Future<int> run(); }` — devuelve cuántas sugerencias nuevas creó.
  - Recurrentes activas: por cada fecha de `dueOccurrences`, `createIfAbsent` (source `recurring`, `sourceRef` = id de la regla, monto/categoría de la regla) y avanza `nextDueDate` a `nextOccurrence` de la última.
  - Esquema de cobro vigente: por cada día de cobro desde el último generado (o desde `effectiveFrom`) hasta hoy, `createIfAbsent` (type `income`, source `incomeSchedule`, `sourceRef` = id del esquema, monto = `expectedAmount` o 0 → la bandeja pide el monto).
  - Si creó ≥ 1: una notificación "Tenés N movimientos por confirmar".

- [ ] **Step 1: Tests que fallan:** catch-up de 3 meses de una recurrente → 3 sugerencias y `nextDueDate` en el mes siguiente; `run()` dos veces el mismo día → la segunda devuelve 0; cobro quincenal desde 1/10 con hoy 16/10 → una sugerencia el 15/10; notificación con el número correcto (Notifier falso). **Step 2:** FAIL. **Step 3:** Implementar. **Step 4:** PASS.
- [ ] **Step 5:** Checkpoint. Mensaje sugerido: `feat: generación de sugerencias de recurrentes y cobros`.

---

### Task 4: Notificaciones y alertas de presupuesto

**Files:**
- Create: `lib/core/notifications/notifier.dart`, `lib/features/budgets/domain/budget_status.dart`
- Modify: `android/app/src/main/AndroidManifest.xml` (`POST_NOTIFICATIONS`), `lib/features/transactions/data/transactions_repository.dart` o un listener en la capa de lógica (evaluar tras guardar/editar un gasto)
- Test: `test/features/budgets/budget_status_test.dart`, `test/features/budgets/budget_alerts_test.dart`

**Interfaces:**
- `abstract class Notifier { Future<void> show(String title, String body, {String? payload}); Future<bool> ensurePermission(); }` + `LocalNotifier` (canal "Pockt", ícono monocromo de la app) + `FakeNotifier` para tests.
- `enum BudgetLevel { ok, warning, over }` y `BudgetStatus budgetStatus(int spent, int limit)` → `level` (≥ 80 % `warning`, ≥ 100 % `over`), `ratio` (double), `remaining` (int, puede ser negativo).
- `Future<void> evaluateBudgetAlerts(String categoryId, {required DateTime nowLocal})` — si el gasto del mes cruza 80 % o 100 % y `alert80SentFor`/`alert100SentFor` ≠ mes actual: notifica ("Comida: llegaste al 80 % de tu presupuesto", "Comida: te pasaste por Gs. 12.000") y marca el mes.
- El permiso de notificaciones se pide la primera vez que el usuario crea un presupuesto o un recurrente, no al abrir la app.

- [ ] **Step 1: Tests que fallan:** `budgetStatus(79,100)` ok, `(80,100)` warning, `(100,100)` over; alerta 80 % una sola vez en el mes aunque se borre y recargue el gasto; mes siguiente vuelve a avisar; cruzar de golpe al 100 % manda solo la de 100 %. **Step 2:** FAIL. **Step 3:** Implementar. **Step 4:** PASS.
- [ ] **Step 5:** Checkpoint. Mensaje sugerido: `feat: alertas de presupuesto al 80 y 100 por ciento`.

---

### Task 5: Pantalla de Presupuestos

**Files:**
- Create: `lib/features/budgets/ui/budgets_screen.dart`
- Modify: `lib/features/shell/ui/app_shell.dart` (reemplaza el "Próximamente")
- Test: `test/features/budgets/budgets_screen_test.dart`

Comportamiento (spec §5.5): un **anillo** por categoría con tope (progreso del mes, color de la categoría; cambia a advertencia en ≥ 80 % y a exceso en ≥ 100 %, con tokens nuevos `warning`/`danger` en `PocktColors`), monto gastado y restante. Tocar un anillo abre sus movimientos del mes y permite editar o quitar el tope. Botón para agregar tope a una categoría sin presupuesto. Estado vacío con invitación a crear el primero. Haptic distinto al cruzar 80 % y 100 % (spec §6.4) cuando ocurre con la pantalla abierta.

- [ ] **Step 1:** Tests que fallan (anillo con ratio correcto; color de advertencia en 85 %; editar tope actualiza el anillo; estado vacío). **Step 2–4.** **Step 5:** Checkpoint. Mensaje sugerido: `feat: pantalla de presupuestos`.

---

### Task 6: Bandeja de sugeridos y tarjeta en el Inicio

**Files:**
- Create: `lib/features/recurring/ui/inbox_screen.dart`
- Modify: `lib/features/home/ui/home_screen.dart`
- Test: `test/features/recurring/inbox_screen_test.dart`, `test/features/home/home_screen_test.dart`

Comportamiento (spec §5.7 y mockup `inicio-v1.html`): tarjeta de vidrio "N por confirmar · Netflix, ANDE" con punto luminoso, solo si N > 0; abre la bandeja. En la bandeja, cada sugerencia muestra ícono de categoría, nombre, fecha y monto; acciones **Confirmar** (un toque), **Editar** (abre el teclado de la carga precargado y confirma al guardar) y **Descartar** (deslizar). Una sugerencia con monto 0 (cobro sin monto esperado) obliga a editar. Al confirmar, la fila sale con animación y el total del Inicio cuenta animado.

- [ ] **Step 1:** Tests que fallan (tarjeta oculta con 0, visible con 2 y texto correcto; confirmar crea movimiento y la saca; monto 0 no deja confirmar directo). **Step 2–4.** **Step 5:** Checkpoint. Mensaje sugerido: `feat: bandeja de sugeridos`.

---

### Task 7: Ajustes: hub, esquema de cobro y recurrentes

**Files:**
- Create: `lib/features/settings/ui/settings_screen.dart`, `lib/features/income/ui/income_schedule_screen.dart`, `lib/features/recurring/ui/recurring_screen.dart`
- Modify: `lib/features/home/ui/home_screen.dart` (el engranaje abre el hub), `lib/features/settings/ui/category_keywords_screen.dart` (pasa a ser el detalle de una categoría: "Reconocer también como…")
- Test: un test de widget por pantalla

Comportamiento: el engranaje abre **Ajustes** (lista en vidrio): Categorías · Esquema de cobro · Recurrentes. (Apariencia, recordatorios, backup y bloqueo se suman en los planes 3–4.) Las palabras clave dejan de ser una sección propia: quedan dentro del detalle de cada categoría. Esquema de cobro: selector Quincenal/Mensual, días (por defecto 15 y último), corrimiento a día hábil, monto esperado opcional, y "Próximo cobro: viernes 13 de noviembre" en vivo. Recurrentes: lista con nombre, monto, frecuencia y próxima fecha; crear/editar/pausar/borrar.

- [ ] **Step 1:** Tests que fallan (el engranaje abre el hub; cambiar a mensual día 30 muestra el próximo cobro correcto; crear un recurrente lo lista con su próxima fecha). **Step 2–4.** **Step 5:** Checkpoint. Mensaje sugerido: `feat: ajustes con esquema de cobro y recurrentes`.

---

### Task 8: Línea de quincena en el Inicio

**Files:**
- Modify: `lib/features/home/ui/home_screen.dart`
- Create: `lib/features/income/domain/period_summary.dart`
- Test: `test/features/income/period_summary_test.dart`, `test/features/home/home_screen_test.dart`

**Interfaces:** `PeriodLine? periodLine({required DateTime todayLocal, required IncomeSchedule? schedule, required int monthIncome, required int monthExpense})` → `label` ("1ª quincena" / "2ª quincena" / "Este mes"), `remaining` (= ingresos − gastos del mes), `daysToNextPay`; `null` sin esquema (la línea no se muestra).

Texto (spec §5.2.4): "2ª quincena · quedan **Gs. 820.000** · cobrás en 6 días"; "cobrás hoy" si es día de cobro; restante negativo con el token `danger`.

- [ ] **Step 1:** Tests que fallan (esquema [15, -1] sin corrimiento: 14/10 → 1ª quincena, cobrás mañana; 16/10 → 2ª, 15 días al 31; con corrimiento: 16/10 → 14 días al viernes 30; sin esquema → null; restante negativo). **Step 2–4.** **Step 5:** Checkpoint. Mensaje sugerido: `feat: línea de quincena en el inicio`.

---

### Task 9: Verificación en el A54 y v0.2.0

- [ ] **Step 1** (orquestador): instalar release sobre la app real (`adb install -r`, nunca desinstalar) y verificar que la migración v3 conserva los datos.
- [ ] **Step 2:** Recorrido: crear esquema quincenal, un recurrente con fecha pasada (catch-up), confirmar y descartar en la bandeja, crear un presupuesto y cruzar el 80 % → llega la notificación una sola vez.
- [ ] **Step 3:** Medición con `-P pocktPerf=true` incluyendo abrir Presupuestos y la bandeja; reportar build/raster p90 y p99.
- [ ] **Step 4:** README: tabla de estado (plan 2 ✅). Tag `v0.2.0` (y `v0.1.0` en el commit de cierre del plan 1 si no existe).
