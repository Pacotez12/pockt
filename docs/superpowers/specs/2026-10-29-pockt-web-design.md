# Pockt web: plataforma web sincronizada con la app

Fecha: 2026-10-29 · Rama: `father` · Estado: diseño aprobado en conversación,
spec pendiente de revisión.

Bocetos validados (visual companion, `.superpowers/brainstorm/171364-1793283290/content/`):
`web-topnav.html` (barra), `web-pantallas.html` (Inicio, Movimientos, Reportes),
`web-pantallas-2.html` (Préstamo, Metas y Presupuestos, Login, 404, modo claro).

## 1. Objetivo

Una web privada para ver más datos, descargar reportes y cargar o editar
movimientos desde la compu, con los mismos datos de la app y cambios visibles
al instante en los dos lados. Un solo usuario (el dueño de los datos).

Éxito:
- Un movimiento cargado en la web aparece en el teléfono en segundos, y al revés.
- El teléfono sigue funcionando completo sin conexión y sin iniciar sesión.
- La web muestra los mismos números que la app para el mismo período.
- Nadie más que el usuario puede leer o escribir sus filas.

## 2. Alcance de la primera versión

En la web:
- Login con Google.
- Inicio: gastado en el mes (tarjeta principal), ingresos, ahorrado en metas,
  arco por categoría, entradas y salidas de 6 meses, últimos movimientos,
  próximos vencimientos (cuotas de préstamos y recurrentes).
- Movimientos: tabla con búsqueda y filtros (fecha, categoría, tipo, monto,
  origen), totales del período; cargar, editar y borrar en un panel lateral;
  descarga CSV y Excel.
- Reportes: período Mes / Año / Personalizado; totales, ahorro neto, mes más
  caro, suscripciones al año, tendencia por categoría, ranking de comercios;
  descargas CSV, Excel y PDF de resumen.
- Préstamos (lista y detalle con cronograma), Metas y Presupuestos: solo lectura.
- 404, modo claro y oscuro (sigue al sistema, con opción).

Fuera de la primera versión: "Podés gastar hoy" (no va en la web), editar
préstamos, metas, presupuestos, recurrentes y categorías desde la web,
bandeja de pendientes de captura, varios usuarios, dominio propio.

## 3. Arquitectura

```
Teléfono (Flutter)                  Nube                        Web (React)
Drift sobre la base de PowerSync <-> PowerSync Service <-> Supabase Postgres <-> PowerSync Web SDK
 (todo local, funciona offline)      (sync en vivo)        (fuente en la nube,   (base local en el
                                                            RLS por usuario)      navegador, IndexedDB)
            escrituras: cola local de PowerSync -> uploadData -> Supabase (con el JWT del usuario)
```

- **Supabase**: Postgres + Auth (Google). Cada tabla sincronizada tiene
  `user_id uuid` y Row Level Security: `user_id = auth.uid()` para leer y escribir.
- **PowerSync**: sincroniza Postgres con la SQLite local de cada dispositivo.
  Regla de sync: un bucket por usuario (`WHERE user_id = request.user_id()`).
  Conflictos: gana la última escritura que llega al servidor (un solo usuario,
  choques muy raros).
- **Teléfono**: Drift sigue siendo la capa de acceso; la base pasa a ser la de
  PowerSync vía `drift_sqlite_async`. Repositorios, cálculos y tests se
  mantienen. La sincronización es opcional: interruptor "Sincronizar con la
  web" en Ajustes; sin sesión la app funciona igual que hoy.
- **Web**: Vite + React + TypeScript + Tailwind + shadcn/ui + Motion, PowerSync
  Web SDK (base local en el navegador) y supabase-js para Auth. Hosting
  estático en Vercel (plan Hobby). Carpeta `web/` del mismo repo.

## 4. Cambios en la base de la app

