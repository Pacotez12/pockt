# Pockt — Plan 3: reportes, recordatorios, apariencia, widget y acceso rápido

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pockt v0.3.0: las cuatro vistas de Reportes, los recordatorios por intensidad (con trabajo en segundo plano que también genera las sugerencias sin abrir la app), el selector de apariencia en Ajustes, el widget de pantalla de inicio y el tile de ajustes rápidos.

**Architecture:** Igual que los planes 1 y 2. Agregados de reportes como consultas del repositorio + funciones puras; ajustes en la tabla clave-valor `settings` a través de un `SettingsRepository` con streams; la planificación de recordatorios es una función pura (qué notificaciones programar para los próximos 7 días) y un servicio que la aplica; `workmanager` corre una tarea periódica que regenera sugerencias y reprograma recordatorios. Widget y tile hablan con Flutter a través de rutas de inicio (`pockt://entry?category=<id>`).

**Tech Stack:** el de los planes 1 y 2 + `workmanager` 0.10.10, `home_widget` 0.10.0.

**Spec:** `docs/superpowers/specs/2026-10-08-nucleo-design.md` (§5.6 reportes, §5.8 recordatorios, §5.9 widget y tile, §5.10 ajustes, §6.1 apariencia). Planes anteriores: plan 1 y plan 2 (sus Global Constraints siguen vigentes).

## Global Constraints

- Todas las de los planes 1 y 2 (PYG `int`, UTC + zona del teléfono, UUID, sin emojis, solo tokens e íconos de `lib/core/design`, migraciones con test sobre base con datos, nunca `flutter drive` con el applicationId real, `t.runAsync` para streams en tests de widgets, implementador sin commits).
- Ajustes: claves en `settings` con valores en texto; nombres exactos: `appearance` (`system`|`light`|`dark`), `reminders.intensity` (`off`|`soft`|`normal`|`insistent`), `reminders.quietStart` (`HH:mm`, por defecto `23:00`), `reminders.quietEnd` (`HH:mm`, por defecto `09:00`).
- Recordatorios (spec §5.8): solo si ese día local no hay gastos y no hay `day_marks.noSpend`. Suave 21:00; Normal 13:00 y 21:00; Insistente cada 3 h desde las 12:00, máximo 4 por día. Ninguno dentro de las horas de silencio. Acciones: **Anotar** (abre la grilla de categorías) y **Hoy no gasté nada** (crea el `day_mark` y cancela los de ese día).
- Comparación con el mes anterior (spec §5.6.3): del día 1 al día de hoy en ambos meses; si el mes anterior es más corto, se recorta a su último día.
- Reportes: nada se guarda sumado; todo sale de consultas.
- Widget y tile: si la app está bloqueada (plan 4), la ruta abre primero el desbloqueo.

## Review Focus

1. **Mes con un solo movimiento o sin datos** en cada vista de reportes: sin división por cero, estados vacíos con texto y no gráficos rotos. → Task 2 y Task 3.
2. **Horas de silencio que cruzan la medianoche** (23:00–09:00): un recordatorio de las 21:00 sale; uno de las 00:00 no. → Task 4.
3. **Cargar un gasto a las 20:59 con intensidad Suave**: el recordatorio de las 21:00 de ese día no sale. → Task 5.
4. **Cambiar de apariencia** con la app abierta: los colores se funden (sin salto) y la elección sobrevive a reiniciar la app. → Task 1.
5. **Categoría archivada** en el widget: no aparece; si no hay 4 activas con uso, se completa con las primeras por `sortOrder`. → Task 6.

---

## Estructura de archivos

```
lib/core/settings/settings_repository.dart          (clave-valor con streams + providers tipados)
lib/features/settings/ui/appearance_screen.dart
lib/features/reports/data/reports_repository.dart   (agregados por mes, categoría y comercio)
lib/features/reports/domain/compare.dart            (comparación a la misma altura del mes)
lib/features/reports/ui/reports_screen.dart          (4 vistas deslizables)
lib/features/reports/ui/charts.dart                  (anillo, barras, línea de evolución: CustomPainter)
lib/features/reminders/domain/reminder_plan.dart    (función pura: qué programar)
lib/features/reminders/data/reminder_scheduler.dart  (aplica el plan con flutter_local_notifications)
lib/features/reminders/ui/reminders_screen.dart
lib/core/background/background_tasks.dart           (workmanager: sugerencias + recordatorios)
lib/features/widget/home_widget_bridge.dart
android/app/src/main/kotlin/.../PocktWidgetProvider.kt
android/app/src/main/kotlin/.../EntryTileService.kt
android/app/src/main/res/layout/pockt_widget.xml, xml/pockt_widget_info.xml
```

