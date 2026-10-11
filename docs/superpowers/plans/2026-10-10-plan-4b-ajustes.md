# Pockt — Plan 4b: Ajustes reorganizados y descuentos del sueldo

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajustes organizado en cinco secciones con opciones reales, y el sueldo con descuentos para que "quedan" use lo que se cobra de verdad.

**Spec:** `docs/superpowers/specs/2026-10-08-nucleo-design.md` §7b (y §5 Inicio, §6 sistema visual). Maqueta aprobada el 2026-10-10.

**Orden:** se ejecuta después de la Task 6 del plan 4 (bloqueo) y antes de la Task 7 (primer uso), para que el primer uso pueda pedir el sueldo con descuentos.

**Global Constraints** (además de las de los planes 1–4):
- TDD en cada tarea: tests que fallan, verlos fallar, implementar, verlos pasar. `flutter test --timeout 30s` y `flutter analyze` en 0.
- Cada ajuste: clave nueva en `SettingsRepository` con valor por defecto igual al comportamiento actual (nada cambia para quien no toque Ajustes), y un provider que la expone. Las pantallas leen el provider, nunca la clave directa.
- Migraciones de Drift con test de migración desde la versión anterior (schemaVersion actual + 1) sin pérdida de datos.
- Sin cambios visuales fuera de lo pedido. Estética "Profundidad y luz": tarjetas de vidrio, encabezados de sección en versalitas, interruptores y segmentos propios del sistema de diseño; íconos Phosphor.
- No commitear (el orquestador commitea después de probar en el A54). No usar el teléfono.

---

### Task 1: Descuentos del sueldo
**Spec:** §7b "Sueldo y cobros". **Files:** `lib/core/db/tables.dart` (tabla `salary_deductions`: id, name, kind `percent`|`fixed`, value int — para `percent` en centésimas de punto, 900 = 9 %; scheduleId), migración; `lib/features/income/domain/` (función pura `netPayAmounts(gross, splitPercents, deductions)` → lista de netos por cobro, los descuentos sobre el último cobro); `income_schedule_screen.dart` renombrada en la UI a "Sueldo y cobros" con la sección Descuentos (agregar, editar, borrar) y el resumen "Lo que cobrás"; "quedan", sugerencia de cobro inicial y estimaciones pasan a usar el neto.
- Tests: `netPayAmounts` con 4.000.000, 30/70, IPS 9 % + fijo 40.000 → [1.200.000, 2.400.000]; un descuento que deja el cobro negativo es rechazado; migración conserva el esquema existente; "quedan" estimado usa el neto.

### Task 2: Inicio del mes
**Spec:** §7b "Inicio del mes". Ajuste `period.monthStart` (`calendar` | `payday`). Un único `periodFor(DateTime day)` en `lib/core/time/` usado por Inicio, presupuestos, alertas, reportes y widget (buscar y reemplazar todos los cálculos de rango de mes dispersos). Con `payday` el período empieza en la fecha real del cobro de fin de mes (con las reglas de día hábil).
- Tests: con `calendar` el período de un día de octubre es 1/10–31/10; con `payday` y cobro el 30/09 el período del 05/10 es 30/09–(día anterior al siguiente cobro de fin de mes); presupuestos y totales del Inicio respetan el ajuste.

### Task 3: Opciones de carga
**Spec:** §7b "Carga". Ajustes `entry.categoryOrder` (`mostUsed` | `manual`), `entry.quickKey` (`000` | `00`), `entry.askNote` (bool), `feedback.haptics` (bool).
- Tests: con `mostUsed` la grilla ordena por uso de 90 días; la tecla muestra `00` y agrega dos ceros; con `askNote` aparece el campo antes de guardar; con vibración apagada `Haptics.debugRecorder` no registra nada.

### Task 4: Inicio y apariencia
**Spec:** §7b "Inicio y apariencia". Ajustes `home.cards` (lista ordenada con visibilidad), `home.recentCount` (5|10|20), `glow.mode` (`off`|`subtle`|`full`), `glow.reactsToBudget` (bool), `calendar.weekStart` (`monday`|`sunday`), `motion.reduce` (bool, se aplica envolviendo la app con `MediaQuery(disableAnimations: true)`). Pantalla "Tarjetas del Inicio" con reordenar arrastrando.
- Tests: ocultar y reordenar tarjetas cambia el Inicio; `off` no pinta aurora; `full` pinta tres manchas; semana en domingo corre las celdas del calendario; reducir animaciones detiene la aurora.

### Task 5: Avisos
**Spec:** §7b "Avisos". Ajustes `budget.alertsEnabled`, `budget.alertLow` (por defecto 80), `budget.alertHigh` (por defecto 100). Las alertas existentes leen estos valores.
- Tests: con umbral 70 la alerta sale al 70 %; desactivadas no sale ninguna.

### Task 6: Privacidad y datos
**Spec:** §7b "Privacidad y datos". `security.lockAfter` (0|1|5|15 min, lo usa el `AppLockController` de la Task 6 del plan 4); `privacy.hideAmounts` (bool; montos como `••••` hasta tocar el total; también en el widget); exportar a CSV (`;`, UTF-8 con BOM, compartir con `share_plus`); borrar todo (escribir "BORRAR", ofrecer backup antes); Acerca de (versión con `package_info_plus`, enlace al repo, `showLicensePage`).
- Tests: CSV con encabezado y una fila por movimiento con montos enteros; borrar exige "BORRAR" y deja la base con las categorías de fábrica; ocultar montos muestra `••••` y al tocar revela; el bloqueo respeta el tiempo elegido.

### Task 7: Pantalla de Ajustes por secciones
**Spec:** §7b completo. Reescribir `settings_screen.dart` con las cinco secciones de la maqueta (Tu dinero, Carga, Inicio y apariencia, Avisos, Privacidad y datos), cada fila con ícono, título, subtítulo con el valor actual y control en línea (interruptor/segmento) o acceso. Skills: `emil-design-eng`, `apple-design`.
- Tests: aparecen las cinco secciones y todas las filas; cambiar un segmento en línea guarda el ajuste.

### Task 8: Verificación en el A54 (orquestador)
Instalar, recorrer cada ajuste en el teléfono, medir `scroll_inicio` y `carga` (mediana de 3) para descartar regresiones, actualizar el README (sección de funciones) y commit.
