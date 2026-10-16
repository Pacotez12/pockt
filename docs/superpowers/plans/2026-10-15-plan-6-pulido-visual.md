# Plan 6: Pulido Visual de Pantallas Nuevas

Auditoría y corrección sistemática de inconsistencias visuales, accesibilidad táctil, tipografía y compatibilidad responsiva (360 px y textScaler 1.3) según spec §6.2b, §7d, §7e y los principios de Emil Kowalski / Apple Design / Impeccable.

---

## Hallazgos por Superficie

### 1. Metas (`goals_screen.dart`, `goal_detail_screen.dart`, `goal_editor.dart`, tarjeta Metas en `home_screen.dart`)
- [x] **`lib/features/goals/ui/goals_screen.dart:23-26`**:
  - *Problema:* Función local `_formatGs` formateaba como `₲ X` en vez de usar el estándar de la app `formatGs(amount)` (`Gs. X`).
  - *Arreglo:* Eliminar `_formatGs` local y usar `formatGs(amount)` de `money.dart`.
- [x] **`lib/features/goals/ui/goals_screen.dart:58-73`**:
  - *Problema:* Botón volver de 36x36 px (< 44 px mínimo de toque).
  - *Arreglo:* Ampliar a 44x44 px (o envolver con padding/constraints mínimos de 44x44 px).
- [x] **`lib/features/goals/ui/goals_screen.dart:111-134`**:
  - *Problema:* Botón agregar meta de 36x36 px (< 44 px).
  - *Arreglo:* Ampliar a 44x44 px manteniendo ícono centrado y semántica.
- [x] **`lib/features/goals/ui/goals_screen.dart:203, 341`**:
  - *Problema:* Radio mágico `999` en vez de tokens de diseño `PocktRadii.xl`.
  - *Arreglo:* Reemplazar por `PocktRadii.xl`.
- [x] **`lib/features/goals/ui/goals_screen.dart:349, 415`**:
  - *Problema:* Tipografía de 11 px en badge de estado y etiqueta de ritmo (regla Pockt: no texto < 12 px).
  - *Arreglo:* Subir a `PocktType.caption` (12 px).
- [x] **`lib/features/goals/ui/goals_screen.dart:362`**:
  - *Problema:* Radio mágico `4` en barra de progreso.
  - *Arreglo:* Reemplazar por `PocktRadii.s` (8 px) o radio semántico consistente con barras.
- [x] **`lib/features/goals/ui/goals_screen.dart:369`**:
  - *Problema:* `progress.percent` sin clamp en `FractionallySizedBox` (desborde si meta superada).
  - *Arreglo:* `progress.percent.clamp(0.0, 1.0)`.
- [x] **`lib/features/goals/ui/goals_screen.dart:385-406`**:
  - *Problema:* Fila de montos y porcentaje sin `Flexible`/`FittedBox` (riesgo de desborde en 360 px y `textScaler 1.3`).
  - *Arreglo:* Envolver montos en `Expanded` con `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft)`.
- [x] **`lib/features/goals/ui/goals_screen.dart:269, 471`**:
  - *Problema:* `Pressable` sin `semanticLabel`.
  - *Arreglo:* Agregar `semanticLabel: 'Meta ${goal.name}'` y `semanticLabel: 'Crear primera meta'`.
- [x] **`lib/features/goals/ui/goal_detail_screen.dart:22-25`**:
  - *Problema:* `_formatGs` con `₲` hardcodeado.
  - *Arreglo:* Usar `formatGs(amount)`.
- [x] **`lib/features/goals/ui/goal_detail_screen.dart:37-38`**:
  - *Problema:* Colores hexadecimales hardcodeados (`0xFF5FC8A6`, `0xFF007E5E`) en categoría sintética.
  - *Arreglo:* Usar tokens de color de `context.pockt`.
- [x] **`lib/features/goals/ui/goal_detail_screen.dart:316`**:
  - *Problema:* `progress.percent` sin clamp en `CircularProgressIndicator`.
  - *Arreglo:* Clampear con `.clamp(0.0, 1.0)`.
