<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/brand/readme/banner-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="docs/brand/readme/banner-light.png">
  <img src="docs/brand/readme/banner-dark.png" alt="Pockt — Tus gastos, en el bolsillo." width="100%">
</picture>

<br>

Una app de finanzas personales para Android, **rápida para anotar y hermosa de usar**.

[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-8.0%2B-3DDC84?logo=android&logoColor=white)](https://www.android.com)
[![Local-first](https://img.shields.io/badge/datos-local--first-FF3D7F)](#privacidad)
[![Estado](https://img.shields.io/badge/versión-0.2-FF8A3D)](#estado)

<br>

<img src="docs/brand/readme/carga.gif" alt="Cargar un gasto en Pockt: elegir categoría, escribir el monto y guardar" width="300">

<sub><i>Cargar un gasto: categoría, monto, listo.</i></sub>

</div>

<br>

<picture>
  <source media="(prefers-color-scheme: light)" srcset="docs/brand/readme/gallery-light.png">
  <img src="docs/brand/readme/gallery-dark.png" alt="Pantallas de Pockt: inicio con calendario de calor, detalle del día, presupuestos y bandeja de sugeridos" width="100%">
</picture>

---

## Qué es Pockt

Pockt nace de una idea simple: si anotar un gasto tarda, dejás de anotarlo. Por eso todo gira alrededor de cargar un gasto en **tres toques**, y de que mirar tus finanzas sea algo que *querés* hacer.

- **Categoría primero.** Tocás la burbuja de la categoría, se transforma en el teclado con su color, ponés el monto y listo.
- **Texto natural que aprende.** Escribís `super 230 mil ayer` o `bolt 28.500` y Pockt lo entiende. Cada comercio que guardás queda en una libreta local: la próxima vez ya sabe su categoría, y tolera errores de tipeo.
- **Tus días, a la vista.** Un calendario de calor del mes, al estilo de las contribuciones de GitHub, que muestra en qué días gastaste más. Tocás un día y ves en qué se fue.
- **Presupuestos por categoría** con anillos de progreso y notificaciones al 80 % y al 100 % (una sola vez por mes).
- **Recurrentes y cobros** que te esperan en una bandeja para confirmar, sin cargarse a ciegas. Entiende el cobro quincenal real: si el 15 cae en fin de semana o feriado, puede ser el día hábil anterior o el siguiente, y el "quedan" arranca el día que cobraste de verdad.
- **Recordatorios con intensidad**: de "suave" a "insistente", y solo si ese día no anotaste nada.
- **Reportes**: mes por categoría, evolución, comparación con el mes anterior a la misma altura y ranking por comercio.

## Diseño

Identidad propia, **"Profundidad y luz"**: negro puro para pantallas AMOLED (y modo claro), un resplandor que toma el color de la categoría donde más gastaste, superficies de vidrio y animaciones con física.

## Privacidad

- **Local-first**: tus datos viven en tu teléfono (SQLite).
- **Backup cifrado** (AES-256-GCM) en una carpeta de **tu propio** Google Drive. La clave sale de una contraseña que solo vos conocés.
- **Sin servidor, sin analíticas, sin publicidad.**

## Stack

**La app**

- **[Flutter](https://flutter.dev) 3.47 + Dart 3.13** — el framework. Dibuja cada píxel con su propio motor (Impeller), lo que permite un diseño 100 % propio y animaciones fluidas.
- **[Inter](https://rsms.me/inter/)** — la tipografía, incluida dentro de la app. Con cifras tabulares: todos los dígitos miden lo mismo, así los montos no "bailan" mientras escribís.

**Datos**

- **[Drift](https://drift.simonbinder.eu)** — base de datos SQLite tipada y reactiva. Guarda gastos, categorías y presupuestos, y avisa sola a cada pantalla cuando algo cambia.
- **[uuid](https://pub.dev/packages/uuid)** — identificadores únicos para cada registro; facilitan backups y una futura sincronización.

**Estado**

- **[Riverpod](https://riverpod.dev)** — conecta los datos con las pantallas: el total del inicio "escucha" a la base y se actualiza solo al cargar un gasto.

**Notificaciones**

- **[flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)** — alertas de presupuesto y avisos de cobros y recurrentes.

**Fechas y formatos**

- **[timezone](https://pub.dev/packages/timezone) + [flutter_timezone](https://pub.dev/packages/flutter_timezone)** — toman la zona horaria del teléfono, para que un gasto de las 23:30 caiga en el día correcto aunque internamente se guarde en UTC.
- **[intl](https://pub.dev/packages/intl)** — fechas en español ("Viernes 17 de octubre").

**Desarrollo y calidad**

- **[build_runner](https://pub.dev/packages/build_runner) + drift_dev + riverpod_generator** — generan el código repetitivo (consultas tipadas, providers) para no escribirlo a mano.
- **[flutter_test](https://docs.flutter.dev/testing) + [mocktail](https://pub.dev/packages/mocktail)** — tests unitarios, de base de datos y de widgets. La lógica de fechas y montos se escribe con tests primero.
- **integration_test** — mide los tiempos de cada frame en un teléfono real (en una variante aparte, sin tocar tus datos).

**Próximamente**

- **workmanager** — backup automático en segundo plano, solo con WiFi.
- **home_widget** — widget de pantalla de inicio con tus categorías más usadas.
- **local_auth** — bloqueo opcional con huella.
- **google_sign_in + googleapis (Drive)** — backup en tu propio Google Drive.
- **cryptography** — cifrado AES-256-GCM con clave derivada por Argon2id.

## Arquitectura

```
lib/
  core/        sistema visual, base de datos, formatos y fechas
  features/    una carpeta por funcionalidad (entry, home, transactions, budgets, …)
```

Cada funcionalidad tiene tres capas: **datos** (repositorios Drift), **lógica** (providers Riverpod con streams reactivos) y **UI** (widgets que solo muestran y animan). Las funcionalidades no se importan entre sí: se comunican a través de la base de datos.

El diseño completo está en [`docs/superpowers/specs/`](docs/superpowers/specs/) y los planes de implementación en [`docs/superpowers/plans/`](docs/superpowers/plans/).

## Estado

| Etapa | Contenido | |
|---|---|---|
| **Plan 1** | Base, carga de gastos, inicio, calendario de calor, movimientos, texto natural que aprende | ✅ v0.1 |
| **Plan 2** | Presupuestos, recurrentes, cobro quincenal con días hábiles y feriados, bandeja de sugeridos, Ajustes | ✅ v0.2 |
| **Plan 3** | Reportes, recordatorios, apariencia, logotipo y apertura animada, widget y acceso rápido | ⏳ |
| **Plan 4** | Backup cifrado, restauración, bloqueo con huella, primer uso | ⏳ |
| **Después** | Motor de captura: leer notificaciones de bancos, SMS y correos | 💡 |
| **Después** | Otras monedas e idiomas (hoy: guaraníes y español) | 💡 |

## Desarrollo

Requisitos: Flutter 3.47 estable y un dispositivo o emulador Android 8.0+.

```bash
git clone https://github.com/Pacotez12/pockt.git
cd pockt
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # código generado de Drift
flutter test
flutter run
```
