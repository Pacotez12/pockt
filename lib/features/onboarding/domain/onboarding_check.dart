import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/settings/settings_repository.dart';

/// Provider que indica si la app corre en modo demo.
final isDemoModeProvider = Provider<bool>((ref) {
  return const bool.fromEnvironment('POCKT_DEMO');
});

/// Determina si se debe mostrar la experiencia de primer uso (Plan 4 Task 7 / spec §5.11).
///
/// Reglas:
/// - Si corre en modo demo ([isDemo] es true), NUNCA se muestra.
/// - Si el ajuste `onboarding.done` ya es 'true', NO se muestra.
/// - Si la base tiene CUALQUIER movimiento, meta, préstamo o esquema de cobro
///   existente (datos reales del usuario), NUNCA se muestra y se marca `onboarding.done = true`.
/// - Solo se muestra en una base completamente limpia y sin datos previos.
Future<bool> checkShouldShowOnboarding({
  required AppDatabase db,
  required SettingsRepository settings,
  bool isDemo = false,
}) async {
  if (isDemo) return false;

  final done = await settings.get(SettingsKeys.onboardingDone);
  if (done == 'true') return false;

  final txCount =
      await (db.selectOnly(db.transactions)
            ..addColumns([db.transactions.id.count()]))
          .getSingle()
          .then((r) => r.read(db.transactions.id.count()) ?? 0);
  if (txCount > 0) {
    await settings.set(SettingsKeys.onboardingDone, 'true');
    return false;
  }

  final goalCount =
      await (db.selectOnly(db.goals)..addColumns([db.goals.id.count()]))
          .getSingle()
          .then((r) => r.read(db.goals.id.count()) ?? 0);
  if (goalCount > 0) {
    await settings.set(SettingsKeys.onboardingDone, 'true');
    return false;
  }

  final loanCount =
      await (db.selectOnly(db.loans)..addColumns([db.loans.id.count()]))
          .getSingle()
          .then((r) => r.read(db.loans.id.count()) ?? 0);
  if (loanCount > 0) {
    await settings.set(SettingsKeys.onboardingDone, 'true');
    return false;
  }

  final schedCount =
      await (db.selectOnly(db.incomeSchedules)
            ..addColumns([db.incomeSchedules.id.count()]))
          .getSingle()
          .then((r) => r.read(db.incomeSchedules.id.count()) ?? 0);
  if (schedCount > 0) {
    await settings.set(SettingsKeys.onboardingDone, 'true');
    return false;
  }

  return true;
}

/// Provider reactivo para decidir si mostrar la pantalla de bienvenida / primer uso.
final shouldShowOnboardingProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(databaseProvider);
  final settings = ref.watch(settingsRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  return checkShouldShowOnboarding(db: db, settings: settings, isDemo: isDemo);
});
