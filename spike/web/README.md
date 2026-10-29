# Mini web descartable · Tarea 0.4

Vite + React + TypeScript. Solo datos inventados; no se importa desde la app.
Requiere Node 24 y el entorno de la tarea 0.1 corriendo:
Supabase en `http://localhost:54321` y PowerSync en `http://localhost:18080`.

## Levantar

```bash
cd spike/web
npm ci
cp .env.example .env
# Completar VITE_SUPABASE_ANON_KEY con SUPABASE_ANON_KEY del .env local
# de spike/infra. Usar solo la llave anon local, nunca service role.
npm run dev -- --port 5173 --strictPort
```

Abrir http://127.0.0.1:5173. `.env` está ignorado; no sobrescribirlo si ya está
configurado. Todas las variables públicas se leen de `import.meta.env`.
No incluir contraseñas, llaves admin o credenciales de nube en `VITE_*`.

Entrar con `a@test.local` o `b@test.local`. La contraseña inventada es el
valor de `SPIKE_TEST_PASSWORD` en `spike/infra/.env` (no se incorpora al frontend).
El login usa `supabase.auth.signInWithPassword` contra Auth local.

## Probar

1. Iniciar sesión como A y esperar “Sincronizado”.
2. Pulsar “+ Insertar Gs. 184.000”. La fila aparece inmediatamente en SQLite;
   PowerSync la encola y el conector la sube a Supabase con el JWT del usuario.
3. Abrir otra sesión del navegador como A: la fila debe aparecer sin recargar.
   También se reciben filas insertadas desde Supabase o desde la app Flutter
   de la tarea 0.2, siempre con el mismo `user_id`.
4. Cerrar sesión y entrar como B: no debe ver las filas de A.
5. Con la app Flutter de 0.2 abierta como A, probar ambos sentidos y comprobar
   que el cambio aparece en menos de 5 segundos. Esa comprobación conjunta
   queda pendiente mientras se termina 0.2; la verificación con Chrome local
   cubrió web → Supabase y Supabase → web, sin recargar.

Cada usuario tiene un archivo SQLite distinto (`pockt-spike-<uuid>.db`).
Al cerrar sesión se desconecta y cierra esa base. Los datos y las escrituras
pendientes se conservan para la siguiente sesión de esa misma cuenta.
Las consultas también filtran por usuario. La seguridad del servidor sigue
siendo RLS de Supabase y las reglas de buckets de PowerSync.

Este spike solo genera inserciones: UUID v4, `amount` entero y fechas Unix
en segundos. El conector usa upsert por UUID para reintentar sin duplicados;
solo completa la transacción local si Supabase aceptó las operaciones. Los
errores de subida quedan visibles y el SDK vuelve a intentar. No incluye
edición ni borrado desde la UI.

## Verificar y bajar

```bash
npm test
npm run build
# Ctrl+C en la terminal que ejecuta Vite para bajar solo esta web.
```

TDD observado: los dos tests fallaron antes de implementar y luego pasaron:
`formatGs(184000) === 'Gs. 184.000'` y `spike_tx.amount` de tipo `INTEGER`.
El build verifica TypeScript y empaqueta los workers/WASM. Vite excluye
`@powersync/web` de optimizeDeps según el ejemplo oficial.

Referencias: [SDK web](https://docs.powersync.com/client-sdks/reference/javascript-web),
[hooks React](https://github.com/powersync-ja/powersync-js/tree/main/packages/react),
[config Vite oficial](https://github.com/powersync-ja/powersync-js/blob/main/demos/example-vite/vite.config.ts),
[login Supabase](https://supabase.com/docs/reference/javascript/auth-signinwithpassword).
