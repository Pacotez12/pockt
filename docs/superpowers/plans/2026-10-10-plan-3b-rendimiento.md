# Pockt — Plan 3b: rendimiento de dibujo y ajustes visuales

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Volver a la meta de fluidez (spec §6.5: ningún frame > 8,3 ms, medido como p99 de build y de raster) después de las funciones del plan 3, y corregir las tarjetas de Comparación en modo oscuro.

**Contexto (medición del cierre del plan 3, variante `.perf`, 40 frames):** build promedio 4,6 / p90 9,5 / p99 16,3 ms; **raster promedio 10,0 / p90 16,5 / p99 18,9 ms** (antes del plan 3: raster promedio 6,6, p99 14,9). El cuello de botella es el **raster** (GPU), no la construcción de widgets.

**Architecture:** primero medir por escenario para saber qué pantalla cuesta; después corregir lo que mida peor, de a una causa por cambio, y volver a medir. Candidatos conocidos de costo de raster: `BackdropFilter` (desenfoque), `saveLayer` implícitos (`Opacity` sobre subárboles, `ShaderMask`, `ClipRRect` con antialias sobre contenido animado), sombras grandes, degradados radiales a pantalla completa que se repintan cada frame, `CustomPainter` sin `RepaintBoundary`.

**Spec:** `docs/superpowers/specs/2026-10-08-nucleo-design.md` §6.3–§6.5. Global Constraints de los planes 1–3 vigentes (en particular: **nunca `flutter drive` con el applicationId real**; medir solo con `-P pocktPerf=true`; las mediciones en el teléfono las corre el orquestador).

---

### Task 1: Medición por escenario + tarjetas de Comparación

**Files:** Modify `integration_test/perf_test.dart`, `test_driver/perf_driver.dart`, `lib/features/reports/ui/reports_screen.dart`; Test `test/features/reports/reports_screen_test.dart`.

- Un `binding.traceAction` **por escenario**, cada uno con su `reportKey`: `apertura` (arranque con la animación), `carga` (＋ → categoría → teclado → guardar), `detalle_dia` (tocar día y cerrar), `cambio_mes` (deslizar 3 meses), `reportes` (abrir Reportes y deslizar las 4 vistas), `scroll_inicio` (scroll del Inicio con la barra de vidrio encima). El driver escribe un `*.timeline_summary.json` por escenario.
- **Comparación en modo oscuro:** las dos tarjetas "Mes actual / Mes anterior" usan un gris claro fijo; deben usar las superficies de los tokens (vidrio / superficie de hoja) en ambos modos. Test: en tema oscuro el color de fondo de esas tarjetas sale de `PocktColors.dark`.
- Checkpoint. `test: medición de rendimiento por escenario` y `fix: tarjetas de comparación con los colores del tema`.

### Task 2: Correcciones guiadas por la medición

El orquestador corre la medición en el A54 y pasa la tabla por escenario. Para cada escenario por encima de la meta, de mayor a menor: identificar la causa en el timeline (`build/<escenario>.timeline.json`: eventos de raster largos, `saveLayer`, `BackdropFilter`) y aplicar **una** corrección por commit, por ejemplo: `RepaintBoundary` alrededor de lo que se anima, reemplazar `Opacity` animada por `FadeTransition`/opacidad en el color, desenfoque solo cuando la barra está sobre contenido que se mueve, degradados pintados una vez (`RepaintBoundary` + `isComplex`/`willChange`), sombras más chicas. Sin cambiar el diseño aprobado.

- [ ] Por cada corrección: medición antes/después del escenario afectado (la corre el orquestador), commit con los números en el mensaje.
- [ ] Cierre: todos los escenarios con raster y build p99 ≤ 8,3 ms, o un informe honesto de los que no llegan y por qué.

### Task 3: Resplandor aurora con reacción al mes

**Spec:** §6.2 punto 2 (aurora sutil, reacción al presupuesto, pulso al guardar). **Files:** Modify `lib/features/home/ui/month_glow.dart` y donde se use; Test `test/features/home/month_glow_test.dart`.

- Dos manchas con degradado radial pintado una vez; deriva lenta con `AnimationController` repetido (ida y vuelta) aplicado solo como `Transform` (traslación + escala) dentro de un `RepaintBoundary`. Con `MediaQuery.disableAnimations` quedan quietas.
- Función pura `glowTint(Color base, double spentRatio)`: sin mezcla < 0,8; hacia ámbar entre 0,8 y 1,0; rojo-rosa ≥ 1,0. `spentRatio` = gastado del mes / suma de presupuestos; null sin presupuestos (sin mezcla). Tests unitarios de los tres tramos.
- Pulso al guardar un movimiento (escala 1 → 1,08 → 1, ~500 ms). Test de widget: el pulso se dispara al guardar.
- Sin regresión de rendimiento: el orquestador mide `scroll_inicio` y `cambio_mes` (mediana de 3) antes y después.
- Checkpoint. `feat: resplandor aurora que reacciona al mes`.
