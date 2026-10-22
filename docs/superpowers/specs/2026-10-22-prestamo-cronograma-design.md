# Préstamo con cronograma de cuotas (cuota variable)

Fecha: 2026-10-22 · Estado: aprobado (boceto validado en el visual companion,
`.superpowers/brainstorm/102422-1792671419/content/prestamo-cronograma.html`).
Amplía §7c de `2026-10-08-nucleo-design.md`.

## Problema

Los préstamos de banco (ej. Itaú) tienen cuotas distintas cada mes (bajan con
el tiempo), pero el banco publica el cronograma completo: número, vencimiento y
monto de cada cuota. Pockt hoy solo guarda una cuota fija (`installmentAmount`),
así que el aviso y el pago precargado muestran un monto que no es el real.

## Decisiones

1. **Cronograma opcional por préstamo.** Tabla nueva `loan_installments`
   (`loanId`, `number`, `dueDate`, `amount`; PK `loanId+number`). Esquema v15.
   Préstamos sin cronograma se comportan exactamente como hoy.
2. **Datos derivados del cronograma** al guardar: `kind = installments`,
   `installmentsTotal = cantidad de cuotas`, `totalAmount = suma de montos`,
   `installmentAmount = null`, `dueDay = día de la primera cuota`.
3. **Carga por texto pegado.** En el editor, dentro de "En cuotas", un selector
   **Monto fijo / Cronograma**. Con Cronograma se pega una cuota por línea:
   `número fecha monto` (ej. `3 02/03/2027 705.000`). Acepta fechas con `/` o `-`,
   montos con puntos de miles y prefijo `Gs.` opcional, espacios extra y líneas
   vacías. Los números deben ser 1..N consecutivos. Las líneas que no se
   entienden se marcan en rojo y no se puede guardar hasta corregirlas.
   Debajo, un resumen: "Se leyeron N cuotas", total, "día D · mes año → mes año".
   Al editar un préstamo con cronograma, el campo se llena con el texto
   reconstruido; guardar reemplaza todas las filas del cronograma.
4. **Asignación de pagos a cuotas por orden.** El k-ésimo pago regular (no extra)
   corresponde a la cuota k. Los pagos extra bajan el saldo pero no avanzan la
   cuota (igual que hoy).
5. **Avance.** Saldo = total − pagado (igual que hoy). Próxima cuota =
   cronograma[cuotas pagadas]; su `dueDate` es el próximo vencimiento; fin
   estimado = `dueDate` de la última cuota; cuotas restantes = N − pagadas.
6. **Detalle del préstamo.** Tarjeta "Próxima cuota · k de N" con monto real,
   vencimiento y "en X días". Tarjeta "Cronograma": muestra 5 filas alrededor de
   la próxima (pagadas tachadas con check, próxima resaltada, futuras atenuadas)
   y "Ver las N" despliega la lista completa.
7. **Aviso.** Título "Vence la cuota k de N", cuerpo "<nombre> · Gs. X el
   <día dd/MM>". Fecha según `dueDate` de la próxima cuota y `reminderDays`,
   respetando horas de silencio como hoy.
8. **Registrar pago.** Monto precargado = monto de la próxima cuota; subtítulo
   "<nombre> · cuota k de N". El monto se puede cambiar y "pago extra" sigue
   igual.
9. **Borrado.** Borrar un préstamo borra su cronograma; `wipeAllData` también
   borra `loan_installments`. El backup cifra el archivo de la base completo, así
   que no necesita cambios.

## Fuera de alcance

Separar capital e interés; detectar el débito de la cuota desde SMS/correo;
importar el cronograma desde una captura dentro de la app.

## Pruebas

Parser (formatos válidos, errores por línea, números no consecutivos), migración
v14→v15, `calculateLoanProgress` con cronograma (próxima cuota, extras, cierre),
aviso con cronograma, precarga del pago, editor (pegar, resumen, error, editar y
reemplazar), detalle (tarjetas y "Ver las N"), borrado en cascada y wipe.