PowerSync exige en cada tabla sincronizada una clave primaria única de texto
llamada `id`, no admite claves compuestas y no valida unicidad, claves
foráneas ni restricciones en el cliente (eso queda en Postgres).

Tablas sincronizadas (las que usa la web): `transactions`, `categories`,
`loans`, `loan_installments`, `goals`, `goal_contributions`, `budgets`,
`recurring_rules`, `income_schedules`, `salary_deductions`, `events`,
`settings`.

Ajustes necesarios:
- `loan_installments`: `id` = `<loanId>:<number>` (hoy PK compuesta).
- `settings`: `id` = la clave (hoy PK `key`).
- Toda tabla sincronizada con `updated_at`; los borrados de filas que la web
  pueda borrar son lógicos (`deleted_at`) donde hoy no lo son, para que viajen.
- Fechas y booleanos en tipos que PowerSync soporta (texto, entero, real):
  verificar que el formato de Drift se mantenga.

Tablas solo locales (no viajan): `suggested_transactions`, `merchant_memory`,
`category_keywords`, `counterparty_rules`, `entry_shortcuts`, `day_marks`.

Migración: al activar la sincronización por primera vez, los datos existentes
de la base de Drift se copian a las tablas de PowerSync y se suben. Sin
pérdida: antes de migrar se hace una copia de la base.

**Riesgo principal:** `drift_sqlite_async` está en beta y el paso de una base
Drift existente a PowerSync no está documentado como camino directo. Por eso
el plan empieza con una prueba técnica (sección 9, fase 0).

## 5. Lógica compartida y números iguales

La web no comparte código con la app. Para que los números coincidan:
- Cálculos que la web necesita: período del mes según "inicio del mes",
  totales por categoría, avance de préstamos (con cronograma y cuotas ya
  pagadas), proyección de metas, uso de presupuestos, próximos vencimientos
  de recurrentes.
- **Casos de prueba compartidos**: `shared/golden/*.json` con entradas y
  resultados esperados. Los corren los tests de Dart y los de TypeScript. Un
  cambio de fórmula en un lado sin el otro hace fallar un test.

## 6. Seguridad y privacidad

- RLS en todas las tablas; política probada con un segundo usuario de prueba
  que no puede ver filas ajenas.
- Llaves privadas (service role de Supabase, llaves de PowerSync) nunca en el
  repo, que es público. En el código solo la llave pública de Supabase y la URL.
  Configuración en `.env` ignorado por git y en las variables de Vercel.
- Login: Google. En el teléfono, inicio de sesión nativo con el token de Google
  hacia Supabase (`signInWithIdToken`); en la web, OAuth de Supabase. Cliente
  OAuth web nuevo en el proyecto de Google Cloud existente.
- La web no se indexa: `robots.txt` con `Disallow: /` y `noindex` en todas las
  páginas. Sin sitemap.
- Ningún dato real en el repo (fixtures, golden cases y capturas con datos
  inventados).

## 7. Reglas de la web (diseño y calidad)

