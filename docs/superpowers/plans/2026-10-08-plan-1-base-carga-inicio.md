# Pockt — Plan 1: base, carga e inicio

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Una app Pockt instalable en el A54 donde se cargan gastos e ingresos (categoría primero, teclado, texto natural), se ven en el Inicio con el resplandor, el calendario de calor y el detalle del día, y se listan, editan y borran con deshacer en Movimientos.

**Architecture:** Flutter, estructura por funcionalidad (`lib/core`, `lib/features/<feature>`). Drift (SQLite) como única fuente de verdad; repositorios exponen `Stream`s reactivos; Riverpod los conecta con la UI. Todos los colores, tipografía, springs y haptics salen de `lib/core/design/`.

**Tech Stack:** Flutter 3.47.x estable (Dart 3.13) en `~/Proyectos/flutter`; `drift` 2.35.2, `drift_flutter` 0.3.1, `drift_dev` 2.35.1, `build_runner` 2.16.2, `flutter_riverpod` 3.4.3, `riverpod_annotation` 4.0.7, `riverpod_generator` 4.0.9, `intl` 0.20.3, `uuid` 4.6.0, `timezone` 0.11.1, `mocktail` 1.0.5 (dev).

**Spec:** `docs/superpowers/specs/2026-10-08-nucleo-design.md` (leerla junto con este plan).

**Planes siguientes (fuera de este plan):** 2) presupuestos, recurrentes, esquema de cobro, bandeja de sugeridos y línea de quincena del Inicio; 3) reportes, recordatorios, widget y tile; 4) backup, restauración, bloqueo, primer uso, selector de apariencia y pulido del modo claro.

## Global Constraints

- App: nombre visible **Pockt**; paquete Dart `pockt`; applicationId `io.github.pacotez12.pockt`. Solo Android. `minSdk` 26.
- Repo **público**: nunca commitear keystores, `key.properties`, archivos de cliente OAuth ni datos personales. Sin archivo de licencia (decisión del autor).
- Montos: `int` en guaraníes, sin decimales. `currency` siempre `'PYG'` en v1.
- Formato de montos: punto como separador de miles (`4.212.000`), prefijo `Gs.`.
- Fechas: se guardan en UTC; se muestran y agrupan por día en la zona horaria del teléfono (`initLocalZone()` con `flutter_timezone`; respaldo `kFallbackZone = 'America/Asuncion'`), vía paquete `timezone`, nunca un offset fijo.
- IDs: UUID v4 en texto para todas las tablas salvo `settings` y `day_marks`.
- Borrado de movimientos: suave (`deletedAt`), con "Deshacer".
- Tipografía: Inter incluida como asset (no descargada en runtime), cifras tabulares (`FontFeature.tabularFigures()`).
- Oscuro: fondo `#000000`. Vidrio: blanco 7 % de opacidad, borde blanco 9 %. Texto en opacidades 100/60/45 %.
- Springs: `firm` = sin rebote (respuestas al toque); `soft` = rebote mínimo (hojas y transiciones). Presión de botones: escala 0,96.
- Haptics: leve por tecla, medio al guardar, tic al cambiar de mes.
- `MediaQuery.disableAnimations == true` ⇒ transiciones pasan a fundidos simples.
- Meta de rendimiento: ningún frame > 8 ms (build + raster, percentil 99) durante carga, detalle del día y cambio de mes, medido con `integration_test` + `IntegrationTestWidgetsFlutterBinding.traceAction` en modo profile en el A54. `dumpsys gfxinfo` NO sirve: no ve los frames de Flutter.
- Ningún error de escritura falla en silencio: se muestra en la UI.
- Mensajes de commit: prefijo `feat:`/`fix:`/`chore:`/`test:`, en español, **sin ninguna atribución a IA**. Los commits los hace el autor tras revisar: el implementador deja los cambios sin commitear al final de cada tarea y sugiere el mensaje.

## Review Focus

1. **Gasto cerca de medianoche:** un gasto a las 23:30 hora de Paraguay cae al día siguiente en UTC; debe contarse en el día local correcto (calendario, detalle del día, total del mes si es el último día). → test en Task 4.
2. **Mes sin gastos (o mes nuevo):** total `Gs. 0`, calendario todo en nivel 0, resplandor con el color de marca; nada debe romper con listas vacías. → tests en Task 5 y Task 8.
3. **Montos absurdos en el teclado:** muchos dígitos o `000` repetido; tope de 12 dígitos (999.999.999.999), y "Guardar" deshabilitado con monto 0. → test en Task 6.
4. **Categoría archivada con movimientos:** no aparece en la grilla de carga, pero sus movimientos siguen mostrando nombre, ícono y color en Inicio y Movimientos. → test en Task 4.
5. **Deshacer después de navegar:** borrar, cambiar de pestaña antes de que expire el aviso y volver; el movimiento debe seguir restaurable mientras el aviso viva, y no duplicarse al restaurar dos veces. → test en Task 4 (repositorio) y Task 9 (UI).

---

## Estructura de archivos

