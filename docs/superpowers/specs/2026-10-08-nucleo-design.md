# Pockt — Diseño del núcleo (v1)

Fecha: 2026-10-08 · Estado: aprobado en conversación, pendiente de revisión escrita

## 1. Contexto y objetivo

**Pockt** es una app personal para registrar gastos e ingresos, de uso exclusivo del autor, instalada directo (sin Play Store) en un Samsung A54 (Android, AMOLED 120 Hz, Exynos 1380).

Requisito central: **que sea lo más atractiva visualmente posible**. Sistema visual propio, motion con física, haptics y fluidez verificada con mediciones en el teléfono real.

El proyecto se divide en dos subproyectos, cada uno con su propio diseño, plan e implementación:

1. **Núcleo** (este documento): carga manual, categorías, ingresos, presupuestos, recurrentes, reportes, calendario de calor, recordatorios, backup, apariencia.
2. **Motor de captura** (diseño posterior, a partir de ejemplos reales de mensajes): lectura de notificaciones de apps bancarias, SMS y correos; interpretación; deduplicación; envío a la bandeja de sugeridos. El núcleo deja preparada la bandeja y los campos que el motor va a necesitar (§4).

## 2. Decisiones de base

| Tema | Decisión |
|---|---|
| Plataforma | Flutter, Android (A54) |
| Estado | Riverpod (con `riverpod_generator`) |
| Persistencia | Drift sobre SQLite, local-first |
| Moneda | Solo PYG en v1; montos `int` sin decimales; campo `currency` presente para sumar USD más adelante |
| Backup | Google Drive, carpeta visible "Gastos · Backups" creada por la app, cifrado en el teléfono |
| Periodo | Totales y presupuestos mensuales, con la quincena de cobro visible |
| Apariencia | Sistema (por defecto) / Claro / Oscuro |
| Servidor propio | Ninguno |

## 3. Arquitectura

Estructura por funcionalidad:

```
lib/
  core/
    design/      tokens de color (claro y oscuro), tipografía, radios, springs, haptics
    db/          base Drift, tablas, migraciones
    format/      formato de guaraníes
    time/        zona horaria del teléfono (respaldo America/Asuncion), rangos de día y mes
  features/
    entry/       carga: grilla de categorías → teclado; texto natural
    home/        inicio: total, resplandor, quincena, calendario de calor, últimos movimientos
    transactions/ historial, búsqueda, filtros, edición, borrado con deshacer
    budgets/     presupuestos mensuales y alertas 80/100 %
    recurring/   reglas recurrentes y bandeja de sugeridos
    income/      esquema de cobro (quincenal/mensual) e ingresos sugeridos
    reports/     cuatro reportes
    reminders/   recordatorios por intensidad
    backup/      backup cifrado y restauración
    settings/    ajustes, bloqueo con huella, apariencia
    onboarding/  primer uso
```

Capas dentro de cada funcionalidad:

- **Datos**: tablas y repositorios Drift. Única capa que toca SQLite.
- **Lógica**: providers Riverpod que exponen streams reactivos (un cambio en `transactions` recalcula totales, anillos y reportes sin código extra).
- **UI**: widgets que muestran y animan. Sin lógica de negocio.

Reglas:

- `core/design/` es la única fuente de colores, tipografía, radios, curvas y duraciones.
- Las funcionalidades no se importan entre sí. Se comunican solo a través de la base de datos y de providers de `core`.
- `entry/` queda aislado a propósito: el flujo de carga (categoría primero) puede reemplazarse sin tocar el resto.
- Fechas: se guardan en UTC y se muestran en la zona horaria del teléfono (`flutter_timezone`); si no se puede leer, `America/Asuncion`.

## 4. Modelo de datos

Todas las claves primarias son UUID (texto), salvo `settings`.

