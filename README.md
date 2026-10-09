<div align="center">

<img src="docs/brand/pockt-icon-rounded.svg" alt="Pockt" width="128" height="128">

# Pockt

**Tus gastos, en el bolsillo.**
Una app de finanzas personales para Android, rápida para anotar y hermosa de usar.

[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-8.0%2B-3DDC84?logo=android&logoColor=white)](https://www.android.com)
[![Local-first](https://img.shields.io/badge/datos-local--first-FF3D7F)](#privacidad)
[![Estado](https://img.shields.io/badge/versión-0.1-FF8A3D)](#estado)

</div>

---

## Qué es Pockt

Pockt nace de una idea simple: si anotar un gasto tarda, dejás de anotarlo. Por eso todo gira alrededor de cargar un gasto en **tres toques**, y de que mirar tus finanzas sea algo que *querés* hacer.

- **Categoría primero.** Tocás la burbuja de la categoría, se transforma en el teclado con su color, ponés el monto y listo.
- **Texto natural que aprende.** Escribís `super 230 mil ayer` o `bolt 28.500` y Pockt lo entiende. Cada comercio que guardás queda en una libreta local: la próxima vez ya sabe su categoría, y tolera errores de tipeo.
- **Tus días, a la vista.** Un calendario de calor del mes, al estilo de las contribuciones de GitHub, que muestra en qué días gastaste más. Tocás un día y ves en qué se fue.
- **Presupuestos por categoría** con anillos de progreso y notificaciones al 80 % y al 100 % (una sola vez por mes).
- **Recurrentes y cobros** (quincenales o mensuales, con corrimiento a día hábil) que te esperan en una bandeja para confirmar, sin cargarse a ciegas.
- **Recordatorios con intensidad**: de "suave" a "insistente", y solo si ese día no anotaste nada.
- **Reportes**: mes por categoría, evolución, comparación con el mes anterior a la misma altura y ranking por comercio.

## Diseño: "Profundidad y luz"

Pockt tiene identidad visual propia, no el aspecto por defecto de Material:

| | |
|---|---|
| **Negro puro** | Pensado para pantallas AMOLED: los píxeles negros se apagan. También tiene modo claro, y sigue al del sistema. |
| **Resplandor** | Una luz de color detrás del total del mes, que toma el color de la categoría donde más gastaste. |
| **Vidrio** | Superficies translúcidas, con desenfoque real solo donde rinde (barra de navegación y hojas). |
| **Motion con física** | Springs interrumpibles y transiciones compartidas: nada aparece de la nada. |
| **Haptics** | Un toque leve por tecla, uno firme al guardar. Confirman sin interrumpir. |
| **120 fps** | Las transiciones se miden en un dispositivo real con `dumpsys gfxinfo`, no a ojo. |

## Privacidad

- **Local-first**: tus datos viven en tu teléfono (SQLite).
- **Backup cifrado** (AES-256-GCM) en una carpeta de **tu propio** Google Drive. La clave sale de una contraseña que solo vos conocés.
- **Sin servidor, sin analíticas, sin publicidad.**

## Stack

**La app**

- **[Flutter](https://flutter.dev) 3.47 + Dart 3.13** — el framework. Dibuja cada píxel con su propio motor (Impeller), lo que permite un diseño 100 % propio y animaciones a 120 fps.
- **[Inter](https://rsms.me/inter/)** — la tipografía, incluida dentro de la app. Con cifras tabulares: todos los dígitos miden lo mismo, así los montos no "bailan" mientras escribís.

**Datos**

- **[Drift](https://drift.simonbinder.eu)** — base de datos SQLite tipada y reactiva. Guarda gastos, categorías y presupuestos, y avisa sola a cada pantalla cuando algo cambia.
- **[uuid](https://pub.dev/packages/uuid)** — identificadores únicos para cada registro; facilitan backups y una futura sincronización.

**Estado**

- **[Riverpod](https://riverpod.dev)** — conecta los datos con las pantallas: el total del inicio "escucha" a la base y se actualiza solo al cargar un gasto.

**Fechas y formatos**

- **[timezone](https://pub.dev/packages/timezone) + [flutter_timezone](https://pub.dev/packages/flutter_timezone)** — toman la zona horaria del teléfono, para que un gasto de las 23:30 caiga en el día correcto aunque internamente se guarde en UTC.
- **[intl](https://pub.dev/packages/intl)** — fechas en español ("Viernes 17 de octubre").

**Desarrollo y calidad**

- **[build_runner](https://pub.dev/packages/build_runner) + drift_dev + riverpod_generator** — generan el código repetitivo (consultas tipadas, providers) para no escribirlo a mano.
- **[flutter_test](https://docs.flutter.dev/testing) + [mocktail](https://pub.dev/packages/mocktail)** — tests unitarios, de base de datos y de widgets. La lógica de fechas y montos se escribe con tests primero.
- **`dumpsys gfxinfo`** — medición real de frames en el dispositivo para sostener los 120 fps.

**Próximamente**

- **flutter_local_notifications** — recordatorios y alertas de presupuesto.
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
| **Plan 2** | Presupuestos, recurrentes, esquema de cobro, bandeja de sugeridos, Ajustes | 🚧 7 de 9 tareas |
| **Plan 3** | Reportes, recordatorios, widget y acceso rápido | ⏳ |
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

Los archivos sensibles (keystores, credenciales de Google) están excluidos por `.gitignore` y nunca forman parte del repositorio.