```
pubspec.yaml
analysis_options.yaml
assets/fonts/Inter-*.ttf                     (Regular, Medium, SemiBold, Bold + OFL.txt)
assets/brand/                                (PNGs generados del ícono)
android/app/build.gradle(.kts)               (applicationId, minSdk)
lib/main.dart                                (bootstrap: timezone, ProviderScope)
lib/app.dart                                 (MaterialApp, themes, shell)
lib/core/format/money.dart                   (formatGs, keypad input)
lib/core/time/local_time.dart                (zona del teléfono con respaldo Asunción, rangos de mes/día)
lib/core/design/tokens.dart                  (PocktColors ThemeExtension claro/oscuro)
lib/core/design/theme.dart                   (ThemeData claro y oscuro, tipografía)
lib/core/design/motion.dart                  (springs, Pressable, reduce-motion)
lib/core/design/haptics.dart                 (Haptics)
lib/core/design/glass.dart                   (GlassCard, GlassBar)
lib/core/db/tables.dart                      (todas las tablas del modelo)
lib/core/db/app_database.dart                (AppDatabase, migración v1, seed)
lib/core/db/providers.dart                   (databaseProvider, repositorios)
lib/features/transactions/data/transactions_repository.dart
lib/features/transactions/data/categories_repository.dart
lib/features/transactions/ui/transactions_screen.dart
lib/features/home/domain/heat_levels.dart
lib/features/home/ui/home_screen.dart
lib/features/home/ui/month_glow.dart
lib/features/home/ui/heat_calendar.dart
lib/features/home/ui/day_detail_sheet.dart
lib/features/entry/domain/natural_parser.dart
lib/features/entry/ui/entry_flow.dart        (grilla → teclado, ingreso/gasto, edición)
lib/features/entry/ui/amount_keypad.dart
lib/features/shell/ui/app_shell.dart         (barra flotante de vidrio + pestañas)
test/...                                     (espejo de lib/)
```

---

### Task 1: Proyecto Flutter, dependencias y arranque en el A54

**Files:**
- Create: proyecto con `flutter create`, `pubspec.yaml`, `analysis_options.yaml`, `assets/fonts/`, `lib/main.dart`, `lib/app.dart`
- Modify: `android/app/build.gradle.kts` (applicationId, minSdk 26, label "Pockt"), `.gitignore`
- Test: `test/app_smoke_test.dart`

**Interfaces:**
- Produces: `PocktApp` (widget raíz en `lib/app.dart`); `bootstrap()` en `lib/main.dart` que inicializa `timezone` antes de `runApp`.

- [ ] **Step 1:** Usar el SDK `~/Proyectos/flutter/bin/flutter` (3.47.0 estable) **tal cual, sin `flutter upgrade`**: es un SDK compartido con otros proyectos. Usar ese binario en todo el plan.
- [ ] **Step 2:** En `~/Proyectos/pockt`: `flutter create --org io.github.pacotez12 --project-name pockt --platforms android .` (sin borrar `docs/`).
- [ ] **Step 3:** Agregar las dependencias del Tech Stack con esas versiones exactas; `flutter_lints` según el template. Descargar Inter (Regular 400, Medium 500, SemiBold 600, Bold 700) desde el release oficial `rsms/inter`, copiar a `assets/fonts/` con su `OFL.txt` y declararla en `pubspec.yaml` como familia `Inter`.
- [ ] **Step 4:** Agregar al `.gitignore`: `*.jks`, `*.keystore`, `android/key.properties`, `**/client_secret*.json`, `**/google-services.json`.
- [ ] **Step 5: Test que falla** — `test/app_smoke_test.dart`:

```dart
testWidgets('PocktApp arranca y muestra el shell', (tester) async {
  await tester.pumpWidget(const ProviderScope(child: PocktApp()));
  await tester.pumpAndSettle();
  expect(find.byType(MaterialApp), findsOneWidget);
  expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, 'Pockt');
});
```

- [ ] **Step 6:** `flutter test test/app_smoke_test.dart` → FAIL (no existe `PocktApp`).
- [ ] **Step 7:** Implementar `PocktApp` (título `'Pockt'`, `themeMode: ThemeMode.system`, home provisorio con fondo negro) y `bootstrap()` (`initializeTimeZones()` + `ProviderScope`).
- [ ] **Step 8:** `flutter test` → PASS. `flutter analyze` → sin issues.
- [ ] **Step 9:** Con el A54 conectado (`adb devices` muestra el serial como `device`): `flutter run -d R5CW31LZ4WK` → la app abre con el nombre "Pockt" en el launcher.
- [ ] **Step 10:** Checkpoint para revisión. Mensaje sugerido: `chore: proyecto Flutter inicial de Pockt`.

---

### Task 2: Formato de guaraníes y entrada del teclado

**Files:**
- Create: `lib/core/format/money.dart`
- Test: `test/core/format/money_test.dart`

**Interfaces:**
- Produces:
  - `String formatGs(int amount, {bool symbol = true})` → `'Gs. 4.212.000'` / `'4.212.000'`; negativos con `−` delante del símbolo.
  - `const int kMaxAmountDigits = 12;`
  - `String keypadAppend(String digits, String key)` — `key` ∈ `'0'..'9'`, `'000'`, `'⌫'`; ignora ceros a la izquierda y no supera `kMaxAmountDigits`.
  - `int keypadValue(String digits)` → `0` si vacío.

- [ ] **Step 1: Tests que fallan:**

```dart
test('formatGs con separador de miles y símbolo', () {
  expect(formatGs(4212000), 'Gs. 4.212.000');
  expect(formatGs(15000, symbol: false), '15.000');
  expect(formatGs(0), 'Gs. 0');
  expect(formatGs(-28500), '−Gs. 28.500');
});
test('keypadAppend respeta ceros a la izquierda, 000 y tope de 12 dígitos', () {
  expect(keypadAppend('', '0'), '');
  expect(keypadAppend('', '000'), '');
  expect(keypadAppend('15', '000'), '15000');
  expect(keypadAppend('15000', '⌫'), '1500');
  expect(keypadAppend('', '⌫'), '');
  expect(keypadAppend('99999999999', '000'), '999999999990');
  expect(keypadAppend('999999999999', '1'), '999999999999');
});
test('keypadValue', () {
  expect(keypadValue(''), 0);
  expect(keypadValue('28500'), 28500);
});
```

