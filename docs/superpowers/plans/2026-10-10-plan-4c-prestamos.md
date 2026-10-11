# Pockt — Plan 4c: Préstamos y cuotas

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** seguir lo que se debe, lo que se prestó y las compras en cuotas, con avance, saldo, fin estimado, registro de pagos y aviso de vencimiento.

**Spec:** `docs/superpowers/specs/2026-10-08-nucleo-design.md` §7c (y §7b para "Tarjetas del Inicio"). Maqueta aprobada el 2026-10-10.

**Orden:** después del plan 4b (Ajustes), que trae "Tarjetas del Inicio"; antes de la Task 7 del plan 4 (primer uso).

**Global Constraints:** las de los planes 1–4b. TDD en cada tarea (`flutter test --timeout 30s`, `flutter analyze` en 0); migración de Drift con test desde la versión anterior; montos enteros en guaraníes; estética "Profundidad y luz" con íconos Phosphor; no commitear ni usar el teléfono (lo hace el orquestador).

---

### Task 1: Modelo y avance
**Files:** `lib/core/db/tables.dart` (tabla `loans`, columna `loanId` nullable en `transactions`, categoría de fábrica "Préstamos"), migración; `lib/features/loans/data/loans_repository.dart` (crear, editar, cerrar, `watchActive(direction)`, `watchClosed()`, `watchPayments(loanId)`); `lib/features/loans/domain/loan_progress.dart` (funciones puras de §7c).
- Tests: migración conserva datos; pagado/saldo/cuotas con pagos regulares y un extra; fin estimado; saldo 0 cierra el préstamo; un pago `lent` es ingreso.

### Task 2: Pantalla Préstamos y detalle
**Files:** `lib/features/loans/ui/loans_screen.dart` (pestañas Debo / Presté / Terminados, tarjetas con barra, etiqueta de vencimiento), `loan_detail_screen.dart` (anillo, resumen, "Registrar pago", "Pago extra / adelanto", historial), `loan_editor.dart` (alta y edición; tipo, total o cuota × cantidad, día de vencimiento; en `lent`, opción de registrar la salida). Skills: `emil-design-eng`, `apple-design`.
- Tests: la lista separa por pestaña; registrar pago crea un gasto ligado con la cuota y actualiza el avance; un extra no suma cuota; el editor valida montos.

### Task 3: Integraciones
**Files:** `home_screen.dart` (tarjeta Préstamos, registrada en "Tarjetas del Inicio" del plan 4b), `settings_screen.dart` (acceso en Tu dinero), flujo de carga (al elegir "Préstamos", hoja para elegir el préstamo o ninguno).
- Tests: la tarjeta aparece solo con préstamos activos y muestra hasta 3 vencimientos; cargar en "Préstamos" y elegir uno lo liga.

### Task 4: Aviso de vencimiento
**Files:** `lib/features/loans/domain/loan_reminders.dart` (fechas de aviso N días antes del `dueDay`, sin aviso si la cuota del mes ya está pagada), programación con el servicio de notificaciones existente y la tarea diaria de segundo plano.
- Tests: aviso 2 días antes por defecto; no se programa si ya se pagó la cuota del mes; respeta el horario de silencio.

### Task 5: Verificación en el A54 (orquestador)
Instalar, crear un préstamo de cada tipo, registrar pagos y un extra, ver la tarjeta del Inicio y el aviso; medir `scroll_inicio` (mediana de 3); actualizar el README; commit.