**`categories`**: `id`, `name`, `icon` (clave de ícono Phosphor, por ejemplo `fork-knife`), `colorDark`, `colorLight`, `kind` (`expense` | `income`), `sortOrder`, `archived`.
- Una categoría con movimientos no se borra: se archiva.
- Set inicial de gastos: Comida, Transporte, Hogar, Salud, Ocio, Servicios, Educación, Regalos, Ropa, Otros. Ingresos: Sueldo, Extra, Otros ingresos. Todo editable (renombrar, crear, reordenar, archivar).

**`transactions`**: `id`, `type` (`expense` | `income`), `amount` (int), `currency` (`PYG`), `categoryId`, `merchant?`, `note?`, `occurredAt`, `createdAt`, `updatedAt`, `source` (`manual` | `recurring` | `income_schedule` | `capture`), `recurringRuleId?`, `suggestionId?`, `deletedAt?`.
- Borrado suave: se marca `deletedAt` y se muestra "Deshacer". Una limpieza periódica elimina los borrados de más de 30 días.

**`suggested_transactions`**: `id`, `type`, `amount`, `currency`, `categoryId?`, `merchant?`, `occurredAt`, `source` (`recurring` | `income_schedule` | `capture`), `sourceRef?` (id de la regla o del esquema), `status` (`pending` | `confirmed` | `dismissed`), `transactionId?`, `rawText?`, `fingerprint?`, `createdAt`.
- `rawText` y `fingerprint` quedan reservados para el motor de captura y no se usan en v1.

**`recurring_rules`**: `id`, `name`, `type`, `amount`, `categoryId`, `frequency` (`monthly` | `weekly` | `yearly`), `dayOfMonth?`, `dayOfWeek?`, `monthOfYear?`, `nextDueDate`, `active`.

**`income_schedules`**: `id`, `mode` (`biweekly` | `monthly`), `payDays` (lista, por ejemplo `[15, -1]`, donde `-1` = último día del mes), `shiftToPreviousBusinessDay` (bool), `expectedAmount?`, `categoryId`, `effectiveFrom`.
- Cambiar de esquema crea una fila nueva con su `effectiveFrom`. Las anteriores no se editan, así los meses pasados se interpretan con el esquema que regía.

**`budgets`**: `id`, `categoryId`, `monthlyLimit` (int), `alert80SentFor?` (`YYYY-MM`), `alert100SentFor?` (`YYYY-MM`).

**`day_marks`**: `date` (clave, fecha local), `noSpend` (bool). Lo usan los recordatorios.

**`settings`**: clave-valor (apariencia, intensidad y horarios de recordatorios, horas de silencio, bloqueo, nombre de la carpeta de backup, fecha del último backup exitoso).

Reglas:
- Los totales se calculan siempre con consultas; nunca se guardan sumas.
- Presupuestos solo mensuales en v1.

## 5. Pantallas y comportamiento

### 5.1 Navegación
Barra flotante de vidrio: Inicio · Movimientos · **＋** · Presupuestos · Reportes. Ajustes se abre desde un ícono en el Inicio.

### 5.2 Inicio
De arriba a abajo:
1. Selector de mes e ícono de ajustes.
2. Total gastado del mes, grande, con el **resplandor** detrás. Su color sale de la categoría con más gasto del mes y cambia con una transición lenta.
3. Barra segmentada por categoría.
4. Línea de quincena: "2ª quincena · quedan Gs. X · cobrás en N días". "Quedan" = ingresos registrados del mes − gastos del mes. Los días se cuentan hasta el próximo día de cobro según el `income_schedule` vigente.
5. Tarjeta "N por confirmar" cuando hay sugeridos pendientes. Abre la bandeja.
6. **Calendario de calor del mes** ("Tus días"): grilla lunes→domingo con un cuadro por día.
   - Intensidad en 5 niveles: nivel 0 = sin gasto. Los días con gasto se reparten en 4 niveles por cuartiles del gasto diario **de ese mes**.
   - Hoy lleva borde; los días futuros van punteados.
   - Al tocar un día se abre su **detalle** (hoja): total del día, comparación con el día promedio del mes ("3,4× tu día promedio"), barras "En qué se fue" por categoría y lista de movimientos del día.
   - Deslizar horizontalmente cambia de mes.