Nota: `'000'` agrega solo los ceros que entran hasta el tope (de ahí `'999999999990'`).

- [ ] **Step 2:** `flutter test test/core/format/money_test.dart` → FAIL.
- [ ] **Step 3:** Implementar con `NumberFormat('#,##0', 'es_PY')` o reemplazo manual de separador; el resultado debe usar `.` como separador en cualquier locale del teléfono.
- [ ] **Step 4:** Tests → PASS.
- [ ] **Step 5:** Checkpoint. Mensaje sugerido: `feat: formato de guaraníes y lógica del teclado`.

---

### Task 3: Sistema visual base (tokens, tema, motion, haptics, vidrio)

**Files:**
- Create: `lib/core/design/tokens.dart`, `theme.dart`, `motion.dart`, `haptics.dart`, `glass.dart`
- Modify: `lib/app.dart` (usar `buildDarkTheme()`/`buildLightTheme()`)
- Test: `test/core/design/tokens_test.dart`, `test/core/design/motion_test.dart`

**Interfaces:**
- Produces:
  - `class PocktColors extends ThemeExtension<PocktColors>` con: `background`, `glassFill`, `glassBorder`, `textPrimary`, `textSecondary`, `textTertiary`, `brandStart` (`#FF8A3D`), `brandEnd` (`#FF3D7F`), `heat` (`List<Color>` de 5 niveles), y `lerp` real. Constantes `PocktColors.dark` y `PocktColors.light`.
  - `extension PocktTheme on BuildContext { PocktColors get pockt; }`
  - `ThemeData buildDarkTheme()`, `ThemeData buildLightTheme()` — familia `Inter`, `fontFeatures: [FontFeature.tabularFigures()]` en todos los estilos de texto, `scaffoldBackgroundColor` = `PocktColors.*.background`.
  - `abstract final class PocktSprings { static final SpringDescription firm; static final SpringDescription soft; }` — `firm` con amortiguación crítica (sin rebote); `soft` con `dampingRatio` 0,85.
  - `class Pressable extends StatefulWidget` (`child`, `onTap`) — escala 0,96 al presionar con `firm`; sin escala si `MediaQuery.disableAnimationsOf(context)`.
  - `abstract final class Haptics { static Future<void> key(); static Future<void> save(); static Future<void> tick(); }` → `HapticFeedback.lightImpact` / `mediumImpact` / `selectionClick`.
  - `class GlassCard extends StatelessWidget` (vidrio sin desenfoque: relleno + borde), `class GlassBar extends StatelessWidget` (con `BackdropFilter`, sigma 24; único uso de desenfoque junto con las hojas).

- [ ] **Step 1: Tests que fallan:**

```dart
test('oscuro usa negro puro y vidrio 7%/9%', () {
  expect(PocktColors.dark.background, const Color(0xFF000000));
  expect(PocktColors.dark.glassFill, Colors.white.withValues(alpha: 0.07));
  expect(PocktColors.dark.glassBorder, Colors.white.withValues(alpha: 0.09));
  expect(PocktColors.dark.heat, hasLength(5));
  expect(PocktColors.light.heat, hasLength(5));
});
test('lerp interpola entre claro y oscuro', () {
  final mid = PocktColors.dark.lerp(PocktColors.light, 0.5);
  expect(mid.background, isNot(PocktColors.dark.background));
});
testWidgets('Pressable no escala con reduce motion', (tester) async {
  await tester.pumpWidget(MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: MaterialApp(home: Pressable(onTap: () {}, child: const SizedBox(width: 50, height: 50))),
  ));
  await tester.press(find.byType(Pressable));
  await tester.pump(const Duration(milliseconds: 50));
  final scale = tester.widget<Transform>(find.descendant(of: find.byType(Pressable), matching: find.byType(Transform))).transform.getMaxScaleOnAxis();
  expect(scale, 1.0);
});
```

- [ ] **Step 2:** Tests → FAIL.
- [ ] **Step 3:** Implementar. Valores del modo claro: fondo `#F7F7F8`, vidrio blanco 70 % con sombra suave (`blurRadius` 24, negro 6 %), textos negro 100/60/45 %. Escala `heat` oscuro: `#FFFFFF0D`, `#FF7A4538`, `#FF7A4573`, `#FF645FB8`, degradado de marca (usar `brandEnd` como valor del último). Claro: `#0000000D`, `#FFB08A`, `#FF8A5C`, `#F2603F`, `#E8306F`.
- [ ] **Step 4:** Tests → PASS; `flutter analyze` limpio.
- [ ] **Step 5:** Checkpoint. Mensaje sugerido: `feat: sistema visual base (tokens, tema, motion, haptics)`.

---

### Task 4: Base de datos, categorías y repositorio de movimientos

**Files:**
- Create: `lib/core/time/local_time.dart`, `lib/core/db/tables.dart`, `lib/core/db/app_database.dart`, `lib/core/db/providers.dart`, `lib/features/transactions/data/categories_repository.dart`, `lib/features/transactions/data/transactions_repository.dart`
- Test: `test/core/time/local_time_test.dart`, `test/core/db/seed_test.dart`, `test/features/transactions/transactions_repository_test.dart`