- [x] **`lib/features/goals/ui/goal_detail_screen.dart:346, 375`**:
  - *Problema:* Tipografía de 13 px fuera de escala.
  - *Arreglo:* Usar `PocktType.caption` (12 px) o `PocktType.body` (14 px).
- [x] **`lib/features/goals/ui/goal_detail_screen.dart:388, 430`**:
  - *Problema:* `Pressable` en botones Aportar y Retirar sin `semanticLabel`.
  - *Arreglo:* Agregar `semanticLabel: 'Aportar a meta'` y `'Retirar de meta'`.
- [x] **`lib/features/goals/ui/goal_detail_screen.dart:649-673`**:
  - *Problema:* En `_statRow`, valor sin `Flexible`/`FittedBox` (desborda en 360 px con textos largos y letra grande).
  - *Arreglo:* Envolver valor en `Flexible(child: FittedBox(...))`.
- [x] **`lib/features/goals/ui/goal_editor.dart:218`**:
  - *Problema:* Prefijo hardcodeado `₲` en vez de `Gs.`.
  - *Arreglo:* Usar `Gs.`.
- [x] **`lib/features/goals/ui/goal_editor.dart:167, 203, 255`**:
  - *Problema:* Tipografía de 13 px en etiquetas de formulario.
  - *Arreglo:* Estandarizar a `PocktType.caption` (12 px) con `colors.textSecondary`.
- [x] **`lib/features/goals/ui/goal_editor.dart:266, 349, 380`**:
  - *Problema:* `Pressable` sin `semanticLabel` en íconos, selector de fecha y botón Guardar.
  - *Arreglo:* Agregar `semanticLabel`.
- [x] **`lib/features/home/ui/home_screen.dart:879`**:
  - *Problema:* `Pressable` de la tarjeta Metas en el Inicio sin `semanticLabel`.
  - *Arreglo:* Agregar `semanticLabel: 'Ver metas'`.
- [x] **`lib/features/home/ui/home_screen.dart:947-980`**:
  - *Problema:* Fila de meta en el Inicio: nombre sin `Expanded` (desborda con nombres largos o escala 1.3).
  - *Arreglo:* Envolver texto de meta en `Expanded` y clampear progreso a 1.0.

---

### 2. ¿Lo compro? (`buy_simulator_sheet.dart`)
- [x] **`lib/features/safe_to_spend/ui/buy_simulator_sheet.dart:192`**:
  - *Problema:* Radio modal `28` mágico.
  - *Arreglo:* Usar `PocktRadii.xl` (24 px).
- [x] **`lib/features/safe_to_spend/ui/buy_simulator_sheet.dart:225, 236`**:
  - *Problema:* Tipografía hardcodeada 20 y 12.
  - *Arreglo:* Usar `PocktType.title` y `PocktType.caption`.
- [x] **`lib/features/safe_to_spend/ui/buy_simulator_sheet.dart:253, 493, 528, 666`**:
  - *Problema:* `Pressable` sin `semanticLabel` en selector de categoría, botones de acción y teclado numérico.
  - *Arreglo:* Agregar etiquetas semánticas claras a todos los elementos interactivos.
- [x] **`lib/features/safe_to_spend/ui/buy_simulator_sheet.dart:284, 361, 451, 467, 617, 629, 641`**:
  - *Problema:* Tipografía de 13 px fuera de escala.
  - *Arreglo:* Estandarizar a `PocktType.caption` (12) o `PocktType.body` (14).
- [x] **`lib/features/safe_to_spend/ui/buy_simulator_sheet.dart:435`**:
  - *Problema:* Llamada a `categoryIconData` con ícono Phosphor de meta.
  - *Arreglo:* Usar `uiIcon(g.goal.icon)`.
- [x] **`lib/features/safe_to_spend/ui/buy_simulator_sheet.dart:607-650`**:
  - *Problema:* Fila de comparación antes -> después desborda en 360 px con números grandes y letra 1.3.
  - *Arreglo:* Envolver columna derecha en `Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Row(...)))`.

---

### 3. Podés gastar hoy (`home_screen.dart`)
- [x] **`lib/features/home/ui/home_screen.dart:1171-1175`**:
  - *Problema:* Usa `GestureDetector` sin respuesta háptica ni accesibilidad para alternar privacidad.
  - *Arreglo:* Usar `Pressable` con `semanticLabel: 'Alternar ocultar montos'`.
