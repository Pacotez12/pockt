# Pockt web, etapa 4: Movimientos completo

> **Para quien implementa:** TDD (Vitest) en la lógica y en los componentes.
> No commitear: el orquestador revisa y commitea. Reporte final corto. Ningún
> dato real en tests ni capturas. No iniciar sesión con la cuenta del usuario.

**Objetivo:** en la web, Movimientos pasa de lista de solo lectura a la
pantalla completa: búsqueda, filtros, totales del período, cargar / editar /
borrar en un panel lateral y descargas CSV y Excel. Todo cambio se escribe en
la base local de PowerSync y sube solo; aparece en el teléfono en segundos.

**Spec:** `docs/superpowers/specs/2026-10-29-pockt-web-design.md` (secciones 2,
7, 8 y etapa 4). **Bocetos aprobados:**
`.superpowers/brainstorm/171364-1793283290/content/web-pantallas.html`
(sección "2 · Movimientos + panel de edición") y el movimiento de
`.superpowers/brainstorm/87432-1794075636/content/propuesta-2-3-fondo-y-movimiento.html`
(panel con spring, montos con `CountUp`). Reusar los componentes de la etapa 3
(`CountUp`, `Skeleton`, `TopNav`, tokens).

## Restricciones globales

- Las del plan 13 (tokens, prohibiciones, accesibilidad, reducir movimiento).
- **Mismo formato que la app** (`lib/core/db/tables.dart`,
  `lib/features/transactions/data/transactions_repository.dart`):
  - `id`: UUID v4 (`crypto.randomUUID()`).
  - `type`: `expense` | `income` | `transfer`. `amount`: entero positivo en
    guaraníes (sin decimales). `currency`: `'PYG'`.
  - Fechas (`occurred_at`, `created_at`, `updated_at`, `deleted_at`): entero,
    **segundos** Unix (igual que lo que guarda Drift).
  - `source`: `'manual'` para lo cargado en la web. `is_extra`: `0`.
  - Borrar = **borrado lógico**: `deleted_at = updated_at = ahora`. Nunca
    `DELETE`. Todas las consultas filtran `deleted_at IS NULL`.
  - Editar actualiza `updated_at`.
- Movimientos ligados a un préstamo (`loan_id` no nulo): se muestran con una
  etiqueta "Préstamo" y **no se editan ni borran en la web** (el panel dice
  "Editalo desde la app, afecta al préstamo"). Fuera de la v1.
- Categorías: solo las de `kind` coherente con el tipo (gasto o ingreso),
  sin archivadas, en su `sort_order`; transferencias usan la categoría que
  la app use para transferencias (mirar la app; si no hay regla, dejar elegir
  entre todas).
- CSV igual al de la app (`lib/features/settings/domain/export_csv.dart`):
  BOM UTF-8, separador `;`, columnas `Fecha;Tipo;Monto;Categoría;Nota;Comercio`
  y la misma protección contra fórmulas (`=+-@` al inicio). Excel con
  `exceljs` (MIT), misma tabla con montos como número y formato de miles.
  Solo se descarga lo filtrado. Nombre `pockt-movimientos-AAAA-MM-DD.csv/xlsx`.

## Foco de revisión

1. Un movimiento creado en la web tiene exactamente las columnas y tipos que
   espera la app (si no, la app falla al leerlo: pasó con los valores por
   defecto en la etapa 2).
2. Borrar no borra la fila: pone `deleted_at`.
3. Movimientos de préstamos no se pueden editar ni borrar.
4. Montos: solo enteros positivos, separador de miles al escribir, sin
   decimales; error claro si queda vacío o en 0.
5. CSV abre bien en Excel con tildes y `;`.

---

### Tarea 4.1: consultas y lógica (sin UI)

**Archivos:** `web/src/lib/movements/query.ts`, `web/src/lib/movements/write.ts`,
`web/src/lib/movements/export.ts`, tests al lado.

- [ ] `buildMovementsQuery(filters)` → SQL + parámetros sobre `transactions`
  con `deleted_at IS NULL`, join a `categories`; filtros: rango de fechas
  (por defecto el mes calendario actual), categorías, tipo, monto mín/máx,
  origen (`manual`, `recurring`, `incomeSchedule`, `capture`) y texto (en
  comercio y nota, sin distinguir mayúsculas ni tildes). Orden por
  `occurred_at` desc. Test por cada filtro.
- [ ] `periodTotals(rows)` → `{ count, spent, earned }` (transferencias no
  suman). Test.
- [ ] `createMovement`, `updateMovement`, `softDeleteMovement` sobre la base
  PowerSync con el formato de arriba. Tests con una base PowerSync en memoria
  o un doble del `execute`: columnas, tipos, segundos, `deleted_at`.
- [ ] `toCsv(rows)` y `toXlsx(rows)`. Test de CSV: BOM, encabezado, `;`,
  comillas y protección de fórmulas iguales a la app (copiar casos del test
  Dart de export_csv si existe).

### Tarea 4.2: pantalla de Movimientos

**Archivos:** `web/src/routes/movimientos.tsx`, componentes en
`web/src/components/movements/`.

- [ ] Encabezado según el boceto: título, resumen "N movimientos · salieron
  Gs. X · entraron Gs. Y" (con `CountUp`), botón "Descargar" (CSV / Excel).
- [ ] Barra de búsqueda y filtros (chips con popover: Período, Categoría,
  Tipo, Monto, Origen; "Limpiar"). Los filtros viven en la URL (se puede
  recargar o compartir el link).
- [ ] Tabla en vivo (`useQuery`): fecha, comercio o nota, categoría con su
  color, origen (ícono), monto con signo y color. Agrupada por día con el
  total del día. Skeleton del mismo tamaño mientras carga. Estado vacío con
  salida ("Cargá el primero"). Fila con foco y teclado (Enter abre).
- [ ] Más de 200 filas: virtualizar o paginar (elegir lo más chico).

### Tarea 4.3: panel de carga y edición

**Archivos:** `web/src/components/movements/MovementPanel.tsx`.

- [ ] Panel lateral debajo de la barra (boceto), entra con spring de Motion;
  se abre con "Cargar" de la `TopNav` (habilitarlo), con `N` en el teclado y
  al tocar una fila. Esc o "Cancelar" cierra; si hay cambios sin guardar,
  pregunta.
- [ ] Campos (reglas de inputs de la spec): Tipo (segmentado Gasto / Ingreso
  / Transferencia), Monto (separador de miles al escribir, ayuda "Sin
  decimales, ej. 45.000"), Fecha y hora (por defecto ahora), Categoría,
  Comercio (opcional), Nota (opcional). Validación con mensaje abajo en rojo
  con ícono.
- [ ] Guardar (spinner chico) → escribe, cierra el panel, la fila aparece
  arriba con un resalte breve. Editar precarga. Borrar con confirmación
  ("Se borra también del teléfono") y opción "Deshacer" 5 s en un aviso.
- [ ] Movimiento de préstamo: panel en solo lectura con el aviso.
- [ ] Error al subir (rechazado por el servidor): marca en la fila con
  "Reintentar" / "Descartar" (spec §8). Si PowerSync no expone el error por
  fila, mostrar el aviso general en `SyncStatus` y anotarlo en el reporte.

## Verificación final (orquestador)

`npm test` y `npm run build` en verde; en el navegador con la cuenta del
usuario: crear, editar y borrar un movimiento de prueba en la web y verlo
reflejado en el teléfono (y al revés); descargar CSV y abrirlo. Después:
auditoría rápida de seguridad de la etapa 4.
