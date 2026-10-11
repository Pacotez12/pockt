// flutter drive --profile --no-dds -P pocktPerf=true --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart -d <device>
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pockt/app.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/home/ui/heat_calendar.dart';
import 'package:pockt/features/splash/ui/pockt_splash.dart';
import 'package:timezone/data/latest.dart' as tz;

Future<void> settle(
  WidgetTester t, [
  Duration d = const Duration(milliseconds: 900),
]) async {
  const step = Duration(milliseconds: 16);
  var elapsed = Duration.zero;
  while (elapsed < d) {
    await t.pump(step);
    elapsed += step;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Captura todos los frames reales (no solo los de cada pump).
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('medicion de rendimiento por escenario', (tester) async {
    // Base en memoria: la medición corre en el teléfono real y no debe
    // escribir datos de prueba en la base real del usuario.
    tz.initializeTimeZones();
    await initLocalZone();
    final db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );

    // Warm-up inicial previo para compilar shaders y pipelines de Vulkan/Impeller
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const PocktApp(),
    ));
    await settle(tester, const Duration(milliseconds: 1200));

    // 1. Escenario: apertura (arranque con la animación del orbe y logotipo)
    PocktSplash.resetForTesting();
    await binding.traceAction(
      () async {
        await tester.pumpWidget(ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: PocktApp(key: UniqueKey()),
        ));
        await settle(tester, const Duration(milliseconds: 1200));
      },
      reportKey: 'apertura',
    );

    // 2. Escenario: carga (＋ → categoría → teclado → guardar)
    await binding.traceAction(
      () async {
        final plusButton = find.byKey(const ValueKey('shell-plus-button'));
        await tester.tap(plusButton);
        await settle(tester, const Duration(milliseconds: 400));

        final categoryBubble = find.text('Comida');
        await tester.tap(categoryBubble);
        await settle(tester, const Duration(milliseconds: 400));

        await tester.tap(find.text('2'));
        await settle(tester, const Duration(milliseconds: 100));
        await tester.tap(find.text('5'));
        await settle(tester, const Duration(milliseconds: 100));
        await tester.tap(find.text('000'));
        await settle(tester, const Duration(milliseconds: 100));

        final saveButton = find.text('Guardar');
        await tester.tap(saveButton);
        await settle(tester, const Duration(milliseconds: 600));
      },
      reportKey: 'carga',
    );

    // 3. Escenario: detalle_dia (tocar día y cerrar)
    await binding.traceAction(
      () async {
        final dayCell = find.text('1');
        await tester.tap(dayCell);
        await settle(tester, const Duration(milliseconds: 400));

        // Cerrar la hoja de detalle tocando el fondo exterior
        await tester.tapAt(const Offset(20, 20));
        await settle(tester, const Duration(milliseconds: 400));
      },
      reportKey: 'detalle_dia',
    );

    // 4. Escenario: cambio_mes (deslizar 3 meses)
    await binding.traceAction(
      () async {
        final calendarArea = find.byType(HeatCalendar);
        for (var i = 0; i < 3; i++) {
          await tester.drag(calendarArea, const Offset(-300, 0));
          await settle(tester, const Duration(milliseconds: 400));
        }
      },
      reportKey: 'cambio_mes',
    );

    // 5. Escenario: reportes (abrir Reportes y deslizar las 4 vistas)
    await binding.traceAction(
      () async {
        final reportesTab = find.text('Reportes');
        await tester.tap(reportesTab);
        await settle(tester, const Duration(milliseconds: 400));

        final reportsPageView = find.byType(PageView);
        for (var i = 0; i < 3; i++) {
          await tester.drag(reportsPageView, const Offset(-400, 0));
          await settle(tester, const Duration(milliseconds: 400));
        }

        // Volver a la pestaña Inicio
        final inicioTab = find.text('Inicio');
        await tester.tap(inicioTab);
        await settle(tester, const Duration(milliseconds: 400));
      },
      reportKey: 'reportes',
    );

    // 6. Escenario: scroll_inicio (scroll del Inicio con la barra de vidrio encima)
    await binding.traceAction(
      () async {
        final scrollable = find.byType(SingleChildScrollView);
        await tester.drag(scrollable, const Offset(0, -350));
        await settle(tester, const Duration(milliseconds: 600));
        await tester.drag(scrollable, const Offset(0, 350));
        await settle(tester, const Duration(milliseconds: 600));
      },
      reportKey: 'scroll_inicio',
    );
  });
}