---

### Task 1: SettingsRepository y apariencia (Sistema / Claro / Oscuro)

**Files:** Create `lib/core/settings/settings_repository.dart`, `lib/features/settings/ui/appearance_screen.dart`; Modify `lib/app.dart`, `lib/features/settings/ui/settings_screen.dart`; Test `test/core/settings/settings_repository_test.dart`, `test/features/settings/appearance_screen_test.dart`.

**Interfaces:**
- `SettingsRepository(AppDatabase db)`: `Stream<String?> watch(String key)`, `Future<String?> get(String key)`, `Future<void> set(String key, String value)`.
- `final appearanceProvider = StreamProvider<ThemeMode>` (lee `appearance`; por defecto `ThemeMode.system`).
- `lib/app.dart`: `themeMode` sale de `appearanceProvider`; `themeAnimationDuration` 400 ms y `themeAnimationCurve` `Curves.easeInOut` (los colores se funden).

- [ ] **Step 1:** Tests que fallan: `set`/`get`/`watch` emiten el valor nuevo; sin valor → `ThemeMode.system`; con `dark` → `MaterialApp.themeMode == ThemeMode.dark`; la pantalla marca la opción activa y al tocar "Oscuro" se guarda `dark`.
- [ ] **Step 2–4:** FAIL → implementar (tres opciones en un `GlassCard`, ícono `uiIcon`, check animado) → PASS, analyze 0.
- [ ] **Step 5:** Checkpoint. `feat: selector de apariencia en ajustes`.

### Task 2: Datos de reportes

**Files:** Create `lib/features/reports/data/reports_repository.dart`, `lib/features/reports/domain/compare.dart`; Test `test/features/reports/reports_repository_test.dart`, `test/features/reports/compare_test.dart`.

**Interfaces:**
- `class MonthTotals { int year; int month; int expense; int income; int get saving => income - expense; }`
- `class MerchantTotal { String merchant; int total; int count; }`
- `ReportsRepository(AppDatabase db)`:
  - `Stream<List<CategoryTotal>> watchMonthByCategory(int year, int month)` (reusar `CategoryTotal` del plan 1)
  - `Stream<List<MonthTotals>> watchEvolution({required int months, required DateTime todayLocal})` — los últimos `months` meses incluido el actual, del más viejo al más nuevo, con ceros donde no hay datos.
  - `Stream<List<MerchantTotal>> watchByMerchant(int year, int month, {int limit = 10})` — agrupa por comercio normalizado (minúsculas, sin tildes) mostrando la escritura más usada; excluye movimientos sin comercio.
- `class Comparison { int current; int previous; double? changePct; }` — `changePct` `null` si `previous == 0`.
- `Comparison compareToPreviousMonth({required DateTime todayLocal, required Map<DateTime, int> dailyExpenseByLocalDay})` (función pura; recorte por mes más corto).

- [ ] **Step 1:** Tests que fallan: evolución de 6 meses con huecos en 0; por comercio agrupa "Superseis" y "superseis"; comparación el 31/03 contra febrero (28 días) compara 1–31/03 con 1–28/02; `previous == 0` → `changePct == null`; movimientos borrados excluidos.
- [ ] **Step 2–4.** **Step 5:** Checkpoint. `feat: datos de reportes`.

### Task 3: Pantalla de Reportes

**Files:** Create `lib/features/reports/ui/reports_screen.dart`, `lib/features/reports/ui/charts.dart`; Modify `lib/features/shell/ui/app_shell.dart` (reemplaza "Próximamente"); Test `test/features/reports/reports_screen_test.dart`.

Cuatro vistas deslizables (`PageView` con indicador): 1) **Mes por categoría** (anillo de segmentos con los colores de categoría + lista; tocar una categoría abre sus movimientos del mes); 2) **Evolución** (barras gasto/ingreso por mes y línea de ahorro, 6 meses; selector 6/12); 3) **Comparación** ("Este mes gastaste 12 % más que en septiembre a esta altura", por total y por categoría); 4) **Por comercio** (ranking con barras). Selector de mes compartido arriba. Gráficos con `CustomPainter`, sin librerías de charts; animan al entrar con `PocktSprings.soft` y respetan reduce motion. Estados vacíos con texto.

