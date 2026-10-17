# Captura por correo (Gmail) — diseño

Fecha: 2026-10-17 · Estado: aprobado en conversación, pendiente de revisión escrita
Relacionado: `2026-10-15-captura-sms-design.md` (v1, SMS). Este documento es la v2 anunciada en su §2.

## 1. Objetivo

Registrar en Pockt las **transferencias enviadas y recibidas** y los **pagos de servicios** de Itaú, que solo llegan completos por correo (`info@itau.com.py`). El SMS 4828 no informa transferencias y la notificación de Gmail no trae el monto (la vista previa se corta antes de "Moneda y Monto"), así que se leen los correos completos con la API de Gmail, todo en el teléfono.

Éxito: una transferencia recibida de alguien conocido se registra sola; una enviada aparece en la bandeja lista para confirmar con un toque; ninguna operación queda duplicada con el SMS; "Podés gastar hoy" no se infla con devoluciones de préstamos ni con plata entre cuentas propias.

## 2. Alcance

- **Dentro:** "Aviso de transferencia enviada", "Aviso de transferencia recibida", "AVISO DE PAGO DE SERVICIOS" de `info@itau.com.py`.
- **Fuera:** otros bancos; resumen mensual de tarjeta (PDF cifrado); correos anteriores a la fecha que el usuario elige al conectar; publicar la app (es de uso personal, < 100 usuarios, sin verificación de Google).

## 3. Formatos (reales, sanitizados)

Los cuerpos llegan en HTML con una tabla de dos columnas "Campo: | Valor |". Tras pasarlos a texto plano:

**Transferencia enviada** — asunto `Aviso de transferencia enviada`
```
Nro. de operación: | 000000000000000 |
Fecha y hora de operación: | 10/10/2026 12:47 |
Cliente Pagador: | JUAN PEREZ |
Nro. de cuenta del pagador: | ****XXXX |
Moneda y Monto: | Gs. 15.000 |
Cliente Beneficiario: | PEDRO GOMEZ |
Nro. de cuenta del beneficiario: | ****XXXX |
Entidad beneficiaria: | BANCO EJEMPLO SAECA |
Concepto de la Transferencia: | |
Estado: | La transferencia ha sido acreditada a la entidad beneficiaria |
```

**Transferencia recibida** — asunto `Aviso de transferencia recibida`
```
Nro. de operación: | ABCDPYPA000000000000000000 |
Fecha y hora de operación: | 10/10/2026 12:47:20 |
Cliente Pagador: | MARIA LOPEZ |
Nro. de cuenta del pagador: | ****XXXX |
Entidad pagadora: | BANCO EJEMPLO S.A. |
Moneda y Monto: | PYG 30,000 |
Nro. de cuenta crédito: | ****XXXX |
Nro. comprobante: | 0000000 |
Concepto de la Transferencia: | /BNF/ |
Estado: | Transferencia acreditada en cuenta |
```

**Pago de servicios** — asunto `AVISO DE PAGO DE SERVICIOS`
```
Tipo de cuenta: | Ahorro a la Vista Guaraníes |
Nombre del cliente: | JUAN PEREZ |
Concepto del servicio | Claro - Pago de factura con CI |
Referencia del servicio: | 0000000 |
Monto del pago: | 95,000 |
Fecha y hora de operación: | 15/10/2026 |
Nro. de operación: | 0000000 |
```
Otros conceptos vistos: `Bancop - Pago de tarjeta con cédula` (monto `1,200,500`).

Notas: el separador de miles cambia según el tipo (`15.000`, `30,000`, `1,200,500`) y el prefijo también (`Gs.`, `PYG`, ninguno). El pago de servicios no trae hora. El resto de correos del remitente (promos, PIN, códigos, resumen de tarjeta) se ignora.

## 4. Comportamiento