**Interfaces:**
- Produces:
  - `local_time.dart`: `const kFallbackZone = 'America/Asuncion'`; `Future<void> initLocalZone()`; `void setLocalZone(String name)` (tests); `DateTime toLocal(DateTime utc)`; `({DateTime startUtc, DateTime endUtc}) monthRangeUtc(int year, int month)` (fin exclusivo); `({DateTime startUtc, DateTime endUtc}) dayRangeUtc(DateTime localDay)`.
  - `tables.dart`: **todas** las tablas de la spec §4 (`Categories`, `Transactions`, `SuggestedTransactions`, `RecurringRules`, `IncomeSchedules`, `Budgets`, `DayMarks`, `Settings`), con los campos y nombres exactos de la spec. Enums Dart: `TxType { expense, income }`, `CategoryKind { expense, income }`, `TxSource { manual, recurring, incomeSchedule, capture }`.
  - `AppDatabase` (`schemaVersion => 1`), `AppDatabase.forTesting(QueryExecutor e)`; `onCreate` inserta las categorías iniciales de la spec §4 (10 de gasto, 3 de ingreso) con `icon` emoji, `colorDark`, `colorLight` y `sortOrder`.
  - `CategoriesRepository(AppDatabase db)`: `Stream<List<Category>> watchActive(CategoryKind kind)` (sin archivadas, por `sortOrder`); `Future<void> archive(String id)`.
  - `class TxView { Transaction tx; Category category; }`
  - `class CategoryTotal { Category category; int total; }`
  - `TransactionsRepository(AppDatabase db, {DateTime Function()? clock})`:
    - `Future<String> add({required TxType type, required int amount, required String categoryId, required DateTime occurredAt, String? merchant, String? note})` → id; lanza `ArgumentError` si `amount <= 0`.
    - `Future<void> update(String id, {int? amount, String? categoryId, DateTime? occurredAt, String? merchant, String? note})`
    - `Future<void> softDelete(String id)`; `Future<void> restore(String id)` (idempotente).
    - `Stream<int> watchMonthTotal(int year, int month, TxType type)`
    - `Stream<List<CategoryTotal>> watchMonthCategoryTotals(int year, int month)` (gastos, mayor a menor)
    - `Stream<Map<int, int>> watchDailyExpenseTotals(int year, int month)` (día local → total; solo días con gasto)
    - `Stream<List<TxView>> watchRecent({int limit = 20})`
    - `Stream<List<TxView>> watchDay(DateTime localDay)`
    - `Stream<List<TxView>> watchFiltered({String? query, Set<String>? categoryIds, TxType? type, DateTime? fromLocal, DateTime? toLocal})`
    - Todas las consultas excluyen `deletedAt != null`.

- [ ] **Step 1: Tests que fallan** (DB en memoria con `NativeDatabase.memory()`):

```dart
test('seed: 10 categorías de gasto y 3 de ingreso', () async {
  expect(await repo.watchActive(CategoryKind.expense).first, hasLength(10));
  expect(await repo.watchActive(CategoryKind.income).first, hasLength(3));
});
test('gasto a las 23:30 en Asunción cuenta en su día local', () async {
  final local = tz.TZDateTime(tz.getLocation(kZone), 2026, 10, 31, 23, 30);
  await txRepo.add(type: TxType.expense, amount: 15000, categoryId: comida, occurredAt: local.toUtc());
  expect(await txRepo.watchDailyExpenseTotals(2026, 10).first, {31: 15000});
  expect(await txRepo.watchMonthTotal(2026, 10, TxType.expense).first, 15000);
  expect(await txRepo.watchMonthTotal(2026, 11, TxType.expense).first, 0);
});
test('mes vacío devuelve 0 y mapas vacíos', () async {
  expect(await txRepo.watchMonthTotal(2026, 2, TxType.expense).first, 0);
  expect(await txRepo.watchDailyExpenseTotals(2026, 2).first, isEmpty);
  expect(await txRepo.watchMonthCategoryTotals(2026, 2).first, isEmpty);
});
test('categoría archivada: fuera de la grilla, visible en sus movimientos', () async {
  final id = await txRepo.add(type: TxType.expense, amount: 5000, categoryId: ocio, occurredAt: now);
  await catRepo.archive(ocio);
  expect((await catRepo.watchActive(CategoryKind.expense).first).map((c) => c.id), isNot(contains(ocio)));
  expect((await txRepo.watchRecent().first).single.category.id, ocio);
});
test('softDelete oculta, restore devuelve, restore doble no duplica', () async {
  final id = await txRepo.add(type: TxType.expense, amount: 28500, categoryId: transporte, occurredAt: now);
  await txRepo.softDelete(id);
  expect(await txRepo.watchRecent().first, isEmpty);
  await txRepo.restore(id);
  await txRepo.restore(id);
  expect(await txRepo.watchRecent().first, hasLength(1));
});
test('monto 0 o negativo se rechaza', () {
  expect(() => txRepo.add(type: TxType.expense, amount: 0, categoryId: comida, occurredAt: now), throwsArgumentError);
});
test('watchFiltered busca en nota y comercio sin distinguir mayúsculas', () async { /* "Superseis" encontrado con query "super" */ });
```

- [ ] **Step 2:** `dart run build_runner build --delete-conflicting-outputs`; tests → FAIL.
- [ ] **Step 3:** Implementar. Los totales diarios se agrupan por día **local**: traer `occurredAt` del rango UTC del mes y agrupar en Dart con `toLocal` (volumen personal, no hace falta SQL de zonas horarias).
- [ ] **Step 4:** Generar código y correr tests → PASS.
- [ ] **Step 5:** Checkpoint. Mensaje sugerido: `feat: base de datos Drift, categorías y repositorio de movimientos`.

---

### Task 5: Niveles del calendario de calor

**Files:**
- Create: `lib/features/home/domain/heat_levels.dart`
- Test: `test/features/home/heat_levels_test.dart`

**Interfaces:**
- Produces: `Map<int, int> heatLevels(Map<int, int> dailyTotals)` — día → nivel 0..4. Días ausentes o con 0 = nivel 0 (el llamador asume 0 para días sin entrada). Días con gasto se reparten en 1..4 por cuartiles de ese mes.