7. Últimos movimientos. Deslizar un movimiento permite editarlo o borrarlo (con deshacer).

### 5.3 Carga (＋)
1. Grilla de burbujas de categorías (gasto por defecto; un interruptor arriba cambia a Ingreso).
2. Al tocar una burbuja, crece y se transforma en el teclado numérico con el color de esa categoría (transición compartida).
3. Teclado: dígitos, `000` y borrar. Separador de miles automático. Haptic leve por tecla.
4. Fecha (hoy por defecto), nota y comercio son opcionales, a un toque.
5. Guardar: haptic medio, la hoja se cierra y el total del Inicio cuenta animado hasta el nuevo valor.
6. **Texto natural**: campo arriba de la grilla. Interpreta `"café 15000"`, `"super 230 mil ayer"`, `"bolt 28.500"`.
   - Reglas locales, sin red: extrae el monto (con `mil`, puntos de miles, `k`), la fecha relativa (`hoy`, `ayer`, `anteayer`, día de la semana) y la categoría por palabras clave editables, más el historial de comercios.
   - Siempre muestra la propuesta para confirmar; nunca guarda directo.

Si la escritura falla, la hoja no se cierra, se muestra el error y el monto queda cargado.

### 5.4 Movimientos
Lista agrupada por día, con búsqueda por texto (nota, comercio) y filtros por categoría, tipo y rango de fechas.

### 5.5 Presupuestos
Un anillo por categoría con tope. Cambia de color al 80 % y al 100 %. Al tocarlo se ven sus movimientos del mes y se edita el tope.
- Notificación al cruzar el 80 % y el 100 %, una sola vez por mes y categoría (`alert80SentFor`, `alert100SentFor`).

### 5.6 Reportes
Cuatro vistas deslizables:
1. **Mes por categoría**: anillo/barras; al tocar una categoría se ven sus movimientos.
2. **Evolución**: gasto, ingreso y ahorro de los últimos 6–12 meses.
3. **Comparación con el mes anterior**: a la misma altura del mes (del día 1 al día de hoy en ambos meses, recortado al último día si el mes anterior es más corto).
4. **Por comercio**: ranking por `merchant` (cobra valor sobre todo cuando exista el motor de captura).

### 5.7 Bandeja de sugeridos
Lista de `suggested_transactions` pendientes. Cada una se confirma (crea la transacción), se edita antes de confirmar o se descarta.
- **Recurrentes**: en `nextDueDate` se crea la sugerencia, se notifica y la regla avanza a la próxima fecha.
- **Esquema de cobro**: el día de cobro se sugiere el ingreso ("¿Cobraste la quincena?"), prellenado con `expectedAmount` si existe.

### 5.8 Recordatorios
Solo avisan si ese día no hay ningún gasto registrado y no está marcado "Hoy no gasté nada".

| Intensidad | Comportamiento |
|---|---|
| Apagado | Ninguno |
| Suave | 21:00 |
| Normal | 13:00 y 21:00 |
| Insistente | Cada 3 h desde las 12:00, máximo 4 por día |

- Horarios configurables y horas de silencio (por defecto 23:00–09:00).
- Acciones de la notificación: **Anotar** (abre la grilla de categorías) y **Hoy no gasté nada** (crea el `day_mark`).
- Implementación: se programan los recordatorios de los próximos 7 días. Al registrar un gasto o marcar "no gasté", se cancelan los del día. Al abrir la app, se reprograman.

### 5.9 Widget y acceso rápido
- **Widget de pantalla de inicio** (`home_widget`): las 4 categorías más usadas. Tocar una abre la carga directo en el teclado de esa categoría.
- **Tile de ajustes rápidos** (TileService nativo en Kotlin): abre la grilla de categorías.

### 5.10 Ajustes
Categorías · Esquema de cobro · Recurrentes · Presupuestos · Recordatorios (intensidad, horarios, silencio) · Apariencia (Sistema/Claro/Oscuro) · Bloqueo con huella · Backup (carpeta, último backup, respaldar ahora, restaurar, cambiar contraseña de respaldo).

