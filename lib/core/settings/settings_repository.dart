import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';

/// Nombres de claves canónicas en la tabla `settings` (Plan 3 Global Constraints).
abstract class SettingsKeys {
  static const appearance = 'appearance';
  static const remindersIntensity = 'reminders.intensity';
  static const remindersQuietStart = 'reminders.quietStart';
  static const remindersQuietEnd = 'reminders.quietEnd';
}

/// Repositorio clave-valor tipado sobre la tabla `settings` de Drift.
class SettingsRepository {
  final AppDatabase _db;

  SettingsRepository(this._db);

  /// Emite el valor actual de [key] y reacciona reactivamente a cualquier cambio.
  Stream<String?> watch(String key) {
    final query = _db.select(_db.settings)..where((t) => t.key.equals(key));
    return query.watchSingleOrNull().map((row) => row?.value);
  }

  /// Obtiene el valor puntual de [key].
  Future<String?> get(String key) async {
    final query = _db.select(_db.settings)..where((t) => t.key.equals(key));
    final row = await query.getSingleOrNull();
    return row?.value;
  }

  /// Guarda o actualiza [key] con [value].
  Future<void> set(String key, String value) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion(
            key: Value(key),
            value: Value(value),
          ),
        );
  }
}

/// Proveedor del repositorio de configuración.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseProvider));
});

/// Proveedor reactivo de apariencia visual (`ThemeMode`).
/// Lee la clave `appearance`:
/// - 'dark' -> ThemeMode.dark
/// - 'light' -> ThemeMode.light
/// - 'system' / null -> ThemeMode.system
final appearanceProvider = StreamProvider<ThemeMode>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watch(SettingsKeys.appearance).map((val) {
    switch (val) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
      default:
        return ThemeMode.system;
    }
  });
});
