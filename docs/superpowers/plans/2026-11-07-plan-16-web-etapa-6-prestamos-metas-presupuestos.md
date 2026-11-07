# Pockt web, etapa 6: Préstamos, Metas y Presupuestos (solo lectura)

> **Para quien implementa:** TDD. No commitear. Reporte final corto. Datos
> inventados en tests. No iniciar sesión con la cuenta del usuario.

**Objetivo:** las tres secciones que faltan en la barra de la web, solo para
ver (editar queda en la app), más una red de seguridad para que un error en
una pantalla no deje la web en negro.

**Spec:** `docs/superpowers/specs/2026-10-29-pockt-web-design.md` (secciones 2,
7, 8 y etapa 6). **Bocetos aprobados:**
`.superpowers/brainstorm/171364-1793283290/content/web-pantallas-2.html`
(Préstamo con migas y cronograma, Metas y Presupuestos) y el movimiento de
`.superpowers/brainstorm/87432-1794075636/content/propuesta-2-3-fondo-y-movimiento.html`.

## Restricciones globales

- Las de los planes 13 a 15. Solo lectura: ningún INSERT/UPDATE/DELETE en estas
  pantallas. Los números salen de `web/src/lib/calc/` (golden cases de la etapa
  5): `loan_progress`, `goal_progress`, `budget_status`. Si falta un cálculo,
  se agrega con su golden case en Dart y TS, sin tocar `lib/`.
- Migas de pan solo en el detalle ("Préstamos › <nombre>"). Título único por
  página. Skeletons del tamaño del contenido. Montos con `CountUp`, barras de
  avance con spring, todo respetando reducir movimiento.
- Un aviso discreto en cada pantalla: "Para editar, usá la app".

## Foco de revisión

1. Préstamo con cronograma variable y cuotas ya pagadas: misma próxima cuota,
   saldo y avance que la app (pasó en la app: mostraba el total como cuota).
2. Préstamos prestados a otros (`direction = lent`) vs debidos (`owe`) bien
   separados.
3. Meta sin fecha y presupuesto en 0 no rompen la pantalla.
4. Un error en una pantalla muestra un mensaje con "Reintentar", no negro.

---

### Tarea 6.0: red de seguridad

- [ ] `ErrorBoundary` en `web/src/components/` alrededor del `<Outlet />` del
  layout privado y del login: muestra "Algo salió mal" con "Reintentar"
  (vuelve a montar la pantalla) e "Ir al Inicio", con la identidad de Pockt.
  Registra el error en consola sin datos del usuario. Test: un hijo que lanza
  muestra el mensaje y "Reintentar" lo vuelve a montar.

### Tarea 6.1: Préstamos

- [ ] Lista: total que debés y total que te deben, tarjetas por préstamo
  (nombre, próxima cuota y fecha, cuotas pagadas de total, saldo, barra de
  avance), cerrados aparte y plegados.
- [ ] Detalle `/prestamos/:id` según el boceto: migas, resumen, cronograma
  completo (número, fecha, monto, pagada o no, con los pagos reales de
  `transactions.loan_id`), y los movimientos ligados.

### Tarea 6.2: Metas y Presupuestos

- [ ] Metas: tarjeta por meta (ahorrado de objetivo, porcentaje, ritmo y
  fecha estimada como la app, aportes recientes). Archivadas aparte.
- [ ] Presupuestos: por categoría, usado del límite del período actual, con
  el color de alerta a 80% y 100% como la app, y el total.
- [ ] Habilitar los tres links de la `TopNav` (hoy son placeholders).

## Verificación final (orquestador)

`npm test` y `npm run build` en verde, `flutter test` si se sumaron golden
cases; en el navegador con la cuenta del usuario, los números coinciden con
la app.
