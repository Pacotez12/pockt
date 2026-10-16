import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/time/date_period.dart';

export 'package:pockt/core/time/date_period.dart';

/// Nombres de claves canónicas en la tabla `settings` (Plan 3 Global Constraints).
abstract class SettingsKeys {
  static const appearance = 'appearance';
  static const remindersIntensity = 'reminders.intensity';
  static const remindersQuietStart = 'reminders.quietStart';
  static const remindersQuietEnd = 'reminders.quietEnd';
  static const backupLastSuccessAt = 'backup.lastSuccessAt';
  static const backupLastError = 'backup.lastError';
  static const backupFolderName = 'backup.folderName';
  static const securityLock = 'security.lock';
  static const periodMonthStart = 'period.monthStart';

  // Carga (§7b)
  static const entryCategoryOrder = 'entry.categoryOrder';
  static const entryQuickKey = 'entry.quickKey';
  static const entryAskNote = 'entry.askNote';
  static const feedbackHaptics = 'feedback.haptics';

  // Inicio y apariencia (§7b)
  static const homeCards = 'home.cards';
  static const homeHeadline = 'home.headline';
  static const homeRecentCount = 'home.recentCount';
  static const glowMode = 'glow.mode';
  static const glowReactsToBudget = 'glow.reactsToBudget';
  static const calendarWeekStart = 'calendar.weekStart';
  static const motionReduce = 'motion.reduce';

  // Avisos (§7b)
  static const budgetAlertsEnabled = 'budget.alertsEnabled';
  static const budgetAlertLow = 'budget.alertLow';
  static const budgetAlertHigh = 'budget.alertHigh';
  static const toneLevel = 'tone.level';
  static const weeklySummaryEnabled = 'reminders.weeklySummary';

  // Privacidad y datos (§7b)
  static const securityLockAfter = 'security.lockAfter';
  static const privacyHideAmounts = 'privacy.hideAmounts';

  // Reportes (§7d)
  static const reportsAntThreshold = 'reports.antThreshold';

  // Primer uso (Plan 4 Task 7 / §5.11)
  static const onboardingDone = 'onboarding.done';

  // Captura automática de SMS (Plan 7 / spec §5)
  static const captureSmsEnabled = 'capture.smsEnabled';
  static const captureSince = 'capture.since';
  static const captureLastSmsAt = 'capture.lastSmsAt';
  static const captureUnrecognizedCount = 'capture.unrecognizedCount';
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
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion(key: Value(key), value: Value(value)),
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

/// Proveedor reactivo del modo de inicio de mes ('calendar' | 'payday').
final monthStartModeProvider = StreamProvider<MonthStartMode>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo
      .watch(SettingsKeys.periodMonthStart)
      .map((val) => MonthStartMode.parse(val));
});

/// Orden de categorías en el flujo de carga (§7b Carga).
enum CategoryOrder {
  mostUsed,
  manual;

  static CategoryOrder parse(String? value) {
    if (value == 'mostUsed') return CategoryOrder.mostUsed;
    return CategoryOrder.manual;
  }
}

/// Modo de resplandor ambiental aurora (§7b Inicio y apariencia).
enum GlowMode {
  off,
  subtle,
  full;

  static GlowMode parse(String? value) {
    switch (value) {
      case 'off':
        return GlowMode.off;
      case 'full':
        return GlowMode.full;
      case 'subtle':
      default:
        return GlowMode.subtle;
    }
  }
}

/// Primer día de la semana (§7b Inicio y apariencia).
enum WeekStart {
  monday,
  sunday;

  static WeekStart parse(String? value) {
    if (value == 'sunday') return WeekStart.sunday;
    return WeekStart.monday;
  }
}

final categoryOrderProvider = StreamProvider<CategoryOrder>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watch(SettingsKeys.entryCategoryOrder).map(CategoryOrder.parse);
});

final quickKeyProvider = StreamProvider<String>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo
      .watch(SettingsKeys.entryQuickKey)
      .map((val) => val == '00' ? '00' : '000');
});

final askNoteProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watch(SettingsKeys.entryAskNote).map((val) => val == 'true');
});

final hapticsEnabledProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watch(SettingsKeys.feedbackHaptics).map((val) {
    final enabled = val == null ? true : (val == 'true');
    Haptics.enabled = enabled;
    return enabled;
  });
});

final homeCardsProvider = StreamProvider<String?>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watch(SettingsKeys.homeCards);
});

final recentCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watch(SettingsKeys.homeRecentCount).map((val) {
    final n = int.tryParse(val ?? '');
    if (n == 10 || n == 20) return n!;
    return 5;
  });
});

final glowModeProvider = StreamProvider<GlowMode>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watch(SettingsKeys.glowMode).map(GlowMode.parse);
});

final glowReactsToBudgetProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo
      .watch(SettingsKeys.glowReactsToBudget)
      .map((val) => val == null ? true : val == 'true');
});

final weekStartProvider = StreamProvider<WeekStart>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watch(SettingsKeys.calendarWeekStart).map(WeekStart.parse);
});

final motionReduceProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watch(SettingsKeys.motionReduce).map((val) => val == 'true');
});

final budgetAlertsEnabledProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo
      .watch(SettingsKeys.budgetAlertsEnabled)
      .map((val) => val == null || val.isEmpty || val == 'true');
});

final budgetAlertLowProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo
      .watch(SettingsKeys.budgetAlertLow)
      .map((val) => int.tryParse(val ?? '') ?? 80);
});

final budgetAlertHighProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo
      .watch(SettingsKeys.budgetAlertHigh)
      .map((val) => int.tryParse(val ?? '') ?? 100);
});

final securityLockAfterProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo
      .watch(SettingsKeys.securityLockAfter)
      .map((val) => int.tryParse(val ?? '') ?? 1);
});

final privacyHideAmountsProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo
      .watch(SettingsKeys.privacyHideAmounts)
      .map((val) => val == 'true');
});

enum HomeHeadline {
  safeToSpend,
  monthSpent;

  static HomeHeadline parse(String? raw) {
    if (raw == 'monthSpent') return HomeHeadline.monthSpent;
    return HomeHeadline.safeToSpend;
  }
}

final homeHeadlineProvider = StreamProvider<HomeHeadline>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watch(SettingsKeys.homeHeadline).map(HomeHeadline.parse);
});

final reportsAntThresholdProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo
      .watch(SettingsKeys.reportsAntThreshold)
      .map((val) => int.tryParse(val ?? '') ?? 30000);
});

final weeklySummaryEnabledProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo
      .watch(SettingsKeys.weeklySummaryEnabled)
      .map((val) => val == null || val == 'true');
});

final captureSmsEnabledProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watch(SettingsKeys.captureSmsEnabled).map((val) => val == 'true');
});

final captureSinceProvider = StreamProvider<DateTime>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watch(SettingsKeys.captureSince).map((val) {
    final parsed = val != null ? DateTime.tryParse(val) : null;
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    return DateTime(2026, 10, 15);
  });
});

final captureLastSmsAtProvider = StreamProvider<DateTime?>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo
      .watch(SettingsKeys.captureLastSmsAt)
      .map((val) => val != null ? DateTime.tryParse(val) : null);
});

final captureUnrecognizedCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo
      .watch(SettingsKeys.captureUnrecognizedCount)
      .map((val) => int.tryParse(val ?? '') ?? 0);
});