- [ ] **Step 1: Tests que fallan:**

```dart
test('vacío', () => expect(heatLevels({}), isEmpty));
test('un solo día con gasto es nivel 4', () => expect(heatLevels({17: 612000}), {17: 4}));
test('cuartiles: el mayor es 4, el menor es 1', () {
  final l = heatLevels({1: 10000, 2: 20000, 3: 30000, 4: 40000, 5: 50000, 6: 60000, 7: 70000, 8: 80000});
  expect(l[1], 1); expect(l[2], 1); expect(l[7], 4); expect(l[8], 4);
  expect(l.values.toSet(), {1, 2, 3, 4});
});
test('todos iguales caen en nivel 4', () => expect(heatLevels({1: 5000, 2: 5000}), {1: 4, 2: 4}));
test('montos en 0 quedan en nivel 0', () => expect(heatLevels({3: 0}), {3: 0}));
```

- [ ] **Step 2:** FAIL. **Step 3:** Implementar: ordenar montos > 0; nivel = `1 + floor(4 * rank / n)` acotado a 1..4, donde `rank` es la posición del menor índice con ese monto (empates comparten nivel; si todos son iguales → 4). **Step 4:** PASS.
- [ ] **Step 5:** Checkpoint. Mensaje sugerido: `feat: niveles del calendario de calor`.

---

### Task 6: Flujo de carga (categoría primero → teclado), con edición

**Files:**
- Create: `lib/features/entry/ui/entry_flow.dart`, `lib/features/entry/ui/amount_keypad.dart`
- Test: `test/features/entry/entry_flow_test.dart`

**Interfaces:**
- Consumes: `keypadAppend`, `keypadValue`, `formatGs` (Task 2); `CategoriesRepository.watchActive`, `TransactionsRepository.add/update` (Task 4); `Pressable`, `Haptics`, `PocktSprings`, `PocktColors` (Task 3).
- Produces: `Future<void> showEntryFlow(BuildContext context, {TxType initialType = TxType.expense, String? initialCategoryId, TxView? editing})` — abre la carga como ruta modal. Con `initialCategoryId` abre directo en el teclado (lo usará el widget del plan 3). Con `editing` precarga todo y guarda con `update`.

Comportamiento (spec §5.3):
- Interruptor Gasto/Ingreso arriba; la grilla muestra `watchActive` del tipo elegido.
- Tocar una burbuja → transición compartida (`Hero` con tag `'cat-<id>'` + `PocktSprings.soft`) al teclado teñido con el color de la categoría.
- Teclado: `1-9`, `000`, `0`, `⌫`; `Haptics.key()` por tecla; monto grande con `formatGs`.
- Fecha (por defecto hoy, selector a un toque), nota y comercio opcionales.
- "Guardar" deshabilitado con monto 0. Al guardar: `Haptics.save()` y cierre. Si `add`/`update` lanza: la ruta no se cierra, se muestra el error en un aviso, el monto queda cargado.

- [ ] **Step 1: Tests que fallan** (repositorio real sobre DB en memoria vía override de `databaseProvider`):

```dart
testWidgets('categoría → monto → guardar crea el gasto', (t) async {
  await openEntry(t);
  await t.tap(find.text('Comida')); await t.pumpAndSettle();
  for (final k in ['1', '5', '000']) { await t.tap(find.text(k)); await t.pump(); }
  expect(find.text('Gs. 15.000'), findsOneWidget);
  await t.tap(find.text('Guardar')); await t.pumpAndSettle();
  final recent = await txRepo.watchRecent().first;
  expect(recent.single.tx.amount, 15000);
  expect(recent.single.category.name, 'Comida');
});
testWidgets('Guardar deshabilitado con monto 0', (t) async { /* tras elegir categoría, onPressed == null */ });
testWidgets('error al guardar mantiene la pantalla y el monto', (t) async {
  /* repo falso cuyo add lanza: se ve el aviso de error, 'Gs. 15.000' sigue visible */
});
testWidgets('el interruptor Ingreso muestra categorías de ingreso', (t) async { /* aparece 'Sueldo', no 'Comida' */ });
testWidgets('edición precarga y actualiza', (t) async { /* editing: amount 28500 → cambia a 30000 → update */ });
```

- [ ] **Step 2:** FAIL. **Step 3:** Implementar. **Step 4:** PASS; `flutter analyze` limpio.
- [ ] **Step 5:** Verificación en el A54 (lo hace el orquestador): cargar 3 gastos reales en release; la transición burbuja→teclado no muestra saltos. La medición de frames se automatiza en la Task 10.
- [ ] **Step 6:** Checkpoint. Mensaje sugerido: `feat: flujo de carga con categoría primero y teclado`.

---

### Task 6b: Íconos Phosphor en lugar de emojis

**Files:**
- Create: `lib/core/design/icons.dart`
- Modify: `pubspec.yaml` (`phosphor_flutter: 2.1.0`), `lib/core/db/app_database.dart` (seed), `lib/features/entry/ui/*` (reemplazar emojis)
- Test: `test/core/design/icons_test.dart`, `test/core/db/seed_test.dart`

**Interfaces:**
- Produces:
  - `Widget categoryIcon(String key, {double size = 24, Color? color})` — Phosphor **duotone**; clave desconocida → ícono `package`.
  - `IconData uiIcon(String key, {bool filled = false})` — Phosphor **regular** o **fill**.
  - `const List<String> kCategoryIconKeys` — set curado para elegir al crear categorías (≥ 40 claves).
