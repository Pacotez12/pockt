import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:intl/intl.dart';
import 'package:pockt/features/backup/domain/backup_service.dart';
import 'package:pockt/features/backup/ui/backup_screen.dart';
import 'package:pockt/features/income/ui/income_schedule_screen.dart';
import 'package:pockt/features/recurring/ui/recurring_screen.dart';
import 'package:pockt/features/reminders/ui/reminders_screen.dart';
import 'package:pockt/features/settings/ui/appearance_screen.dart';
import 'package:pockt/features/settings/ui/category_keywords_screen.dart';
import 'package:pockt/features/security/app_lock.dart';

/// Hub principal de Ajustes (spec §5.10):
/// Categorías · Esquema de cobro · Recurrentes
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final scheduleAsync = ref.watch(incomeScheduleRepositoryProvider).watchCurrent();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.glassFill,
                        border: Border.all(color: colors.glassBorder),
                      ),
                      child: Center(
                        child: Icon(
                          uiIcon('arrow-left'),
                          size: 18,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ajustes',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Preferencias y configuración',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _SettingsTile(
                    key: const ValueKey('settings-categories-tile'),
                    icon: 'tag',
                    title: 'Categorías',
                    subtitle: 'Personalizar y palabras clave',
                    iconColor: colors.brandStart,
                    onTap: () {
                      Haptics.tick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CategoryKeywordsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder(
                    stream: scheduleAsync,
                    builder: (context, snapshot) {
                      final schedule = snapshot.data;
                      final subtitle = schedule != null
                          ? (schedule.mode == 'biweekly' ? 'Quincenal' : 'Mensual')
                          : 'Configurar cuándo cobrás';

                      return _SettingsTile(
                        key: const ValueKey('settings-income-schedule-tile'),
                        icon: 'calendar',
                        title: 'Esquema de cobro',
                        subtitle: subtitle,
                        iconColor: colors.positive,
                        onTap: () {
                          Haptics.tick();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const IncomeScheduleScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    key: const ValueKey('settings-recurring-tile'),
                    icon: 'sparkle',
                    title: 'Recurrentes',
                    subtitle: 'Gastos fijos y suscripciones',
                    iconColor: colors.brandEnd,
                    onTap: () {
                      Haptics.tick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RecurringScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (context, ref, _) {
                      final appearanceAsync = ref.watch(appearanceProvider);
                      final mode = appearanceAsync.value ?? ThemeMode.system;
                      final subtitle = switch (mode) {
                        ThemeMode.dark => 'Oscuro',
                        ThemeMode.light => 'Claro',
                        ThemeMode.system => 'Sistema',
                      };

                      return _SettingsTile(
                        key: const ValueKey('settings-appearance-tile'),
                        icon: 'paint-brush',
                        title: 'Apariencia',
                        subtitle: subtitle,
                        iconColor: colors.brandStart,
                        onTap: () {
                          Haptics.tick();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AppearanceScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (context, ref, _) {
                      final repo = ref.watch(settingsRepositoryProvider);
                      return StreamBuilder<String?>(
                        stream: repo.watch(SettingsKeys.remindersIntensity),
                        builder: (context, snapshot) {
                          final intensity = snapshot.data ?? 'normal';
                          final subtitle = switch (intensity) {
                            'off' => 'Apagado',
                            'soft' => 'Suave (21:00)',
                            'insistent' => 'Insistente',
                            _ => 'Normal (13:00 y 21:00)',
                          };

                          return _SettingsTile(
                            key: const ValueKey('settings-reminders-tile'),
                            icon: 'bell',
                            title: 'Recordatorios',
                            subtitle: subtitle,
                            iconColor: colors.warning,
                            onTap: () {
                              Haptics.tick();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RemindersScreen(),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (context, ref, _) {
                      final service = ref.watch(backupServiceProvider);
                      return StreamBuilder<BackupStatus>(
                        stream: service.watchStatus(),
                        builder: (context, snapshot) {
                          final status = snapshot.data;
                          final subtitle = status?.lastSuccessAt != null
                              ? 'Último: ${DateFormat('dd/MM/yyyy').format(status!.lastSuccessAt!)}'
                              : 'Respaldo automático y cifrado';

                          return _SettingsTile(
                            key: const ValueKey('settings-backup-tile'),
                            icon: 'cloud-arrow-up',
                            title: 'Copia de seguridad',
                            subtitle: subtitle,
                            iconColor: colors.brandEnd,
                            onTap: () {
                              Haptics.tick();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const BackupScreen(),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  const _LockSettingsTile(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Pressable(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: isDark ? 0.16 : 0.12),
              ),
              child: Center(
                child: Icon(
                  uiIcon(icon),
                  size: 18,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              uiIcon('caret-right'),
              size: 16,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _LockSettingsTile extends ConsumerStatefulWidget {
  const _LockSettingsTile();

  @override
  ConsumerState<_LockSettingsTile> createState() => _LockSettingsTileState();
}

class _LockSettingsTileState extends ConsumerState<_LockSettingsTile> {
  AppLockAvailability? _availability;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final controller = ref.read(appLockControllerProvider);
    final avail = await controller.availability();
    if (mounted) {
      setState(() {
        _availability = avail;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final controller = ref.watch(appLockControllerProvider);
    final isEnabled = controller.isLockEnabled;

    final isReady = _availability == AppLockAvailability.ready;
    final isNoDeviceLock = _availability == AppLockAvailability.noDeviceLock;
    final isUnsupported = _availability == AppLockAvailability.unsupported;

    final String subtitle;
    if (_availability == null) {
      subtitle = 'Comprobando seguridad...';
    } else if (isNoDeviceLock) {
      subtitle = 'El dispositivo no tiene bloqueo configurado (PIN, patrón o huella)';
    } else if (isUnsupported) {
      subtitle = 'No soportado en este dispositivo';
    } else if (isEnabled) {
      subtitle = 'Activo (huella o PIN)';
    } else {
      subtitle = 'Pedir huella o PIN al abrir la app';
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.brandStart.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                uiIcon('fingerprint'),
                size: 20,
                color: colors.brandStart,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bloqueo con huella',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: isNoDeviceLock ? colors.warning : colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: const ValueKey('settings-lock-switch'),
            value: isEnabled,
            onChanged: isReady
                ? (val) async {
                    Haptics.tick();
                    await controller.setLockEnabled(val);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