- [x] **`lib/features/home/ui/home_screen.dart:1215-1224`**:
  - *Problema:* Subtítulo `Gastado X · Quedan Y` sin protección contra overflow en 360 px con fuente grande.
  - *Arreglo:* Envolver en `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(...))`.

---

### 4. Saldo arrastrado (`carry_over_card.dart` y línea del período en `home_screen.dart`)
- [x] **`lib/features/income/ui/carry_over_card.dart:180`**:
  - *Problema:* `_CardButton` altura 40 px (< 44 px mínimo táctil).
  - *Arreglo:* Subir altura a 44 px.
- [x] **`lib/features/income/ui/carry_over_card.dart:227-268`**:
  - *Problema:* Hoja modal `_GoalPickerSheet` sin scroll si hay muchas metas o fuente aumentada.
  - *Arreglo:* Envolver lista de metas en `Flexible(child: SingleChildScrollView(...))`.
- [x] **`lib/features/home/ui/home_screen.dart:1466-1468`**:
  - *Problema:* `GestureDetector` en línea de período sin accesibilidad.
  - *Arreglo:* Envolver con `Semantics(button: true, label: 'Línea de período')`.
- [x] **`lib/features/home/ui/home_screen.dart:1483`**:
  - *Problema:* Tamaño 11 px en texto de arrastre.
  - *Arreglo:* Subir a 12 px (`PocktType.caption`).

---

### 5. Aportes en Movimientos (`tx_row.dart`)
- [x] **`lib/features/transactions/ui/tx_row.dart:358`**:
  - *Problema:* `GoalContributionRow` en `Pressable` sin `semanticLabel`.
  - *Arreglo:* Agregar `semanticLabel: '$title, $amountStr'`.
- [x] **`lib/features/transactions/ui/tx_row.dart:399, 412, 424`**:
  - *Problema:* Tipografías hardcodeadas.
  - *Arreglo:* Usar `PocktType.body` y `PocktType.caption`.

---

### 6. Eventos (`events_screen.dart`)
- [x] **`lib/features/events/ui/events_screen.dart:34-36, 69-70, 387-388`**:
  - *Problema:* Botones de volver y agregar de 36x36 px (< 44 px).
  - *Arreglo:* Aumentar área táctil a 44x44 px.
- [x] **`lib/features/events/ui/events_screen.dart:312`**:
  - *Problema:* Texto 'Activo' de 10 px.
  - *Arreglo:* Subir a 12 px (`PocktType.caption`).
- [x] **`lib/features/events/ui/events_screen.dart:569, 820`**:
  - *Problema:* Textos secundarios de 11 px.
  - *Arreglo:* Subir a 12 px (`PocktType.caption`).
- [x] **`lib/features/events/ui/events_screen.dart:879`**:
  - *Problema:* Radio modal `28` mágico.
  - *Arreglo:* Reemplazar por `PocktRadii.xl` (24 px).
- [x] **`lib/features/events/ui/events_screen.dart:959`**:
  - *Problema:* `Pressable` de selector de íconos sin `semanticLabel`.
  - *Arreglo:* Agregar `semanticLabel: 'Ícono $key'`.
- [x] **`lib/features/events/ui/events_screen.dart:1028-1075`**:
  - *Problema:* Uso de `ElevatedButton` sin degradé ni estilos de diseño Pockt.
  - *Arreglo:* Usar `Pressable` con degradé de marca y altura 48 px.

---

### 7. Gastos hormiga (`reports_screen.dart`)
- [x] **`lib/features/reports/ui/reports_screen.dart:1612, 1635, 1656, 1676, 1697`**:
  - *Problema:* Textos de 11 px en badges y tarjetas estadísticas.
  - *Arreglo:* Subir a 12 px (`PocktType.caption`).
- [x] **`lib/features/reports/ui/reports_screen.dart:1623-1707`**:
  - *Problema:* Montos de tarjetas estadísticas en `Row` sin `FittedBox` (riesgo de desborde en 360 px con escala 1.3).
  - *Arreglo:* Envolver cada monto en `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft)`.
