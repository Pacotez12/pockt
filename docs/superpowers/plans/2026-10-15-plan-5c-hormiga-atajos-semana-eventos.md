# Pockt — Plan 5c: Gastos hormiga, atajos, resumen semanal y eventos

**Spec:** §7d. **Global Constraints:** las de siempre.

### Task 1: Gastos hormiga en Reportes (opción A)
Vista "Hormiga" en Reportes: gastos ≤ umbral (ajuste `reports.antThreshold`, por defecto 30.000) del período; total, cantidad, proyección anual, agrupado por comercio (o categoría) con cantidad y promedio, ícono de la categoría. Tests de la agrupación y la proyección.

### Task 2: Atajos de carga
Sugerencias por repetición (mismo comercio/nota + monto + categoría ≥ 3 veces en 60 días), máximo 6, fijar/quitar (tabla `entry_shortcuts`). Chips sobre la grilla de la carga; un toque guarda con deshacer. Tests.

### Task 3: Resumen semanal
Notificación domingo 19:00 (respeta silencio, se programa con la tarea diaria): total de la semana, % vs la anterior, categoría principal; payload abre Reportes. Ajuste para apagarlo en Avisos. Tests del texto y la programación.

### Task 4: Eventos
Tabla `events` y `eventId` nullable en movimientos (migración). Crear evento, marcar activo (los gastos nuevos se asignan solos mientras esté activo), pantalla de evento con total y desglose por categoría; acceso desde Ajustes → Tu dinero y un chip en la carga cuando hay evento activo. Tests.
