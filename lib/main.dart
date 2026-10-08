import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/app.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:timezone/data/latest.dart' as tz;

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await initLocalZone();
  runApp(const ProviderScope(child: PocktApp()));
}

void main() async {
  await bootstrap();
}
