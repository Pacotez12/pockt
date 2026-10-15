# Plan 5a.2 — Aportes a metas en Movimientos

Spec: §7d, "Aportes en Movimientos" (2026-10-15).

**Restricciones globales:** TDD (test que falla primero), `flutter test --timeout 30s`, sin `dart format` de carpetas enteras, íconos Phosphor (sin emojis), colores del sistema §6.2b (neutros, nada de estados ni marca en estas filas), no tocar archivos ajenos a la tarea.

## Tarea 1 — Fila de aporte en Movimientos e Inicio

- Archivos: `lib/features/transactions/ui/transactions_screen.dart`, `lib/features/transactions/ui/tx_row.dart` (o un widget hermano `GoalContributionRow`), `lib/features/home/ui/home_screen.dart` (Últimos movimientos), `lib/features/goals/data/goals_repository.dart` (stream de aportes con su meta, por rango de fechas).
- Mezclar aportes/retiros con los movimientos por fecha, agrupados en el mismo día. Título "Aporte · {meta}" o "Retiro · {meta}", ícono de la meta en círculo neutro, monto en color de texto secundario.
- Tocar abre `GoalDetailScreen`. Sin swipe de borrar (se borra desde la meta).
- Respetar los filtros: si hay filtro de categoría, tipo o búsqueda que no aplica, los aportes no se muestran; la búsqueda por texto sí matchea el nombre de la meta.
- Respetar "Ocultar montos".
- No sumarlos a totales, presupuestos, reportes, calendario ni CSV.
- Tests: aparece la fila tras aportar; no cambia el total del mes; retiro muestra "Retiro"; filtro por categoría la oculta; tocar navega al detalle.