- Identidad de la app: fondo negro, vidrio, degradé naranja a rosa
  (#FF8A3D a #FF3D7F) solo en botones y acentos, Inter con números tabulares,
  aurora de fondo, modo claro y oscuro con los mismos tokens de la app.
- Prohibido: degradé violeta a azul, texto con degradé, emojis (solo íconos
  SVG), rayas largas en los textos.
- Barra superior `TopNav` aislada en un componente: arriba de todo, a lo ancho
  y transparente; al hacer scroll se transforma en píldora de vidrio centrada
  (Motion); con "reducir movimiento" cambia sin animación. Por debajo de cierto
  ancho pasa a menú.
- Carga: skeleton del mismo tamaño que el contenido, con brillo suave, mostrando
  por partes lo que ya está listo (números, gráficos, tablas); spinner solo en
  acciones chicas (guardar, generar PDF).
- Inputs: label arriba, placeholder con el formato, ayuda abajo siempre
  visible, campo activo con borde y label en color de marca, error abajo en
  rojo con ícono.
- Jerarquía: una acción principal visible sin scroll ("Cargar" en la barra);
  pantallas fáciles de escanear.
- Migas de pan solo en detalles (Préstamos › nombre).
- Título único por página ("Movimientos · Pockt"); metadescripción solo en el
  login; texto alternativo en imágenes y etiquetas en botones de solo ícono;
  favicon con el ícono de la app; 404 propia con salida al Inicio.
- Responsive: optimizada para compu y tablet; usable en el teléfono.
- Componentes: shadcn/ui como base; Watermelon UI (MIT), Cult UI, React Bits
  y Skiper UI (solo gratis, con la atribución que pida) copiando solo lo
  necesario, revisando licencia y código, y adaptando cada uno a los tokens
  de Pockt.
- Skills de diseño: **`apple-design` es la principal** (movimiento físico con
  springs interrumpibles, paneles y gestos, materiales translúcidos,
  tipografía, reducir movimiento) y manda cuando hay dudas; `emil-design-eng`
  es la segunda (pulido de componentes y decisiones de animación). De apoyo:
  ui-ux-pro-max, impeccable, high-end-visual-design, animate,
  review-animations, fixing-accessibility, fixing-motion-performance,
  web-design-guidelines. Cada pantalla nueva se valida en el visual companion
  antes de implementarla.
- Aprobado 2026-11-07: login con fondo shader WebGL propio y tarjetas
  flotantes; montos que cuentan, entradas escalonadas y paneles con resorte;
  en Reportes, "Tus días" como mapa de calor de puntos con cambio a 3D
  isométrico (three.js, una sola malla instanciada, globo con detalle). En la
  app, más adelante: toque largo sobre "Tus días" inclina el calendario.
  Solo librerías gratis (three.js MIT); nada de bibliotecas pagas.

## 8. Errores y estados

- Sin conexión en la web: aviso discreto en la barra ("Sin conexión, los
  cambios se guardan y se suben al volver"); la base local sigue mostrando datos.
- Sesión vencida: se renueva sola; si no puede, vuelve al login sin perder lo
  que estaba sin subir.
- Error al subir un cambio rechazado por el servidor: se muestra en la fila y
  se puede reintentar o descartar.
- Estado de sincronización siempre visible en la barra (Sincronizado / Subiendo
  / Sin conexión).

## 9. Etapas

0. **Prueba técnica** (descartable): app Flutter mínima con Drift +
   PowerSync + Supabase local; tabla con id texto, migración de datos Drift
   existentes, cambio en vivo hacia una web mínima. Resultado: sí o no al
   camino `drift_sqlite_async`, con alternativas si no.
1. Supabase y PowerSync: esquema Postgres, RLS, reglas de sync, Auth Google.
2. App: adaptación de la base (ids, borrados lógicos), PowerSync opcional,
   login, migración inicial, interruptor en Ajustes.
3. Web base: proyecto, tokens, TopNav, login, 404, estado de sync, skeletons.
4. Movimientos: tabla, filtros, panel de carga y edición, descargas CSV/Excel.
5. Inicio y Reportes, con golden cases compartidos; PDF.
6. Préstamos, Metas y Presupuestos (lectura).
7. Despliegue en Vercel, revisión de accesibilidad, rendimiento y seguridad.

## 10. Pruebas

- App: suite actual en verde en cada etapa; tests de migración de la base y
  de ids nuevos; golden cases en Dart.
- Web: Vitest para lógica y golden cases; tests de componentes; prueba de RLS
  con dos usuarios; prueba punta a punta de un cambio en vivo web a teléfono y
  teléfono a web en el dispositivo real (instalando la variante Demo primero).

## 11. Cuentas que crea el usuario

GitHub (existe), Supabase, Vercel (Hobby) y PowerSync, todas con GitHub. La
configuración se hace con el usuario presente; él inicia sesión y aprueba
permisos.
