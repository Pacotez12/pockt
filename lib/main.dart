import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/app.dart';
import 'package:pockt/core/background/background_tasks.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/demo/demo_seed.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await initLocalZone();
  await initBackgroundTasks();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('No se pudo inicializar Supabase: $e');
    }
  }

  AppDatabase? demoDb;
  if (const bool.fromEnvironment('POCKT_DEMO')) {
    demoDb = AppDatabase();
    // En la primera apertura la tarea de fondo puede bloquear la base un
    // instante: si la carga de ejemplo falla, se reintenta una vez y, si no,
    // la app arranca igual (antes quedaba la pantalla en negro).
    try {
      await seedDemoData(demoDb, nowLocal: DateTime.now());
    } catch (_) {
      await Future<void>.delayed(const Duration(seconds: 1));
      try {
        await seedDemoData(demoDb, nowLocal: DateTime.now());
      } catch (_) {}
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        if (demoDb != null) databaseProvider.overrideWithValue(demoDb),
      ],
      child: const PocktApp(),
    ),
  );
}

void main() async {
  await bootstrap();
}
