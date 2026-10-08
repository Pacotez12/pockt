// flutter drive --profile --no-dds -P pocktPerf=true --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/app.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('medicion de rendimiento de transiciones', (tester) async {
    // Base en memoria: la medición corre en el teléfono real y no debe
    // escribir gastos de prueba en los datos del usuario.
    tz.initializeTimeZones();
    await initLocalZone();
    final db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const PocktApp(),
    ));
    await tester.pumpAndSettle();

    await binding.traceAction(
      () async {
        // 1. Abrir carga (+ en la barra de navegación)
        final plusButton = find.byKey(const ValueKey('shell-plus-button'));
        await tester.tap(plusButton);
        await tester.pumpAndSettle();

        // 2. Tocar categoría (burbuja -> teclado) y guardar
        final categoryBubble = find.text('Comida');
        await tester.tap(categoryBubble);
        await tester.pumpAndSettle();

        await tester.tap(find.text('2'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('5'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('000'));
        await tester.pumpAndSettle();

        final saveButton = find.text('Guardar');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // 3. Tocar un día del calendario (detalle)
        final dayCell = find.text('1');
        await tester.tap(dayCell);
        await tester.pumpAndSettle();

        // Cerrar la hoja de detalle tocando el fondo exterior
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        // 4. Deslizar 3 meses
        final calendarArea = find.text('Tus días');
        for (var i = 0; i < 3; i++) {
          await tester.drag(calendarArea, const Offset(-300, 0));
          await tester.pumpAndSettle();
        }
      },
      reportKey: 'transiciones',
    );
  });
}
