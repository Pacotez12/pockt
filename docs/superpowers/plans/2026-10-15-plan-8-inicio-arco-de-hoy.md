# Pockt — Plan 8: Inicio con "Arco de hoy"

Spec: núcleo §7d-bis (y §7d, §7e). Maqueta aprobada: `.superpowers/brainstorm/2070133-1792112183/content/inicio-v6.html`, opción D (local, no se commitea).

**Restricciones globales:** TDD (test que falla primero), `flutter test --timeout 30s`, `flutter analyze` en 0, sin `dart format` de carpetas enteras, íconos Phosphor, tokens §6.2b (`PocktType`, `PocktRadii`, `glassFill`, `danger`, degradé de marca solo en el arco). No commitear, no usar el teléfono, no revertir archivos ajenos. Skills: `test-driven-development`, `emil-design-eng`, `apple-design`, `impeccable`, `ui-ux-pro-max` (flutter).

**Orden:** después del plan 7.

### Task 1: Límite de hoy (dominio)
**Files:** `lib/features/safe_to_spend/domain/safe_to_spend.dart` + test.
- `todayAllowance` = cálculo de "Podés gastar hoy" con `quedan + gastadoHoy` (los gastos de hoy no achican el límite); `spentToday`; `leftToday = todayAllowance − spentToday`.
- Tests: gastar durante el día no cambia `todayAllowance`; excedente; límite ≤ 0; día de cobro (usa el período nuevo, plan 6).

### Task 2: Arco de hoy (widget)
**Files:** `lib/features/home/ui/today_arc.dart` (CustomPainter) + test.
- Semicírculo, pista `glassFill`, progreso con degradé de marca, extremos redondeados; estados normal / te pasaste (`danger`) / sin margen. Texto centrado que no toca el arco con textScaler 1.3 en 360 px (FittedBox). Semantics con el texto completo ("Te quedan hoy Gs. X, gastaste Y de Z"). Animación de llenado 600 ms ease-out, desactivada con `motion.reduce`. "Ocultar montos" → ••••.

### Task 3: Tarjeta "Gastado en {mes}" y armado del Inicio
**Files:** `lib/features/home/ui/home_screen.dart` (+ widget propio para la tarjeta) + tests.
- Con `safeToSpend`: arco arriba, tarjeta con monto del mes, barra segmentada, "Quedan" (con la aclaración del saldo arrastrado) y "cobrás en N días"; se quitan el subtítulo "Gastado X · Quedan Y" y la línea del período. La tarjeta de sobrante (§7e) sigue apareciendo debajo cuando corresponde.
- Con `monthSpent`: Inicio clásico sin cambios.
- Tests: cada dato aparece una sola vez; estados del arco; ocultar montos; letra 1.3 sin overflow a 360 px; modo claro y oscuro.