- [ ] **Step 1:** Tests que fallan: con datos muestra las 4 vistas al deslizar; mes vacío muestra el estado vacío en cada vista (sin excepciones); tocar una categoría abre la lista filtrada.
- [ ] **Step 2–4.** Skills: `emil-design-eng`, `apple-design`, `flutter-animating-apps`, `dataviz` (criterio de color y lectura de gráficos). **Step 5:** Checkpoint. `feat: pantalla de reportes`.

### Task 4: Plan de recordatorios (función pura)

**Files:** Create `lib/features/reminders/domain/reminder_plan.dart`; Test `test/features/reminders/reminder_plan_test.dart`.

**Interfaces:**
- `enum ReminderIntensity { off, soft, normal, insistent }`
- `class PlannedReminder { DateTime atLocal; int notificationId; String title; String body; }` — `notificationId` estable por fecha y hora (`yyyymmdd * 100 + índice`), para poder cancelar.
- `List<PlannedReminder> planReminders({required DateTime nowLocal, required ReminderIntensity intensity, required Set<DateTime> daysWithExpense, required Set<DateTime> noSpendDays, required ({int h, int m}) quietStart, required ({int h, int m}) quietEnd, int days = 7})` — solo horarios futuros.
- Textos: Suave "¿Gastaste algo hoy? Anotalo en 10 segundos."; Normal mediodía "¿Cómo va el día? Anotá lo que llevás gastado."; Insistente "ANOTÁ TUS GASTOS DE HOY."

- [ ] **Step 1:** Tests que fallan: cada intensidad genera los horarios de la spec; día con gasto o `noSpend` → nada ese día; silencio 23:00–09:00 cruzando medianoche; a las 21:30 con Suave no planifica hoy; Insistente máximo 4 por día; ids estables entre dos llamadas.
- [ ] **Step 2–4.** **Step 5:** Checkpoint. `feat: plan de recordatorios`.

### Task 5: Recordatorios en el teléfono, trabajo en segundo plano y pantalla

**Files:** Create `lib/features/reminders/data/reminder_scheduler.dart`, `lib/core/background/background_tasks.dart`, `lib/features/reminders/ui/reminders_screen.dart`; Modify `lib/core/notifications/notifier.dart` (programar/cancelar con `zonedSchedule` y acciones), `lib/main.dart`, `settings_screen.dart`, `transactions_repository.dart` (al guardar un gasto, cancelar los recordatorios de ese día), `AndroidManifest.xml` (permisos `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` según corresponda, `RECEIVE_BOOT_COMPLETED`); Test `test/features/reminders/reminder_scheduler_test.dart`, `test/features/reminders/reminders_screen_test.dart`.

**Interfaces:**
- `Notifier` agrega: `Future<void> schedule(PlannedReminder r)`, `Future<void> cancel(int id)`, `Future<void> cancelAllReminders()`.
- `ReminderScheduler(Notifier n, TransactionsRepository tx, DayMarksRepository marks, SettingsRepository s)`: `Future<void> reschedule({required DateTime nowLocal})` (cancela y vuelve a programar según `planReminders`).
- `DayMarksRepository(AppDatabase db)`: `Future<void> markNoSpend(DateTime localDay)`, `Future<Set<DateTime>> noSpendDays(DateTime fromLocal, DateTime toLocal)`.
- `background_tasks.dart`: `void callbackDispatcher()` (top-level, `@pragma('vm:entry-point')`) que abre la base, corre el generador de sugerencias del plan 2 y `reschedule`; registrado con `Workmanager().registerPeriodicTask('pockt-daily', ..., frequency: 12 h)`.
- Acción "Hoy no gasté nada": crea el `day_mark` y llama `reschedule`. Acción "Anotar": abre `showEntryFlow`.
- Pantalla: intensidad (4 opciones con el ejemplo de texto de cada una), horas de silencio, estado del permiso de notificaciones con botón para activarlo si está denegado (spec §8).

- [ ] **Step 1:** Tests que fallan (con `FakeNotifier`): `reschedule` con Normal programa 13:00 y 21:00 de hoy; guardar un gasto cancela los de hoy; "Hoy no gasté nada" cancela los de hoy y crea el mark; cambiar intensidad reprograma.
- [ ] **Step 2–4.** **Step 5:** Checkpoint. `feat: recordatorios por intensidad y tarea en segundo plano`.