- [x] **`lib/features/reports/ui/reports_screen.dart:1744`**:
  - *Problema:* Color hexadecimal hardcodeado `0xFF8BA4B5`.
  - *Arreglo:* Usar `colors.textTertiary.toARGB32()`.

---

### 8. Atajos (`entry_flow.dart`)
- [x] **`lib/features/entry/ui/entry_flow.dart:965`**:
  - *Problema:* Barra de chips con altura 38 px (< 44 px).
  - *Arreglo:* Subir a 44 px.
- [x] **`lib/features/entry/ui/entry_flow.dart:976`**:
  - *Problema:* `Pressable` del atajo sin `semanticLabel`.
  - *Arreglo:* Agregar `semanticLabel: 'Atajo ${item.label}, ${formatGs(item.amount)}'`.

---

### 9. Primer uso (`onboarding_flow.dart`)
- [x] **`lib/features/onboarding/ui/onboarding_flow.dart:201`**:
  - *Problema:* `backgroundColor: Colors.black` hardcodeado (inutilizable en modo claro).
  - *Arreglo:* Usar `colors.background`.
- [x] **`lib/features/onboarding/ui/onboarding_flow.dart:214`**:
  - *Problema:* `PocktWordmark(color: Colors.white)` hardcodeado.
  - *Arreglo:* Usar `colors.textPrimary`.
- [x] **`lib/features/onboarding/ui/onboarding_flow.dart:256, 383, 385, 459, 464, 596, 598, 606, 746, 750, 756`**:
  - *Problema:* Capas y bordes hardcodeados con `Colors.white.withValues(...)` (invisibles o sin contraste en modo claro).
  - *Arreglo:* Reemplazar por tokens del tema (`colors.glassFill`, `colors.glassBorder`, `colors.textTertiary`).
- [x] **`lib/features/onboarding/ui/onboarding_flow.dart:452`**:
  - *Problema:* `GestureDetector` en tarjetas de modo sin accesibilidad.
  - *Arreglo:* Usar `Pressable` con `semanticLabel: 'Modo $title'`.
- [x] **`lib/features/onboarding/ui/onboarding_flow.dart:419, 561, 803`**:
  - *Problema:* `ElevatedButton` básico en vez de botón Pockt con degradé de marca.
  - *Arreglo:* Usar `Pressable` con degradé de marca y `PocktRadii.xl`.
- [x] **`lib/features/onboarding/ui/onboarding_flow.dart:634`**:
  - *Problema:* `SizedBox(width: 100)` fijo para montos en escala 1.3.
  - *Arreglo:* Ajustar a ancho responsivo con `FittedBox`.
- [x] **`lib/features/onboarding/ui/onboarding_flow.dart:246, 267`**:
  - *Problema:* Animaciones no respetan `Motion.reduced`.
  - *Arreglo:* Verificar `Motion.reduced(context)` para duración 0 cuando se solicita movimiento reducido.

---

## Hallazgos del Orquestador en Teléfono Real (Demo, A54)

### Grupo A: Período y Cobros (#1, #15, #2, #11)
- [x] **1 & 15. BUG período y próximo cobro con cobro de hoy ya registrado**:
  - *Problema:* Hoy 15/10 ya hay cobro registrado y el Inicio dice "1ª quincena · cobrás hoy" y "Podés gastar hoy" divide por 1 día mostrando 1.886.500/día. En "Sueldo y cobros" dice "Próximo cobro: jueves 15 de octubre".
  - *Arreglo:* En `period_summary.dart`, `pay_days.dart`, `safe_to_spend.dart` y `income_schedule_screen.dart`: si el cobro de hoy ya está registrado (`lastConfirmedSalaryDate == hoy`), el período actual es el que arranca hoy y el próximo cobro es el siguiente (ej. 30/10, "2ª quincena").
- [x] **2. Inicio con "Podés gastar hoy" ("Quedan" duplicado)**:
  - *Problema:* "Quedan" sale dos veces (subtítulo de Podés gastar hoy y línea del período).
  - *Arreglo:* Subtítulo en Podés gastar hoy solo muestra "Gastado en <mes> Gs. X".
