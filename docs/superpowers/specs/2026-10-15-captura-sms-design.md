# Pockt — Motor de captura (SMS de Itaú), diseño

Decidido con el usuario el 2026-10-15. Complementa la spec núcleo (`2026-10-08-nucleo-design.md`), en especial §5 (bandeja de sugeridos), §7c (Préstamos) y §7e (saldo arrastrado).

## 1. Objetivo

Que los movimientos de la cuenta de Itaú lleguen solos a Pockt a partir de los avisos que el banco ya manda al teléfono, sin compartir claves, sin internet y sin tocar los sistemas del banco. Todo pasa por la bandeja **Por confirmar**.

**Por qué no "conexión con el banco" (estilo YNAB):** en Paraguay no hay open finance; Itaú no tiene API pública; los agregadores (Belvo, Prometeo) no confirman Itaú PY y piden compartir la clave, lo que viola la cláusula 2.28 del contrato de Itaú (no informar la contraseña a terceros) y el banco puede cerrar la cuenta sin motivo (4.5). Leer los avisos en el propio teléfono no tiene ese riesgo.

## 2. Alcance

- **v1 (esta spec):** SMS del remitente `4828` (Itaú Paraguay).
- **v2 (después, spec aparte):** correos de `info@itau.com.py` leídos desde la notificación de Gmail del teléfono (transferencias enviadas/recibidas, pagos de servicios). Antes hay que comprobar que la notificación expandida trae el monto.
- **Fuera de alcance por ahora:** compras con tarjeta de crédito Itaú (no hay SMS ni correo por compra; solo el resumen mensual en PDF cifrado); otros bancos; importar el historial anterior al 15/10/2026 (opcional a futuro).

## 3. Formatos de SMS (reales, con datos sanitizados)

Remitente `4828`. Fechas `dd/MM/yyyy HH:mm:ss` en hora local de Paraguay.

1. **Débito** (la gran mayoría):
   `Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****34.500 por PIZZA HUT-MULTIPLAZA al 14/10/2026 12:15:51`
   - Monto con cantidad variable de `*` de relleno antes de los dígitos y puntos de miles: `Gs.**1.200.500`, `Gs.******7.162`.
   - El texto entre `por ` y ` al dd/MM` es la **descripción**. Tipos:
     - Comercio: `PEDIDOS YA`, `PEDIDOS YA-FARMACIAS`, `FCIA PUNTO FARMA-P394`, `SHELL BAHIA ABASTO`, `BIGGIE-DE LA VICTORIA`, `TIENDA EJEMPLO-VPOS`.
     - Comercio con referencia numérica al final, a limpiar: `ANTHROPIC* CLAUDE SUB0001234567890` → `ANTHROPIC* CLAUDE`; `WL *STEAM PURCHASE   0001234567890` → `WL *STEAM PURCHASE`.
     - Pago de servicio: `Claro Pago de factura con CI`.
     - **Pago de tarjeta** de otra entidad: `Bancop Pago de tarjeta con cedula`, `FINANCIERA FIC Pago de tarjeta con` (cortado).
     - **Pago de préstamo**: `Banco Familiar Pago de Prestamos`.
     - Recarga: `Mas tarjeta Billetaje Mas - Carga`.
2. **Acreditación de sueldo:**
   `Itau le informa: Su empresa realizo una acreditacion en su cuenta XXXXXXXXX en Gs. al 15/10/2026 15:19:24.Puede verificar su saldo aqui: www.itau.com.py/itaupy`
   - **No trae monto.**
3. **Otros del 4828** (tarjeta de crédito, devoluciones, mora, alta de préstamo, encuestas, promos): se ignoran en v1.

## 4. Comportamiento

### 4.1 Lectura
- **En vivo:** receptor de `SMS_RECEIVED` (Android) que filtra remitente `4828`, parsea y guarda la sugerencia aunque la app esté cerrada; muestra la notificación local "Tenés 1 movimiento por confirmar" respetando los avisos existentes.
- **Al abrir la app:** relectura del buzón (`content://sms/inbox`, remitente `4828`) desde la fecha del último SMS procesado (o desde la fecha de activación, nunca antes del 15/10/2026 por defecto) para recuperar lo que llegó con el teléfono apagado o sin permiso.
- Permisos `RECEIVE_SMS` y `READ_SMS`, pedidos solo al activar la captura, con explicación previa. Si se niegan, la función queda apagada sin errores.
- **Play Store:** Google no permite `READ_SMS` a apps que no son de mensajería. Hoy Pockt se instala directo; si algún día se publica, la fuente pasa a notificaciones (fuera de alcance).