- Seed (`icon`): Comida `fork-knife`, Transporte `car-profile`, Hogar `house-line`, Salud `heartbeat`, Ocio `popcorn`, Servicios `lightning`, Educación `graduation-cap`, Regalos `gift`, Ropa `t-shirt`, Otros `package`, Sueldo `briefcase`, Extra `sparkle`, Otros ingresos `arrow-circle-down`. La base no está instalada en ningún dispositivo todavía: se modifica el seed de la v1 sin migración.

- [ ] **Step 1: Tests que fallan:** todas las claves del seed y de `kCategoryIconKeys` resuelven a un ícono real (no al de respaldo); una clave inexistente devuelve `package`; ningún `name`/`icon` del seed contiene emojis (regex de rango Unicode de emoji).
- [ ] **Step 2:** FAIL. **Step 3:** Implementar y reemplazar todo emoji de la UI por `categoryIcon`/`uiIcon`. **Step 4:** PASS, `flutter analyze` limpio.
- [ ] **Step 5:** Checkpoint. Mensaje sugerido: `feat: íconos Phosphor en lugar de emojis`.

---

### Task 7: Texto natural en la carga

**Files:**
- Create: `lib/features/entry/domain/natural_parser.dart`
- Modify: `lib/features/entry/ui/entry_flow.dart` (campo arriba de la grilla; muestra la propuesta; nunca guarda directo)
- Test: `test/features/entry/natural_parser_test.dart`

**Interfaces:**
- Produces: `class ParsedEntry { int amount; String? categoryId; DateTime occurredLocalDay; String? merchant; }` y `ParsedEntry? parseNaturalEntry(String input, {required DateTime nowLocal, required Map<String, String> keywordToCategoryId})` → `null` si no hay monto.

- [ ] **Step 1: Tests que fallan** (`nowLocal` = jueves 2026-10-08; keywords `{'café': comida, 'super': hogar, 'bolt': transporte, 'uber': transporte}`):

```dart
expect(parseNaturalEntry('café 15000', ...)!.amount, 15000);
expect(parseNaturalEntry('café 15000', ...)!.categoryId, comida);
final s = parseNaturalEntry('super 230 mil ayer', ...)!;
expect(s.amount, 230000); expect(s.categoryId, hogar); expect(s.occurredLocalDay, DateTime(2026, 10, 7));
expect(parseNaturalEntry('bolt 28.500', ...)!.amount, 28500);
expect(parseNaturalEntry('uber 25k', ...)!.amount, 25000);
expect(parseNaturalEntry('almuerzo 45.000 el lunes', ...)!.occurredLocalDay, DateTime(2026, 10, 5));
expect(parseNaturalEntry('anteayer farmacia 60mil', ...)!.occurredLocalDay, DateTime(2026, 10, 6));
expect(parseNaturalEntry('15000', ...)!.categoryId, isNull);
expect(parseNaturalEntry('café', ...), isNull);
expect(parseNaturalEntry('Café Martínez 15000', ...)!.merchant, 'Café Martínez');
```

Reglas: el día de la semana nombrado es el más reciente ≤ hoy (si es hoy, hoy). Palabras clave sin distinguir mayúsculas ni tildes. `merchant` = texto restante sin monto ni palabras de fecha, con su capitalización original; `null` si queda vacío.

- [ ] **Step 2:** FAIL. **Step 3:** Implementar. Mapa de palabras clave inicial: un `const` por categoría del seed (p. ej. Comida: café, almuerzo, cena, delivery, pedidosya; Transporte: bolt, uber, nafta, combustible, peaje; Hogar: super, superseis, stock, biggie, ferretería; Salud: farmacia, médico; Servicios: ande, essap, tigo, personal, claro, netflix, spotify). **Step 4:** PASS.
- [ ] **Step 5:** Test de widget: escribir `'bolt 28.500'` y confirmar la propuesta abre el teclado de Transporte con `Gs. 28.500`. PASS.
- [ ] **Step 6:** Checkpoint. Mensaje sugerido: `feat: carga por texto natural`.

---

### Task 8: Shell con barra de vidrio e Inicio (total, resplandor, barra por categoría, calendario)

**Files:**
- Create: `lib/features/shell/ui/app_shell.dart`, `lib/features/home/ui/home_screen.dart`, `lib/features/home/ui/month_glow.dart`, `lib/features/home/ui/heat_calendar.dart`
- Modify: `lib/app.dart` (home = `AppShell`)
- Test: `test/features/home/home_screen_test.dart`, `test/features/home/heat_calendar_test.dart`

**Interfaces:**
- Consumes: repositorio (Task 4), `heatLevels` (Task 5), `showEntryFlow` (Task 6), diseño (Task 3).
- Produces: `AppShell` (pestañas Inicio · Movimientos · ＋ · Presupuestos · Reportes; Presupuestos y Reportes muestran un placeholder "Próximamente" hasta los planes 2-3; ＋ llama `showEntryFlow`); `HeatCalendar({required int year, required int month, required Map<int, int> levels, required DateTime todayLocal, required ValueChanged<int> onDayTap})`; `MonthGlow({required Color color})` — degradado radial pintado (sin `BackdropFilter` ni `ImageFilter`), color animado con `TweenAnimationBuilder` lento (~900 ms).

Inicio (spec §5.2, sin la línea de quincena ni la tarjeta de sugeridos, que llegan en el plan 2):
- Selector de mes (pill "Octubre ▾"); deslizar el calendario horizontalmente cambia de mes con `Haptics.tick()`.
- Total del mes con `formatGs`, que cuenta animado al cambiar.
- `MonthGlow` con el `colorDark`/`colorLight` de la primera categoría de `watchMonthCategoryTotals`; si está vacío, `brandStart`.
- Barra segmentada proporcional a `watchMonthCategoryTotals`.
- `HeatCalendar` "Tus días": grilla lunes→domingo, celdas vacías antes del día 1, hoy con borde, días futuros punteados.
- Últimos movimientos (`watchRecent(limit: 5)`) en `GlassCard`.