- [x] **11. Hora de sugerencia de cobro confirmada**:
  - *Problema:* Al confirmar una sugerencia de cobro queda a las "00:00".
  - *Arreglo:* Si es de hoy usar hora actual (`combineDayWithNow`); si es de días pasados, 12:00.

### Grupo B: Tipografía, Moneda y Números (#3, #14, #27, #32)
- [x] **3. Moneda estándar en Metas**:
  - *Problema:* Metas (lista, detalle, historial, editor) usa "₲"; el resto usa "Gs.".
  - *Arreglo:* `formatGs` en todas partes.
- [x] **14. Formato de porcentajes en Reportes**:
  - *Problema:* Porcentajes con punto "53.1 %".
  - *Arreglo:* Usar coma decimal (es-PY): "53,1 %".
- [x] **27. Comparación de meses truncada**:
  - *Problema:* "Mes anterior (septie..." truncado en la tarjeta.
  - *Arreglo:* Abreviar meses ("Sept.") o permitir 2 líneas con `FittedBox`.
- [x] **32. Adaptabilidad a fuente grande (font_scale 1.3)**:
  - *Problema:* En Inicio "Quedan Gs. 2.251.500" se corta entre "Gs." y el número. En barra de navegación etiquetas se achican distinto ("Presupuestos" más chica que "Reportes"). En Presupuestos "de Gs. 1.500.000" toca el borde de la tarjeta.
  - *Arreglo:* Usar espacio no rompible `\u00A0` o `FittedBox` en "Quedan Gs. X", tipografía consistente en nav bar, y padding/FittedBox en Presupuestos.

### Grupo C: Sistema de Diseño y Consistencia (#4, #5, #16, #17, #18, #19, #20, #25)
- [x] **4. Divisores sutiles**:
  - *Problema:* En `goal_detail_screen` y `buy_simulator_sheet` divisores blancos fuertes en oscuro y negros en claro.
  - *Arreglo:* `Divider(color: colors.glassBorder, height: 1)`.
- [x] **5. Anillo de progreso en detalle de meta**:
  - *Problema:* Color naranja sólido en anillo circular.
  - *Arreglo:* Shader con degradé de marca (`colors.brandStart` -> `colors.brandEnd`) como en barras de progreso.
- [x] **16. Botón primario y botón "+" consistentes**:
  - *Problema:* Varios estilos de botón primario (naranja sólido, círculos tintados, degradé de marca).
  - *Arreglo:* Un solo estilo de botón primario (degradé de marca, 48 px, `PocktRadii.xl`) y un solo "+" de encabezado (círculo 44x44 px touch, vidrio con borde).
- [x] **17. Control segmentado unificado**:
  - *Problema:* 3 estilos diferentes (píldora blanca, marrón con borde naranja, relleno tinte).
  - *Arreglo:* Unificar al estilo de Ajustes/Pockt (`glassFill` con borde `glassBorder`, selección en `brandAt(0)` o píldora de vidrio).
- [x] **18. Verde semántico solo para estado**:
  - *Problema:* "Total neto mensual" (Sueldo), "Quedan" en hoja de presupuesto al 50 %, "Promedio mensual de ingreso"/"Ahorro neto" en Evolución usan verde como adorno.
  - *Arreglo:* Usar `colors.textPrimary` salvo que represente un estado positivo explícito.
- [x] **19. Encabezados de sección uniformes**:
  - *Problema:* Mezcla de versalitas y oración en la misma pantalla.
  - *Arreglo:* Estandarizar encabezados de sección.
- [x] **20. Estados vacíos consistentes**:
  - *Problema:* Préstamos no tiene botón de acción en estado vacío mientras Eventos sí.
  - *Arreglo:* Mismo patrón: ícono en círculo, título, descripción y botón de acción con degradé.
- [x] **25. Acerca de Pockt**:
  - *Problema:* pubspec dice 1.0.0+1 cuando el proyecto está en 0.5. Botones con rosa+naranja.
  - *Arreglo:* Actualizar pubspec a 0.5.0+5, mostrar "Versión 0.5.0" y botones con estilo estándar Pockt.

