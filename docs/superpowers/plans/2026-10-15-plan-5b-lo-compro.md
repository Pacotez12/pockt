# Pockt — Plan 5b: Podés gastar hoy, ¿Lo compro? y tono

**Spec:** §7d. Depende del plan 5a (metas). **Global Constraints:** las de siempre.

### Task 1: Podés gastar hoy (dominio)
Función pura `safeToSpendToday(...)` según §7d (quedan − recurrentes pendientes hasta el cobro − aporte necesario de metas prorrateado, ÷ días hasta el cobro, mínimo 1 día). Provider reactivo. Tests: sin esquema de cobro (usa fin de mes), con recurrentes, con metas, negativo.

### Task 2: Tono
Ajuste `tone.level` (`soft`|`normal`|`spicy`, por defecto normal) en Ajustes → Avisos. Banco de mensajes de ¿Lo compro? por tono y situación (dentro del día / pasa el día / rompe presupuesto / atrasa meta), varios por caso, en español paraguayo; Picante con humor sin insultos. Tests de selección.

### Task 3: Hoja ¿Lo compro? (opción A)
Mantener apretado el ＋ abre la hoja: monto con el teclado existente + categoría; lista antes → después (podés gastar hoy, presupuesto de la categoría, días de atraso por meta con fecha); colores de estado solo al cruzar límites; mensaje del tono; "No, gracias" / "Lo compro" (abre la carga con monto y categoría). Skills: emil-design-eng, apple-design, impeccable. Tests de widget.

### Task 4: Podés gastar hoy en el Inicio (opción B, con ajuste)
Ajuste `home.headline` (`safeToSpend` por defecto | `monthSpent`) con segmento "Número principal" en Ajustes → Inicio y apariencia. Con `safeToSpend`: etiqueta "Podés gastar hoy", número grande (negativo en `danger`), debajo una línea chica "Gastado X · Quedan Y" y la línea de período/cobro como hoy; respeta "Ocultar montos". Con `monthSpent`: el Inicio actual sin cambios. Calendario de calor intacto. Tests de los dos modos.
