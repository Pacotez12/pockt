<div align="center">

<img src="docs/brand/pockt-icon-rounded.svg" alt="Pockt" width="128" height="128">

# Pockt

**Tus gastos, en el bolsillo.**
Una app de finanzas personales para Android, rápida para anotar y hermosa de usar.

[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-8.0%2B-3DDC84?logo=android&logoColor=white)](https://www.android.com)
[![Local-first](https://img.shields.io/badge/datos-local--first-FF3D7F)](#privacidad)
[![Estado](https://img.shields.io/badge/estado-en%20desarrollo-FF8A3D)](#estado)

</div>

---

## Qué es Pockt

Pockt nace de una idea simple: si anotar un gasto tarda, dejás de anotarlo. Por eso todo gira alrededor de cargar un gasto en **tres toques**, y de que mirar tus finanzas sea algo que *querés* hacer.

- **Categoría primero.** Tocás la burbuja de la categoría, se transforma en el teclado con su color, ponés el monto y listo.
- **Texto natural.** Escribís `super 230 mil ayer` o `bolt 28.500` y Pockt lo entiende.
- **Tus días, a la vista.** Un calendario de calor del mes, al estilo de las contribuciones de GitHub, que muestra en qué días gastaste más. Tocás un día y ves en qué se fue.
- **Presupuestos por categoría** con avisos al 80 % y al 100 %.
- **Recurrentes y cobros** (quincenales o mensuales) que te esperan en una bandeja para confirmar, sin cargarse a ciegas.
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

| Pieza | Para qué |
|---|---|
| [Flutter](https://flutter.dev) / Dart | UI y lógica de la app |
| [Drift](https://drift.simonbinder.eu) | Base de datos SQLite tipada y reactiva |
| [Riverpod](https://riverpod.dev) | Estado y conexión entre datos y pantallas |
| [timezone](https://pub.dev/packages/timezone) | Fechas por día local correcto |
| [intl](https://pub.dev/packages/intl) | Formatos de fecha y número |
| [Inter](https://rsms.me/inter/) | Tipografía, con cifras tabulares |

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
| **Plan 1** | Base, carga de gastos, inicio, calendario de calor, movimientos | 🚧 en curso |
| **Plan 2** | Presupuestos, recurrentes, esquema de cobro, bandeja de sugeridos | ⏳ |
| **Plan 3** | Reportes, recordatorios, widget y acceso rápido | ⏳ |
| **Plan 4** | Backup cifrado, restauración, bloqueo con huella, primer uso | ⏳ |
| **Después** | Motor de captura: leer notificaciones de bancos, SMS y correos | 💡 |

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
