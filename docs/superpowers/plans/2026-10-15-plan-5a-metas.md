# Pockt — Plan 5a: Metas de ahorro

**Spec:** §7d "Metas" (opción B). **Global Constraints:** las de los planes anteriores; TDD; migración Drift con test desde la versión actual; paleta §6.2b; solo íconos Phosphor (agregar al mapa de `icons.dart` los que hagan falta: airplane-tilt, laptop, shield-check, piggy-bank, house-line, car, gift, graduation-cap, target); datos reales del autor (migraciones sin pérdida); no commitear ni usar el teléfono.

### Task 1: Modelo y dominio
Tablas `goals` y `goal_contributions` (migración). `GoalsRepository` (crear, editar, archivar, aportar, retirar = aporte negativo, `watchActive`, `watchContributions`). `goal_progress.dart` puro: ahorrado, %, restante, ritmo necesario por mes (si tiene fecha), ritmo real (promedio de aportes 90 días), fecha proyectada, estado `onTrack` / `late(meses)` / `noDate`, y `delayDaysFor(amount)` (monto ÷ ritmo diario real; null sin ritmo). Tests de cada cálculo, incluidos 0 aportes y meta cumplida.

### Task 2: "Quedan" descuenta aportes
Los aportes del período de cobro actual restan de `quedan` (period_summary y donde se calcule). Test: aporte de 300.000 baja quedan en 300.000; retiro lo devuelve.

### Task 3: Pantallas
Lista de metas (opción B de la maqueta: encabezado de ahorrado total, tarjetas con ícono, fecha, %, barra con degradé, ritmo y estado) y detalle (anillo, Aportar/Retirar con el teclado de montos existente, editar, archivar; historial de aportes). Editor de meta (nombre, ícono de una grilla Phosphor, monto, fecha opcional). Acceso: Ajustes → Tu dinero → Metas y tarjeta "Metas" del Inicio (registrada en Tarjetas del Inicio, hasta 2 metas, oculta sin metas). Skills: emil-design-eng, impeccable, ui-ux-pro-max (stack flutter), apple-design. Tests de widget.