### 4.2 Parser
- Reglas (regex), sin IA. Función pura `parseItauSms(String body) → CaptureResult?` con tipos: `debit(amount, description, occurredAt)`, `salaryCredit(occurredAt)`, `ignored`.
- Monto: quitar `*` y puntos → entero en guaraníes.
- Descripción: limpiar referencias numéricas finales (≥ 8 dígitos) y espacios repetidos; quitar sufijos de canal tipo `-VPOS` solo para la clave de comercio, no para el texto mostrado.
- `occurredAt` = fecha y hora del SMS (más precisa que la de recepción).
- Un SMS que empieza con `Itau informa: Registramos un debito` y no matchea el patrón se guarda como **no reconocido** (contador visible en Ajustes) para detectar cambios de formato.

### 4.3 Clasificación
- **Comercio** → sugerencia de gasto, categoría de la libreta de comercios (`merchant_memory`, mismo motor que el texto natural); sin match, sin categoría y el usuario elige al confirmar.
- **Pago de servicio** (`Pago de factura`) → gasto; si hay una recurrente con monto igual o cercano (±10 %) en ±5 días, la sugerencia se asocia a esa regla y **reemplaza** la sugerencia de la recurrente (no se crean dos).
- **Pago de préstamo** (`Pago de Prestamos`) → pago de préstamo: si hay un préstamo activo cuya cuota coincide (±5 %), la sugerencia queda ligada a ese préstamo (`loanId`) y al confirmar registra el pago; si no, sugerencia de gasto en la categoría Préstamos.
- **Pago de tarjeta** (`Pago de tarjeta`) → movimiento de tipo **transferencia** que **no cuenta como gasto** (no entra en Gastado, presupuestos, reportes, calendario ni "quedan"), porque lo consumido ya se registró o se registrará como compra. Se muestra en Movimientos con estilo neutro, igual que los aportes a metas.
- **Acreditación de sueldo** → si hay una sugerencia de cobro pendiente del esquema (`incomeSchedule`) con fecha ±3 días, se **confirma sola** con su monto esperado y la hora del SMS; si no hay, se crea una sugerencia de ingreso en la categoría del sueldo con el monto esperado del período (o 0 si no hay esquema) para que el usuario complete.

### 4.4 Duplicados
- Clave de cada captura: `sms:<fecha-hora>:<monto>` → índice único (no se procesa dos veces el mismo SMS).
- Contra lo cargado a mano: si existe un movimiento del mismo tipo y monto exacto entre 2 horas antes y 2 horas después, la sugerencia se crea marcada **"posible duplicado"** con el movimiento existente a la vista y botones **Es el mismo** (descarta y une) / **Es otro** (confirma).
- Contra la v2 (correo): misma regla de monto + ventana.

### 4.5 Bandeja Por confirmar
- Las capturas aparecen con un ícono de mensaje (Phosphor `chat-text`) y el texto original plegado ("Ver mensaje").
- Confirmar con un toque; editar categoría/monto antes de confirmar; descartar.
- **Confirmar siempre este comercio** (opcional, por comercio): las próximas capturas de ese comercio se confirman solas con su categoría. Se gestiona en Ajustes → Captura.

### 4.6 Ajustes → Tu dinero → Captura automática
- Interruptor **Leer SMS de Itaú** (apagado por defecto) → pide permisos.
- Estado: último SMS leído, cantidad capturada este mes, cantidad no reconocida.
- Lista de comercios con confirmación automática (quitar).
- **Leer desde**: fecha (por defecto 15/10/2026).

## 5. Datos

- `suggested_transactions` ya tiene `source = capture`, `rawText`, `fingerprint`: se usan para guardar el SMS original y la clave de duplicado.
- Nueva columna `kind` en `transactions` y `suggested_transactions` o tipo `TxType.transfer` (decidir en el plan con migración y test) para los pagos de tarjeta.
- Tabla `capture_rules` (merchantKey, categoryId, autoConfirm) o reutilizar `merchant_memory` con columna `autoConfirm`.
- Ajustes nuevos: `capture.smsEnabled`, `capture.since`, `capture.lastSmsAt`.

## 6. Privacidad y seguridad

- Todo local; nada sale del teléfono. Los SMS no se guardan completos fuera de `rawText` de la sugerencia, que se borra al descartar.
- El número de cuenta del SMS nunca se guarda (se recorta del `rawText`).
- Fixtures de tests sanitizados: `****XXXX`, sin nombres reales.

## 7. Testing

- Parser: cada formato real de §3 (sanitizado), variantes de relleno `*`, descripciones con referencia numérica, texto cortado, SMS desconocidos.
- Clasificación: servicio ↔ recurrente, préstamo ↔ cuota, pago de tarjeta excluido de totales, sueldo confirma la sugerencia del esquema.
- Duplicados: mismo SMS dos veces; manual + captura; ventana de 2 horas.
- Receptor y relectura con un `SmsSource` falso (interfaz Dart) — el canal nativo se prueba a mano en el A54 con la Demo.
