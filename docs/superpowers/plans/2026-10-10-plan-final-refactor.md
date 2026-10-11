# Pockt — Plan final: partición de pantallas y refactor

> **Estado:** en espera. Es el **último plan** del proyecto: se ejecuta después del plan 4 (backup, seguridad, primer uso), del motor de captura y de cualquier otro plan de funciones. Antes de empezarlo se vuelve a medir el tamaño de los archivos y se detalla cada tarea con `writing-plans` (pasos TDD, comandos exactos).

**Goal:** que el código sea fácil de mantener y de leer para la comunidad, **sin cambiar nada de lo que el usuario ve ni de cómo se comporta la app**. Cada tarea es un refactor puro: la suite completa pasa igual antes y después, y la medición de rendimiento por escenario no empeora.

**Contexto (2026-10-10):** los archivos escritos a mano más largos son pantallas que acumulan varias vistas y su lógica en un solo archivo:

| Archivo | Líneas |
|---|---|
| `lib/features/budgets/ui/budgets_screen.dart` | 1.699 |
| `lib/features/reports/ui/reports_screen.dart` | 1.478 |
| `lib/features/income/ui/income_schedule_screen.dart` | 934 |
| `lib/features/recurring/ui/recurring_screen.dart` | 884 |
| `lib/features/home/ui/home_screen.dart` | 752 |
| `lib/features/entry/ui/entry_flow.dart` | 748 |
| `lib/features/entry/ui/amount_keypad.dart` | 725 |

**Reglas para todo el plan:**
- Sin cambios visuales ni de comportamiento. Si un test necesita cambiar, es señal de que el refactor cambió algo: se revisa antes de seguir.
- Una pantalla por tarea, un commit por tarea (`chore:` o `refactor:`), con la suite en verde y `flutter analyze` en 0.
- Las tareas que tocan Inicio, carga o Reportes llevan medición antes/después en el A54 (variante `.perf`, mediana de 3 corridas) que corre el orquestador.
- Objetivo orientativo: ningún archivo de UI escrito a mano por encima de ~400 líneas.

---

### Task 1: Reportes, una vista por archivo
Partir `reports_screen.dart` en `reports/ui/views/` (Categorías, Evolución, Por comercio, Comparación) más el contenedor con el `PageView` y los widgets compartidos (`_StatPill`, encabezados) en su propio archivo.

### Task 2: Presupuestos por secciones
Partir `budgets_screen.dart` en la lista, la tarjeta de presupuesto, la hoja de edición y las alertas 80/100 %.

### Task 3: Esquema de cobros y recurrentes
Partir `income_schedule_screen.dart` (formulario, vista previa de fechas de cobro, reparto) y `recurring_screen.dart` (lista, editor, confirmación) en archivos por sección.

### Task 4: Inicio con providers en lugar de suscripciones manuales
`home_screen.dart` mantiene a mano unas 7 `StreamSubscription` con `setState` (totales, categorías, movimientos, sugerencias, esquema, cobros, presupuestos). Pasarlas a providers de Riverpod (`StreamProvider` por dato, derivados para "quedan", tinte del resplandor, etc.) y dejar la pantalla como composición de widgets. Medición de rendimiento obligatoria antes/después.

### Task 5: Flujo de carga
Separar en `entry_flow.dart` y `amount_keypad.dart` la lógica (armado del movimiento, texto natural, fecha/hora) de la UI, con la lógica en `domain/` y tests unitarios propios.

### Task 6: Limpieza general
- Revisar duplicados entre pantallas (encabezados, hojas, botones de vidrio) y moverlos a `core/design/widgets`.
- Revisar nombres, comentarios desactualizados e imports sin uso.
- Actualizar el README (sección de arquitectura) si cambió la estructura de carpetas.
