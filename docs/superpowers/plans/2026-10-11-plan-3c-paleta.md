# Pockt — Plan 3c: Paleta y uso correcto del color

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** que cada color tenga un solo rol en toda la app (spec §6.2b), con Ajustes en la familia de la marca (opción B aprobada el 2026-10-11).

**Spec:** `docs/superpowers/specs/2026-10-08-nucleo-design.md` §6.2b. **Orden:** antes de seguir con el plan 4b (Ajustes por secciones usa estas reglas).

**Global Constraints:** las de planes anteriores; TDD donde haya lógica (migración, funciones de color); sin cambios de layout ni de comportamiento; skills `impeccable` (colorize/polish), `ui-ux-pro-max` (stack flutter), `emil-design-eng`; no commitear ni usar el teléfono.

---

## Auditoría (2026-10-11)

Origen de los colores: **ninguno copiado de possible_rfid**. Coincidencias con ese repo: solo `#18181B`, `#E4E4E7` y `#10B981`, valores genéricos de Tailwind. Problemas reales encontrados:

1. **Choques de significado en categorías:** Comida = `#FF9F43` = exactamente el color de aviso; Hogar = `#1DD1A1` = exactamente el color positivo. Ingresos (Sueldo, Extra, Otros ingresos) sacados de otra paleta (Tailwind), con saturación distinta a los gastos.
2. **Estados usados como decoración:** `settings_screen.dart` ícono de Esquema de cobro en positivo (l.122) y Recordatorios en aviso (l.198); `restore_flow.dart` l.285 y `backup_screen.dart` l.632 íconos decorativos en positivo.
3. **Gastos en rojo de peligro:** `reports/ui/charts.dart` l.300/330 (serie Gastos = `danger`); los gastos no son un error.
4. **Ahorro neto:** `reports_screen.dart` l.950 usa marca para ahorro ≥ 0 (debe ser positivo) y peligro para < 0 (correcto).
5. **Marca dispersa sin regla:** unas 90 apariciones de `brandStart/brandEnd`; correctas en botones principales, selección, sliders, interruptores, calendario y logo; incorrectas como color de texto/íconos informativos sueltos (p. ej. `income_schedule_screen.dart` l.663, l.729, l.1166; `recurring_screen.dart` l.128, l.195, l.230, l.742; `reminders_screen.dart` l.515, l.567; `backup_screen.dart` l.521; `restore_flow.dart` l.269). Cada uso se decide con la tabla de §6.2b: si es acción/selección queda; si es información, pasa a texto 1/2.
6. **Colores escritos a mano fuera de tokens:** `month_glow.dart` (`glowAmber` = `#FF9F43`, `glowRedPink`), `pockt_splash.dart` l.241-243, `tx_row.dart` l.249 (grises), `amount_keypad.dart` l.126 (`Colors.red.shade900`) y l.276, `entry_flow.dart` l.438 y l.645 (`#141414`).
7. **Íconos de Material** en `restore_flow.dart` (8) y `backup_screen.dart` (2): deben ser Phosphor.
8. **Calendarios:**
   - Calendario de calor (`heat_calendar.dart` + `tokens.dart` `heat`): la escala usa naranjas sueltos que no son la marca (`#FF7A45`, `#FF645F`; en claro `#FFB08A`, `#FF8A5C`, `#F2603F`, `#E8306F`) y el nivel 4 lleva degradé solo en modo oscuro (en claro es plano): la escala tiene que salir de los 4 pasos de `brandAt` (niveles 1–3 con opacidad creciente, nivel 4 con el degradé completo) igual en ambos temas.
   - "Hoy" se marca distinto en cada calendario: en el de calor con un anillo blanco/texto, en el selector de fecha (`theme.dart` `datePickerTheme`) con anillo y número en marca. Regla: **hoy = anillo de texto 1** en ambos (la marca queda para lo seleccionado), y el día elegido en el selector = relleno de marca con número blanco (ya está).
   - Leyenda del calendario de calor (l.78–81) con los mismos pasos que las celdas; celdas futuras con borde punteado escrito con `Colors.white/black` sueltos → tokens.
9. **Ajustes sin regla de color** (opción B): las filas mezclan marca, positivo y aviso al azar.

---

### Task 1: Tokens
**Files:** `lib/core/design/tokens.dart`; Test `test/core/design/tokens_test.dart`.
- Estados nuevos de §6.2b (oscuro y claro), `brandRamp` con los 4 pasos del degradé (`brandAt(int step)` 0..3) y una superficie `keypadKey` para reemplazar `#141414`.
- Test: los estados no coinciden con ningún color de categoría de fábrica; contraste ≥ 3:1 de estados y pasos del degradé contra el fondo en ambos temas.

### Task 2: Paleta de categorías
**Files:** `app_database.dart` (semilla y migración v7), Test de migración.
- Semilla con la paleta de §6.2b. Migración: actualizar `colorDark/colorLight` solo en las categorías de fábrica cuyo color sigue siendo el viejo por defecto (las personalizadas no se tocan).
- Tests: base nueva con la paleta nueva; migración cambia las de fábrica intactas y conserva una personalizada.

### Task 3: Colores fuera de tokens
Puntos 6 de la auditoría: todos pasan a tokens (`warning`, `brandEnd`, `brandStart`, `danger`, neutros, `keypadKey`). `grep` de `Color(0x` y `Colors\.(red|green|blue|orange|amber|grey)` fuera de `tokens.dart`, `wordmark.dart` y la semilla de categorías debe quedar vacío (agregar ese chequeo como test).

### Task 4: Estados solo como estado
Puntos 2, 3 y 4: gastos en marca y no en peligro en Evolución (leyenda incluida); ahorro neto positivo/peligro; íconos decorativos de restauración/backup fuera de positivo. Tests de widget de leyenda y del color del ahorro.

### Task 5: Marca solo como acción, selección o sección
Punto 5: recorrer cada uso listado y aplicar §6.2b. Ajustes (punto 9): cada sección toma un paso de `brandAt` (Tu dinero 0, Carga 1, Inicio y apariencia 2, Avisos y Privacidad 3) en encabezado e ícono; el aviso de backup atrasado sigue en `warning`. Skills: `impeccable`, `emil-design-eng`.

### Task 5b: Calendarios
Punto 8: escala `heat` derivada de `brandAt` en ambos temas (nivel 4 con degradé también en claro), "hoy" con anillo de texto 1 en el calendario de calor y en el selector de fecha, leyenda igual a las celdas, punteado de días futuros con tokens. Tests: la escala `heat` de cada tema sale de la marca (mismo matiz que `brandAt`); el selector marca hoy con `textPrimary`; contraste del número sobre cada nivel ≥ 4,5:1 (si no llega, número en blanco desde el nivel que haga falta).

### Task 6: Íconos de Phosphor
Punto 7 de la auditoría: reemplazar los `Icons.*` por equivalentes de `uiIcon(...)`/Phosphor.

### Task 7: Verificación (orquestador)
Capturas de Inicio, Carga, Reportes, Presupuestos y Ajustes en oscuro y claro en el A54; revisión con `impeccable` (critique); commit.
