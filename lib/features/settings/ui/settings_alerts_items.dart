import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/reminders/ui/reminders_screen.dart';
import 'package:pockt/features/safe_to_spend/domain/tone.dart';
import 'package:pockt/features/settings/ui/settings_tiles.dart';

List<Widget> alertsSettingsItems(BuildContext context, WidgetRef ref) {
  final colors = context.pockt;
  final repo = ref.watch(settingsRepositoryProvider);
  return [
    StreamBuilder<String?>(
      stream: repo.watch(SettingsKeys.remindersIntensity),
      builder: (context, snapshot) {
        final intensity = snapshot.data ?? 'normal';
        final subtitle = switch (intensity) {
          'off' => 'Apagado',
          'soft' => 'Suave (21:00)',
          'insistent' => 'Insistente',
          _ => 'Normal (13:00 y 21:00)',
        };
        return SettingsTile(
          key: const ValueKey('settings-reminders-tile'),
          icon: 'bell',
          title: 'Recordatorios',
          subtitle: subtitle,
          iconColor: colors.brandAt(3),
          onTap: () {
            Haptics.tick();
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RemindersScreen()));
          },
        );
      },
    ),
    SettingsSwitchTile(
      key: const ValueKey('settings-budget-alerts-switch'),
      icon: 'bell-ringing',
      title: 'Alertas de presupuesto',
      subtitle: 'Avisar al acercarse al límite mensual',
      iconColor: colors.brandAt(3),
      value: ref.watch(budgetAlertsEnabledProvider).value ?? true,
      onChanged: (val) =>
          repo.set(SettingsKeys.budgetAlertsEnabled, val.toString()),
    ),
    SettingsSegmentTile<int>(
      key: const ValueKey('settings-alert-low'),
      icon: 'warning',
      title: 'Umbral de advertencia',
      subtitle: 'Porcentaje para el primer aviso',
      iconColor: colors.brandAt(3),
      selectedValue: ref.watch(budgetAlertLowProvider).value ?? 80,
      options: const [
        (value: 70, label: '70 %'),
        (value: 80, label: '80 %'),
        (value: 90, label: '90 %'),
      ],
      onSelected: (val) =>
          repo.set(SettingsKeys.budgetAlertLow, val.toString()),
    ),
    SettingsSegmentTile<int>(
      key: const ValueKey('settings-alert-high'),
      icon: 'warning-octagon',
      title: 'Umbral de límite',
      subtitle: 'Porcentaje para el aviso de exceso',
      iconColor: colors.brandAt(3),
      selectedValue: ref.watch(budgetAlertHighProvider).value ?? 100,
      options: const [
        (value: 100, label: '100 %'),
        (value: 110, label: '110 %'),
      ],
      onSelected: (val) =>
          repo.set(SettingsKeys.budgetAlertHigh, val.toString()),
    ),
    SettingsSegmentTile<ToneLevel>(
      key: const ValueKey('settings-tone-level'),
      icon: 'sparkle',
      title: 'Tono de los avisos',
      subtitle: 'Estilo de los mensajes del simulador ¿Lo compro?',
      iconColor: colors.brandAt(3),
      selectedValue: ref.watch(toneLevelProvider).value ?? ToneLevel.normal,
      options: const [
        (value: ToneLevel.soft, label: 'Suave'),
        (value: ToneLevel.normal, label: 'Normal'),
        (value: ToneLevel.spicy, label: 'Picante'),
      ],
      onSelected: (val) => repo.set(SettingsKeys.toneLevel, val.key),
    ),
    SettingsSwitchTile(
      key: const ValueKey('settings-weekly-summary-switch'),
      icon: 'calendar-check',
      title: 'Resumen semanal',
      subtitle: 'Notificación los domingos 19:00 con el gasto de la semana',
      iconColor: colors.brandAt(3),
      value: ref.watch(weeklySummaryEnabledProvider).value ?? true,
      onChanged: (val) =>
          repo.set(SettingsKeys.weeklySummaryEnabled, val.toString()),
    ),
  ];
}
