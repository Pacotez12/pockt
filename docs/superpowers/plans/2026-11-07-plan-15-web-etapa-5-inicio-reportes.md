# Pockt web, etapa 5: Inicio y Reportes

> **Para quien implementa:** TDD. No commitear: el orquestador revisa y
> commitea. Reporte final corto. Datos inventados en tests, golden cases y
> capturas. No iniciar sesión con la cuenta del usuario.

**Objetivo:** Inicio completo y Reportes en la web, con los **mismos números
que la app** garantizados por casos de prueba compartidos (golden cases) que
corren en Dart y en TypeScript, más "Tus días" en 3D y el PDF de resumen.

**Spec:** `docs/superpowers/specs/2026-10-29-pockt-web-design.md` (secciones 2,
5, 7, 8 y etapa 5). **Bocetos aprobados:**
`.superpowers/brainstorm/171364-1793283290/content/web-pantallas.html`
(Inicio y Reportes), `.superpowers/brainstorm/87432-1794075636/content/propuesta-1b-tus-dias-3d-webgl.html`
("Tus días" 2D/3D con three.js) y el movimiento de
`propuesta-2-3-fondo-y-movimiento.html`.

## Restricciones globales

- Las de los planes 13 y 14. **Sin "Podés gastar hoy" en la web.**
- La web no comparte código con la app: se portan a TypeScript solo los
  cálculos que la web necesita, en `web/src/lib/calc/`, uno por archivo,
  leyendo el código Dart como fuente de verdad:
  - período del mes según "inicio del mes" y cobros: `lib/core/time/date_period.dart`
    (`periodFor`), `lib/features/home/domain/home_period_summary.dart`;
  - totales y arco por categoría: `lib/features/home/domain/category_arc_data.dart`;
  - niveles del mapa de calor: `lib/features/home/domain/heat_levels.dart`;
  - avance de préstamos (con cronograma y cuotas ya pagadas):
    `lib/features/loans/domain/loan_progress.dart`;
  - metas: `lib/features/goals/domain/goal_progress.dart`;
  - presupuestos: `lib/features/budgets/domain/budget_status.dart`;
  - próximos vencimientos de recurrentes: `lib/features/recurring/domain/recurrence.dart`;
  - reportes (comparación, hormiga, resumen semanal):
    `lib/features/reports/domain/*.dart` y `lib/features/reports/data/reports_repository.dart`.
- **Golden cases:** `shared/golden/<calculo>.json` con `{ "cases": [ { "name",
  "input", "expected" } ] }`. El mismo archivo lo leen un test Dart
  (`test/golden/<calculo>_golden_test.dart`, llama a la función real de la
  app) y un test Vitest (`web/src/lib/calc/<calculo>.golden.test.ts`). Al
  menos 6 casos por cálculo, incluidos bordes: mes que empieza el 1 y el 25,
  cobro en fin de semana, año bisiesto, cambio de año, préstamo con cuotas
  ya pagadas y con cronograma variable, meta sin fecha, presupuesto en 0.
  Si el Dart necesita un adaptador chico para leer el JSON, va en el test,
  nunca en `lib/`.
- Gráficos: SVG propio o una librería gratis y liviana (elegir una sola,
  versión exacta). "Tus días" 3D: `three` versión exacta, una sola
  `InstancedMesh`, carga diferida (solo en Reportes), sin bloquear la
  primera pantalla. PDF: `jspdf` (MIT) o equivalente gratis.

## Foco de revisión

1. Mismos números que la app (golden cases en verde en los dos lados).
2. "Inicio del mes" distinto de 1 (por ejemplo 25) cambia todos los totales.
3. Performance: "Tus días" 3D fluido (sin trabarse) y Reportes con un año de
   datos sin congelar la pantalla (cálculos en SQL o memoizados).
4. Reducir movimiento: 3D y conteos sin animación.
5. PDF y descargas sin datos de otras personas ni llaves.

---

### Tarea 5.1: cálculos y golden cases

- [ ] Por cada cálculo de la lista: JSON de golden cases, test Dart contra la
  función de la app (en verde sin tocar `lib/`), test Vitest que falla,
  port a TS, verde. `flutter test` completo y `npm test` en verde.

### Tarea 5.2: Inicio completo

- [ ] Según el boceto: tarjeta principal "Gastado en <período>" con arco por
  categoría, ingresos, ahorrado en metas, entradas y salidas de 6 meses,
  últimos movimientos (abre el panel de la etapa 4), próximos vencimientos
  (cuotas de préstamos y recurrentes, 30 días). Skeletons por parte
  (números, gráficos, listas). Montos con `CountUp`, tarjetas escalonadas.

### Tarea 5.3: Reportes y "Tus días" 3D

- [ ] Período Mes / Año / Personalizado (en la URL). Totales, ahorro neto,
  mes más caro, suscripciones al año (recurrentes), tendencia por categoría,
  ranking de comercios, gastos hormiga (como la app).
- [ ] "Tus días": mapa de calor del período elegido (6 meses por defecto)
  según `propuesta-1b-tus-dias-3d-webgl.html`: 2D por defecto, botón 3D con
  spring interrumpible, arrastrar para girar, globo con detalle al pasar el
  mouse, clic abre los movimientos de ese día. Niveles de color iguales a la
  app (`heat_levels`). Sin WebGL: queda en 2D (SVG). Test del cálculo de
  niveles y de la vista sin WebGL.

### Tarea 5.4: descargas de Reportes

- [ ] CSV y Excel del período (reusar la etapa 4) y PDF de resumen de una o
  dos páginas: totales, gráfico por categoría, ranking de comercios, con la
  identidad de Pockt (logo, tipografía, sin degradé de fondo). Test de que
  el PDF se genera y contiene los totales.

## Verificación final (orquestador)

Golden cases en verde en Dart y TS; `flutter analyze` 0, `flutter test`,
`npm test`, `npm run build`; en el navegador con la cuenta del usuario, Inicio
y Reportes coinciden con la app para el mismo período; 3D fluido.