### 5.11 Primer uso
Tres pasos, todos salteables: esquema de cobro → presupuestos → conectar Google Drive y elegir la contraseña de respaldo.

## 6. Sistema visual y motion

### 6.1 Identidad: "Profundidad y luz"
- **Oscuro**: fondo `#000` puro. Vidrio = blanco 7 % de opacidad con borde 9 %. El resplandor es luz de color detrás del total.
- **Claro**: no es una inversión del oscuro. El resplandor se vuelve un tinte pastel de la categoría; el vidrio es blanco esmerilado con sombras suaves.
- Cada categoría tiene `colorDark` (vivo) y `colorLight` (más oscuro, legible sobre blanco).
- El calendario va de gris tenue a naranja intenso en claro, y de casi negro a degradado naranja→rosa en oscuro.
- Texto en 3 niveles por opacidad (100 / 60 / 45 %).
- Acento de marca: degradado naranja→rosa (botón ＋).
- El cambio entre claro y oscuro funde los colores con una transición, sin salto.

### 6.1b Iconografía
- Librería: **Phosphor** (`phosphor_flutter`). Nada de emojis en la interfaz.
- Categorías: estilo **duotone** sobre la burbuja de color. Pestaña activa: estilo **fill**; inactivas y UI general: **regular**.
- Un registro central (`lib/core/design/icons.dart`) traduce la clave guardada en la base al ícono. Es el único archivo que conoce la librería.
- Al crear o editar una categoría se elige de un set curado de íconos, no de la librería completa.

### 6.2 Tipografía
Inter (incluida en la app) con cifras tabulares. Montos grandes con letter-spacing negativo; "Gs." chico y atenuado. Separador de miles con punto (`4.212.000`).

### 6.3 Motion
- Interacciones con springs: uno **firme** (sin rebote, respuestas al toque) y uno **suave** (rebote mínimo, hojas y transiciones). Todas interrumpibles desde el estado actual.
- Transiciones compartidas: burbuja → teclado, celda del calendario → detalle del día, ＋ → grilla.
- Presión: escala 0,96 con retorno por spring.
- Montos que cambian cuentan animados.
- Con "reducir animaciones" de Android activo, todo pasa a fundidos simples.

### 6.4 Haptics
Leve por tecla, medio al guardar, patrón distinto al cruzar 80 % y 100 % de un presupuesto, tic al cambiar de mes.

### 6.5 Rendimiento (A54)
- Resplandor: degradado radial pintado, sin desenfoque en tiempo real.
- `BackdropFilter` solo en la barra de navegación y en las hojas. Tarjetas en reposo con vidrio sin desenfoque.
- **Meta**: 120 fps; ningún frame por encima de 8 ms (build + raster) durante las transiciones principales, medido con `integration_test` + `traceAction` en modo profile en el dispositivo (`dumpsys gfxinfo` no ve los frames de Flutter) (carga, detalle del día, cambio de mes, cambio de pestaña).

## 6.6 Marca

- Nombre: **Pockt** (así, sin la "e").
- Ícono: concepto "orbe con abertura". Orbe con degradado radial (`#ffb07a` → `#ff6a52` → `#e8306f`), resplandor naranja→rosa alrededor y una curva de abertura de bolsillo en negro. Fuente maestra: `docs/brand/pockt-icon.svg` (lienzo 108×108 de ícono adaptativo; las formas clave dentro de la zona segura central de 66×66).
- Variantes a generar desde el SVG maestro: ícono adaptativo (capa frontal: orbe y abertura; capa de fondo: negro con resplandor), ícono monocromo para íconos temáticos de Android 13+, splash screen (Android 12+ `windowSplashScreenAnimatedIcon`), PNG por densidad.
- Validación: instalar en el A54 y revisar el ícono en la pantalla de inicio real, en fondos claro y oscuro y con íconos temáticos.

## 7. Backup, restauración y seguridad