### Grupo D: Metas, Aportes y ¿Lo compro? (#9, #10, #13, #30, #31)
- [x] **9. Montos de aportes/retiros en Movimientos**:
  - *Problema:* Montos en blanco como gasto.
  - *Arreglo:* Usar `colors.textSecondary` según spec §7d.
- [x] **10. Hoja ¿Lo compro? refinada**:
  - *Problema:* "Podés g..." truncado; con monto 0 muestra mensaje de tono; "A tiempo (+0 d)" verboso; espacio vacío inferior grande.
  - *Arreglo:* Etiqueta arriba y montos abajo en comparación; con 0 mensaje neutro "Escribí un monto"; texto "Sin atraso"; altura ajustada al contenido (`mainAxisSize: MainAxisSize.min`).
- [x] **13. Encabezados de Metas y acción Archivar**:
  - *Problema:* Lista y detalle tienen encabezados distintos; engranaje confuso en detalle.
  - *Arreglo:* Unificar con patrón de Ajustes; menú de opciones con "Archivar" explícito.
- [x] **30. Validación en editor de meta**:
  - *Problema:* "₲" presente; botón "Crear meta" activo con nombre vacío.
  - *Arreglo:* Deshabilitar botón hasta tener nombre y monto válido; usar "Gs.".
- [x] **31. Teclado de aporte a meta**:
  - *Problema:* Chip muestra ícono de caja en vez de la meta; chip "Comercio" innecesario.
  - *Arreglo:* Mostrar ícono de la meta; ocultar selector de comercio en aportes a metas.

### Grupo E: Gastos Hormiga y Reportes (#6, #7, #26, #28)
- [x] **6. Íconos en Gastos hormiga**:
  - *Problema:* Íconos salen como "?" por búsqueda de ícono fallida.
  - *Arreglo:* Mapear correctamente categoría a `uiIcon(category.icon)` o `categoryIconData`.
- [x] **7. Barra de pestañas en Reportes**:
  - *Problema:* 5 pestañas se salen de la pantalla cortando texto en los bordes.
  - *Arreglo:* Márgenes de 16 px y scroll horizontal con padding o pestañas adaptadas.
- [x] **26. Gráfico de Evolución**:
  - *Problema:* Líneas guía blancas fuertes y naranja en "Gastos".
  - *Arreglo:* Líneas con `glassBorder`; serie de gastos con color neutro/categoría.
- [x] **28. Títulos redundantes en Reportes**:
  - *Problema:* Pestaña "Por comercio" repite título "Por comercio" abajo.
  - *Arreglo:* Eliminar título repetido o reemplazar por resumen métrico.

### Grupo F: Recurrentes, Presupuestos, Categorías y Backup (#8, #21, #22, #23, #24, #29)
- [x] **8. Indicador de día en Calendario**:
  - *Problema:* "↑ 0,1× tu día promedio" en naranja cuando es muy bajo.
  - *Arreglo:* Flecha abajo y color neutro cuando ratio < 1.0.
- [x] **21. Filas de Recurrentes**:
  - *Problema:* Todas las filas con destellos naranja; tacho de borrar pegado al switch.
  - *Arreglo:* Ícono y color de categoría de la regla; acción de borrar accesible con confirmación.
- [x] **22. Título de Categorías y Palabras clave**:
  - *Problema:* Fila dice "Categorías — Personalizar y palabras clave" y pantalla dice "Palabras clave".
  - *Arreglo:* Unificar títulos.
- [x] **23. Botones de Por confirmar**:
  - *Problema:* Botón "Confirmar" toma color de categoría.
  - *Arreglo:* Estilo de botón primario de marca unificado.
- [x] **24. Terminología y botones de Copia de seguridad**:
  - *Problema:* Mezcla de términos (backup/respaldo/copia) e íconos no descriptivos.
  - *Arreglo:* Usar "copia" en toda la UI; ícono de llave/candado para contraseña y compartir para exportar.
- [x] **29. Hoja de detalle de Presupuesto**:
  - *Problema:* Hueco grande y movimientos sueltos en tarjetas individuales.
  - *Arreglo:* Ajustar espaciado y agrupar movimientos en `TxGroupCard` como en Movimientos.