### 4.1 Conexión
- Ajustes → Captura automática → interruptor **Leer correos de Itaú (Gmail)**, apagado por defecto.
- Al activarlo: pantalla que explica qué se lee (solo `info@itau.com.py`, solo lectura, todo en el teléfono) → ventana de Google (cuenta + aviso "app no verificada") → elegir **Leer desde** (por defecto 15/10/2026).
- Proyecto de Google Cloud `pockt-511921`: API de Gmail activada, permiso `gmail.readonly`, estado "En producción" sin verificar, cliente OAuth Android para `io.github.pacotez12.pockt` con la huella SHA-1 de la clave de firma. La app no lleva ningún ID ni secreto: Play Services la reconoce por paquete + firma. Si cambia la clave de firma hay que actualizar la huella en el cliente.

### 4.2 Puente nativo
`GmailCapture.kt` (MethodChannel), con dependencia `com.google.android.gms:play-services-auth`:
- `authorize()` → `AuthorizationClient.authorize` con `gmail.readonly`; si hace falta, lanza la ventana de Google desde la Activity. Devuelve conectado / cancelado.
- `fetchSince(epochMillis)` → pide token sin interacción (contexto de aplicación, sirve en segundo plano); `messages.list` con `q=from:info@itau.com.py after:<fecha>` (paginado) y `messages.get` (`format=full`) por cada id nuevo; devuelve `[{id, internalDate, subject, bodyText}]`, con el HTML ya pasado a texto plano. Si Google exige interacción, devuelve el error `needsReconnect` sin abrir nada.
- `disconnect()` → `revokeAccess` y limpia el token cacheado.
- Sin dependencias Dart nuevas. HTTP con `HttpURLConnection` en Kotlin.

Del lado Dart, interfaz `EmailSource` (`authorize`, `fetchSince`, `disconnect`) con `AndroidEmailSource` y `FakeEmailSource` para tests, igual que `SmsSource`.

### 4.3 Cuándo se lee
- Al abrir la app y en segundo plano cada 15 minutos (el `Workmanager` existente), solo con el interruptor prendido. Siempre desde el último correo procesado (`capture.emailLastAt`).
- Notificación local "Tenés N movimientos por confirmar" (respeta los avisos existentes) y "Ingreso registrado…" cuando una regla se aplica sola.
- `needsReconnect`: la lectura se pausa sin errores y se notifica "Volvé a conectar Gmail" (abre Ajustes).
- **Riesgo a verificar primero (Task 1 del plan):** que el token se obtenga sin interacción con la app cerrada. Si no se puede, la lectura en segundo plano se reemplaza por "al abrir la app" y se avisa al usuario antes de seguir.

### 4.4 Parser
- Reglas (regex), sin IA. Función pura `parseItauEmail(subject, bodyText, receivedAt) → EmailCapture` con tipos `transferOut`, `transferIn`, `servicePayment`, `ignored`, `unrecognized`.
- Campos: `operationId`, `amount` (entero en guaraníes: quitar `Gs.`, `PYG`, puntos y comas), `occurredAt` (fecha y hora del correo; si no trae hora, la de recepción), `counterparty` (beneficiario o pagador), `entity`, `concept`.
- Asunto conocido que no matchea → `unrecognized` (contador en Ajustes).
- **Nunca se guardan números de cuenta.** El `rawText` guardado es un resumen: tipo, persona, entidad, monto, fecha, concepto.

### 4.5 Clasificación
- **Transferencia recibida** (aprende por pagador):
  - Sin regla → bandeja con opciones **Ingreso** (categoría), **Me pagaron un préstamo** (préstamos `lent` activos) o **No contar**.
  - Al confirmar se guarda la regla del pagador. Con regla → se registra sola y se notifica. Si la regla apunta a un préstamo ya saldado → vuelve a la bandeja.
- **Transferencia enviada** (siempre a la bandeja): opciones **Gasto** (categoría), **Le presté a alguien** (crea un préstamo `lent` o suma a uno), **Pagué una deuda** (préstamo `owe` activo), **No contar**. Precargada con lo último elegido para ese destinatario; nunca se confirma sola.
- **Entre cuentas propias:** si la otra persona coincide con el titular (nombre normalizado igual al "Cliente Pagador" de las enviadas, guardado al conectar como `capture.emailOwnerName`), la opción precargada es **No contar**.
- **Pago de servicios:** mismas reglas que el SMS (§4.3 de la spec SMS): recurrente coincidente (±10 % y ±5 días) la reemplaza; `Pago de tarjeta` → gasto en **Tarjetas**; `Pago de Prestamos` → préstamo con cuota coincidente; resto → gasto con categoría de la libreta de comercios.
- **Efecto en los números:** "Me pagaron un préstamo" y "Pagué una deuda" solo mueven el préstamo (no son ingreso ni gasto); "Le presté a alguien" tampoco es gasto; "No contar" no registra movimiento. "Ingreso" y "Gasto" son movimientos normales.