### Task 6: Widget de pantalla de inicio

**Files:** Create `lib/features/widget/home_widget_bridge.dart`, `PocktWidgetProvider.kt`, `res/layout/pockt_widget.xml`, `res/xml/pockt_widget_info.xml`, `res/drawable/` fondos; Modify `AndroidManifest.xml`, `lib/main.dart` (manejar `pockt://entry?category=<id>`); Test `test/features/widget/home_widget_bridge_test.dart`.

**Interfaces:**
- `Future<List<Category>> topCategories(AppDatabase db, {int n = 4, required DateTime nowLocal})` — por cantidad de gastos de los últimos 60 días, sin archivadas; completa con `sortOrder`.
- `HomeWidgetBridge.update()` — guarda en `home_widget` nombre, clave de ícono y color de las 4 categorías y pide redibujar; se llama al guardar un movimiento y en la tarea de segundo plano.
- Widget 4×1: fondo negro con borde de vidrio, 4 burbujas con el color de la categoría (ícono Phosphor exportado como vector drawable para las claves del set curado) y un ＋. Tocar una burbuja abre `pockt://entry?category=<id>` → `showEntryFlow(initialCategoryId:)`.

- [ ] **Step 1:** Tests que fallan: `topCategories` ordena por uso, excluye archivadas, completa hasta 4.
- [ ] **Step 2–4.** **Step 5** (orquestador): agregar el widget en el A54 y verificar que abre la carga en la categoría tocada. **Step 6:** Checkpoint. `feat: widget de pantalla de inicio`.

### Task 7: Tile de ajustes rápidos

**Files:** Create `EntryTileService.kt`; Modify `AndroidManifest.xml` (servicio con `BIND_QUICK_SETTINGS_TILE`, ícono monocromo del orbe).

- `EntryTileService.onClick()` abre `pockt://entry` (grilla de categorías) con `startActivityAndCollapse` (con `PendingIntent` en API 34+).

- [ ] **Step 1:** Implementar y compilar. **Step 2** (orquestador): agregar el tile en el panel del A54 y verificar que abre la grilla. **Step 3:** Checkpoint. `feat: tile de ajustes rápidos`.

### Task 7b: Logotipo "Pockt" y animación de apertura

Pedido del autor. **Antes de empezar, el orquestador usa la skill `find-skills`** para buscar skills de diseño de logotipos/wordmarks y de animaciones de apertura, y nombra en el prompt las que sirvan.

- **Logotipo (wordmark):** "Pockt" como marca tipográfica propia (no solo Inter en negrita): ajuste de espaciado, una o dos letras con un detalle del orbe o de la curva de la abertura. Entregables: `docs/brand/pockt-wordmark.svg` (claro y oscuro), versión horizontal orbe + palabra (`pockt-lockup.svg`), y su uso en splash, primer uso y README.
- **Apertura:** el splash del sistema (Android 12+: `AnimatedVectorDrawable`, ≤ 1 s) muestra el orbe; Flutter continúa sin corte: el resplandor se abre, aparece el logotipo, y el orbe se funde con el resplandor del Inicio. Total ≤ 900 ms, solo en arranque en frío, se saltea al tocar, y con "reducir animaciones" pasa a un fundido simple. Mientras tanto se abre la base y se generan las sugerencias (la animación tapa la carga real, no la alarga).
- Tests: con `disableAnimations` no hay animación; el Inicio queda visible después de la apertura; tocar la saltea.
- Checkpoint. `feat: logotipo y animación de apertura`.

### Task 8: Verificación en el A54 y v0.3.0

- [ ] **Step 1** (orquestador): instalar release sobre la app real (`adb install -r`, nunca desinstalar); datos intactos.
- [ ] **Step 2:** Recorrido: cambiar apariencia; recorrer los 4 reportes con datos reales; Insistente con la hora del teléfono → llega el recordatorio, "Hoy no gasté nada" lo cancela; widget y tile.
- [ ] **Step 3:** Medición con `-P pocktPerf=true` incluyendo deslizar los reportes; reportar build/raster p90 y p99.
- [ ] **Step 4:** README (estado: plan 3 ✅, funciones nuevas). Tag `v0.3.0`.