- [ ] **Step 1: Tests que fallan:**

```dart
testWidgets('mes vacío: Gs. 0, sin crash, glow de marca', (t) async { /* find.text('Gs. 0'); MonthGlow.color == brandStart */ });
testWidgets('total y glow siguen a la categoría con más gasto', (t) async {
  /* Hogar 380.000 + Comida 186.000 → 'Gs. 566.000', MonthGlow.color == Hogar.colorDark */
});
testWidgets('octubre 2026 empieza en jueves: 3 celdas vacías antes del 1', (t) async {
  /* HeatCalendar(year: 2026, month: 10): primeras 3 celdas sin número, la 4ª dice '1'; 31 celdas numeradas */
});
testWidgets('días futuros punteados y hoy con borde', (t) async { /* todayLocal = 24/10: celda 25 tiene decoración punteada; 24 tiene borde */ });
testWidgets('el ＋ abre la carga', (t) async { /* tap '+' → find.text('Comida') */ });
```

- [ ] **Step 2:** FAIL. **Step 3:** Implementar. **Step 4:** PASS.
- [ ] **Step 5:** Verificación en el A54 (oscuro y claro, cambiando el tema del sistema): resplandor visible, vidrio de la barra con desenfoque, nada recortado por el notch.
- [ ] **Step 6:** Checkpoint. Mensaje sugerido: `feat: inicio con resplandor y calendario de calor`.

---

### Task 9: Detalle del día, Movimientos y borrar con deshacer

**Files:**
- Create: `lib/features/home/ui/day_detail_sheet.dart`, `lib/features/transactions/ui/transactions_screen.dart`
- Modify: `home_screen.dart` (tap en día → hoja; deslizar movimiento → editar/borrar), `app_shell.dart` (pestaña Movimientos)
- Test: `test/features/home/day_detail_sheet_test.dart`, `test/features/transactions/transactions_screen_test.dart`

**Interfaces:**
- Consumes: `watchDay`, `watchDailyExpenseTotals`, `watchFiltered`, `softDelete`, `restore` (Task 4); `showEntryFlow(editing:)` (Task 6).
- Produces: `Future<void> showDayDetail(BuildContext context, DateTime localDay)`; `Future<void> deleteWithUndo(BuildContext context, WidgetRef ref, String txId)` — `softDelete` + aviso "Movimiento borrado · Deshacer" de 5 s que vive en el `ScaffoldMessenger` raíz (sobrevive a cambios de pestaña).

Detalle del día (spec §5.2.6): título con fecha larga en español ("Viernes 17 de octubre"), total del día, "N,N× tu día promedio" (promedio = total del mes ÷ días con gasto; se omite si es el único día con gasto), "tu día más caro del mes" si corresponde, barras "En qué se fue" por categoría y lista de movimientos.

Fecha en "Últimos movimientos" del Inicio (pedido del autor): cada fila muestra categoría o comercio y debajo la fecha relativa con hora: `Hoy · 14:32`, `Ayer · 09:03`; otros días, `Lun 6 oct · 19:40` (español, zona local). Función pura `String formatTxWhen(DateTime occurredLocal, DateTime nowLocal)` en `lib/core/format/dates.dart`, con tests para hoy, ayer, otro día de la misma semana y otro mes.

Movimientos (spec §5.4): lista agrupada por día local (encabezados "Hoy", "Ayer", luego fecha), búsqueda (nota y comercio) y filtros por categoría, tipo y rango de fechas.

- [ ] **Step 1: Tests que fallan:**

```dart
testWidgets('detalle: total, múltiplo del promedio y categorías', (t) async {
  /* mes con 17: 612.000 y 3 días más sumando 108.000 → promedio 180.000 → '3,4× tu día promedio' y 'tu día más caro del mes' */
});
testWidgets('borrar y deshacer tras cambiar de pestaña', (t) async {
  /* deslizar y borrar en Inicio → ir a Movimientos → tap 'Deshacer' → el movimiento vuelve y aparece una sola vez */
});
testWidgets('Movimientos agrupa por día y filtra por búsqueda', (t) async { /* encabezados 'Hoy'/'Ayer'; query 'super' deja solo Superseis */ });
```

- [ ] **Step 2:** FAIL. **Step 3:** Implementar. **Step 4:** PASS.
- [ ] **Step 5:** A54: la celda del día se transforma en la hoja (Hero + `soft`), sin saltos.
- [ ] **Step 6:** Checkpoint. Mensaje sugerido: `feat: detalle del día, movimientos y deshacer`.

---

### Task 10: Ícono, splash y prueba final en el A54

**Files:**
- Create: `assets/brand/` (PNG exportados), `android/app/src/main/res/` (mipmaps, `ic_launcher.xml` adaptativo, capa monocroma), estilos de splash Android 12+
- Source: `docs/brand/pockt-icon.svg`

**Interfaces:**
- Consumes: SVG maestro (lienzo 108×108, zona segura 66×66).