### 4.6 Duplicados
- Clave única `email:<id de Gmail>` en `fingerprint`: un correo nunca se procesa dos veces.
- **Correo ↔ SMS** de la misma operación: si existe una captura SMS (sugerencia o movimiento) del mismo tipo, mismo monto y mismo día, el correo no crea nada; solo completa esa captura con `operationId` y concepto. Simétrico: el SMS que llega después de un correo hace lo mismo.
- **Correo ↔ carga manual:** mismo tipo y monto en ±2 horas (o el mismo día si el correo no trae hora) → sugerencia marcada **posible duplicado** con **Es el mismo** / **Es otro**, como en el SMS.

### 4.7 Bandeja
- Ícono `envelope-simple` (Phosphor) y "Ver mensaje" con el resumen recortado.
- Hoja de confirmación con las opciones de §4.5 según el tipo; los préstamos se eligen de la lista existente o se crea uno nuevo con la persona como nombre.

### 4.8 Ajustes → Tu dinero → Captura automática (sección Correo)
- Interruptor + cuenta conectada; **Leer desde**; estado (último correo leído, capturados este mes, no reconocidos).
- **Personas recordadas**: lista de reglas (persona, acción) con quitar.
- **Desconectar Gmail**: revoca el permiso y apaga la lectura; lo registrado queda.

## 5. Datos

- Migración a **v14**: tabla `counterparty_rules` (`id`, `nameKey` normalizado, `direction` in/out, `action` income/expense/loanRepayment/loanLent/loanPayment/ignore, `categoryId?`, `loanId?`, `autoApply`, `updatedAt`), índice único (`nameKey`, `direction`). Las enviadas guardan la última elección con `autoApply = false` (solo precarga).
- `suggested_transactions`: se reutilizan `source = capture`, `rawText`, `fingerprint`; columna nueva `captureMeta` (JSON corto: canal sms/email, tipo, persona, `operationId`) para la hoja de confirmación y la unión SMS↔correo.
- Ajustes nuevos: `capture.emailEnabled`, `capture.emailSince`, `capture.emailLastAt`, `capture.emailOwnerName`, `capture.emailUnrecognized`.

## 6. Privacidad y seguridad

- Solo `gmail.readonly` y solo `from:info@itau.com.py`; los correos van de Google al teléfono, sin servidores intermedios.
- Pockt no guarda tokens (los maneja Play Services). No se guardan números de cuenta ni cuerpos completos; el resumen se borra al descartar.
- Repo público: fixtures inventados (nombres genéricos, `****XXXX`, números de operación en cero). Ningún dato real en tests, specs ni commits.

## 7. Testing

- **Parser:** los 3 formatos; montos `15.000` / `30,000` / `1,200,500` con y sin prefijo; pago de servicio sin hora; asunto desconocido → `ignored`; asunto conocido roto → `unrecognized`; ningún número de cuenta en el resultado.
- **Clasificación:** recibida sin regla → bandeja; con regla → se aplica sola; regla con préstamo saldado → bandeja; titular → precarga "No contar"; enviada siempre a bandeja con precarga; servicio ↔ recurrente / tarjeta / préstamo.
- **Duplicados:** mismo correo dos veces; correo→SMS y SMS→correo; correo + carga manual (con y sin hora).
- **Lectura:** con `FakeEmailSource`: relectura desde fecha, avance de `emailLastAt`, `needsReconnect` pausa y notifica, desconectar.
- **Migración v14:** tests de migración con `greaterThanOrEqualTo` como el resto.
- **A54:** el puente Kotlin se prueba a mano (primero la prueba de segundo plano de §4.3), con la variante Demo y luego en la real con el interruptor que activa el usuario.