### 7.1 Backup
- Login con Google (`google_sign_in`) con el scope mínimo `drive.file`. Proyecto de Google Cloud en modo "en pruebas" con el autor como único usuario de prueba.
- La app crea la carpeta visible **"Gastos · Backups"** en el primer backup. Si se borra a mano, la recrea en el siguiente.
- Proceso: `VACUUM INTO` (copia consistente) → compresión → cifrado → subida.
- **Automático** cada 2 días (día de por medio), solo con WiFi (`workmanager` con restricción de red), y después de confirmar una tanda de sugeridos.
- Se conservan las últimas 7 copias (unas dos semanas de historia).
- "Respaldar ahora" manual; la fecha del último backup exitoso queda visible.

### 7.2 Cifrado
- AES-256-GCM. Clave derivada con Argon2id de una **contraseña de respaldo** elegida en el primer uso.
- La contraseña no se guarda en ningún lado. La clave derivada se guarda en Android Keystore (`flutter_secure_storage`) para el uso diario.
- Advertencia explícita al elegirla: sin la contraseña, el backup no se puede recuperar.

### 7.3 Restauración
Conectar Google → la app lista los backups de la carpeta → contraseña → se muestra el resumen ("Backup del 24/10 · 1.243 movimientos") → se confirma. Antes de reemplazar, se guarda una copia local de los datos actuales para poder volver atrás si algo falla.

### 7.4 Seguridad local
- Bloqueo con huella (o PIN del teléfono) opcional, desactivado por defecto (`local_auth`). Se pide al abrir y al volver después de 1 minuto en segundo plano.
- Con el bloqueo activo, `FLAG_SECURE` oculta la app en la vista de recientes.
- Sin analíticas, sin publicidad, sin servidor. Los datos solo salen del teléfono hacia el Drive del autor, cifrados.

## 8. Manejo de errores

- Nada falla en silencio: todo error de escritura, backup o permisos se muestra en la UI.
- Guardar un movimiento: ver §5.3.
- Backup: reintento automático en la próxima ventana con WiFi. Si pasan 5 días sin backup exitoso (dos ciclos fallidos), aviso visible en el Inicio.
- Restauración: copia local previa y vuelta atrás si falla.
- Permiso de notificaciones denegado: Ajustes muestra el estado con un botón para activarlo.
- Migraciones Drift: cada cambio de esquema lleva su migración y su test.

## 9. Testing

Los tests se escriben antes de la implementación (TDD), con prioridad en fechas y montos.

- **Unitarios**: presupuestos y alertas 80/100 %; días de cobro quincenal y mensual (fin de mes, febrero, corrimiento a día hábil); generación de recurrentes; cuartiles del calendario de calor; lógica de recordatorios (cuándo sí, cuándo no, horas de silencio, "no gasté"); parser de texto natural; formato de guaraníes; comparación "a la misma altura del mes".
- **Base de datos**: consultas de totales y reportes sobre SQLite en memoria; tests de migraciones.
- **Widgets**: flujo de carga completo; bandeja de sugeridos; detalle del día.
- **Integración en el A54**: cargar, editar, borrar con deshacer, backup y restauración completos.
- **Rendimiento**: `integration_test` + `traceAction` en modo profile sobre las transiciones de §6.5.

## 10. Fuera de alcance de v1

- Motor de captura (notificaciones, SMS, correo): subproyecto 2.
- Otras monedas y conversión.
- Presupuestos no mensuales.
- Subcategorías y etiquetas.
- Sincronización entre dispositivos y versión web.
- Exportación a CSV/Excel.

## 10b. Pendientes para la comunidad

- Otras monedas (el campo `currency` ya existe) e idiomas (pasar los textos a archivos de traducción). Hoy la app asume guaraníes y español.

## 11. Paquetes previstos

`drift`, `drift_flutter`, `flutter_riverpod`, `riverpod_generator`, `flutter_local_notifications`, `timezone`, `workmanager`, `home_widget`, `local_auth`, `google_sign_in`, `googleapis`, `cryptography`, `flutter_secure_storage`, `intl`, `uuid`, `flutter_timezone`, `phosphor_flutter`. Versiones a fijar en el plan, verificando la última estable de cada uno.
