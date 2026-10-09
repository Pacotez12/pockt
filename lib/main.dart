import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/app.dart';
import 'package:pockt/core/background/background_tasks.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/demo/demo_seed.dart';
import 'package:timezone/data/latest.dart' as tz;

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await initLocalZone();
  await initBackgroundTasks();

  AppDatabase? demoDb;
  if (const bool.fromEnvironment('POCKT_DEMO')) {
    demoDb = AppDatabase();
    await seedDemoData(demoDb, nowLocal: DateTime.now());
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