- [ ] **Step 1:** Exportar desde el SVG: capa **frontal** (orbe + abertura, sin fondo), capa de **fondo** (negro + resplandor), **monocroma** (orbe sólido + abertura recortada, un color) y PNG de 1024 px para splash. Usar `rsvg-convert` o Inkscape CLI.
- [ ] **Step 2:** Configurar `mipmap-anydpi-v26/ic_launcher.xml` con `<adaptive-icon>` (`foreground`, `background`, `monochrome`) y los mipmaps por densidad; splash con `windowSplashScreenAnimatedIcon` y fondo `#000000`.
- [ ] **Step 3:** `flutter build apk --release` (firma debug por ahora) e instalar en el A54: `adb -s R5CW31LZ4WK install -r build/app/outputs/flutter-apk/app-release.apk`.
- [ ] **Step 4:** Verificar en el teléfono y documentar con capturas (`adb exec-out screencap -p`): ícono en pantalla de inicio con fondo oscuro y claro, ícono temático activado, splash al abrir.
- [ ] **Step 5:** Prueba completa en release: cargar gastos e ingresos, texto natural, editar, borrar y deshacer, detalle del día, cambio de mes, oscuro y claro.
- [ ] **Step 5b: Medición de rendimiento** — `integration_test/perf_test.dart` con `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` y `binding.traceAction(..., reportKey: 'transiciones')` que recorre: abrir carga → tocar categoría (burbuja→teclado) → guardar; tocar un día del calendario (detalle); deslizar 3 meses. Driver `test_driver/perf_driver.dart` que escribe `TimelineSummary.summarize(...)`. Correr: `flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart -d R5CW31LZ4WK`. Aceptación: `99th_percentile_frame_build_time_millis` y `99th_percentile_frame_rasterizer_time_millis` ≤ 8.
- [ ] **Step 5c: Tamaño** — `flutter build apk --release --target-platform android-arm64 --analyze-size`; confirmar que las fuentes de Phosphor se recortan ("Font asset ... was tree-shaken") y reportar el tamaño final.
- [ ] **Step 6:** Checkpoint. Mensaje sugerido: `feat: ícono adaptativo y splash de Pockt`.

---

### Task 7b: Texto natural que aprende (historial, palabras editables, errores de tipeo)

Se ejecuta **después de la Task 10**. La app ya está instalada en el A54 con datos reales: el cambio de esquema necesita **migración v1 → v2**.

**Files:**
- Modify: `lib/core/db/tables.dart`, `lib/core/db/app_database.dart` (`schemaVersion` 2 + migración), `lib/features/transactions/data/transactions_repository.dart`, `lib/features/entry/domain/natural_parser.dart`, `lib/features/entry/ui/entry_flow.dart`, `lib/features/home/ui/home_screen.dart` (ícono de ajustes abre la pantalla nueva, provisorio hasta el plan 4)
- Create: `lib/features/transactions/data/keywords_repository.dart`, `lib/features/settings/ui/category_keywords_screen.dart`
- Test: `test/core/db/migration_v2_test.dart`, `test/features/transactions/keywords_repository_test.dart`, `test/features/entry/natural_parser_test.dart` (casos nuevos)

**Interfaces:**
- Tablas nuevas:
  - `CategoryKeywords`: `id` (UUID), `categoryId` (FK), `keyword` (normalizado: minúsculas, sin tildes), `source` (`enum KeywordSource { seed, user }`). Único (`categoryId`, `keyword`).
  - `MerchantMemory`: `merchantKey` (PK, normalizado), `categoryId`, `uses` (int), `lastUsedAt`.
- Migración v2: crea las dos tablas y copia `kSeedCategoryKeywords` a `CategoryKeywords` **por id de categoría** (resolviendo el nombre una sola vez, en la migración). A partir de ahí el parser no usa más los nombres.
- `KeywordsRepository(AppDatabase db)`:
  - `Stream<List<CategoryKeyword>> watchFor(String categoryId)`
  - `Future<void> addUserKeyword(String categoryId, String keyword)` (normaliza; ignora duplicados)
  - `Future<void> remove(String id)`
  - `Future<Map<String, String>> keywordMap()` — palabra → categoryId. Prioridad: `MerchantMemory` (la categoría con más `uses`) > `user` > `seed`.
- `TransactionsRepository.add/update`: si `merchant` no es nulo, hace upsert en `MerchantMemory` (`uses + 1`, `lastUsedAt`) **en la misma transacción SQL**.
- Parser: misma firma de `parseNaturalEntry`. Coincidencia: exacta primero; si no hay, tolerancia con `int damerauLevenshtein(String a, String b)` — distancia ≤ 1 para palabras de 4–6 letras, ≤ 2 para 7 o más; palabras de menos de 4 letras solo exactas. Ante empate gana la de mayor prioridad del mapa.
- `CategoryKeywordsScreen`: lista de categorías; al entrar en una, sus palabras (chips, con origen visible), agregar y borrar. Lenguaje visual existente (GlassCard, tokens, íconos Phosphor).

- [ ] **Step 1: Tests que fallan:**
  - Migración: una base v1 con 2 movimientos → tras migrar, los movimientos siguen y `CategoryKeywords` tiene las palabras del seed con los ids correctos.
  - Renombrar "Comida" a "Comidas" → `keywordMap()['pizza']` sigue apuntando a su id.
  - Guardar un gasto con comercio "Superseis" en Hogar → `keywordMap()['superseis'] == hogar`; guardarlo 3 veces en Comida y 1 en Hogar → gana Comida.
  - `addUserKeyword(salud, 'Farma')` → `parseNaturalEntry('farma 40000', ...)!.categoryId == salud`.
  - Tipeo: `'suoer 230 mil'` → Hogar; `'cafr 15000'` → Comida; `'bar'` no matchea `'bat'` (palabra corta, solo exacta).
- [ ] **Step 2:** FAIL. **Step 3:** Implementar. **Step 4:** PASS; `flutter analyze` en 0.
- [ ] **Step 5:** Checkpoint. Mensaje sugerido: `feat: texto natural que aprende de tu historial`.
