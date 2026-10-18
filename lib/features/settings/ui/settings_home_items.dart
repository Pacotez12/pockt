import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/home/ui/home_cards_screen.dart';
import 'package:pockt/features/settings/ui/appearance_screen.dart';
import 'package:pockt/features/settings/ui/settings_tiles.dart';

List<Widget> homeSettingsItems(BuildContext context, WidgetRef ref) {
  final colors = context.pockt;
  final repo = ref.watch(settingsRepositoryProvider);
  return [
    Consumer(
      builder: (context, ref, _) {
        final appearanceAsync = ref.watch(appearanceProvider);
        final mode = appearanceAsync.value ?? ThemeMode.system;
        final subtitle = switch (mode) {
          ThemeMode.dark => 'Oscuro',
          ThemeMode.light => 'Claro',
          ThemeMode.system => 'Sistema',
        };
        return SettingsTile(
          key: const ValueKey('settings-appearance-tile'),
          icon: 'paint-brush',
          title: 'Apariencia',
          subtitle: subtitle,
          iconColor: colors.brandAt(2),
          onTap: () {
            Haptics.tick();
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AppearanceScreen()));
          },
        );
      },
    ),
    SettingsTile(
      key: const ValueKey('settings-home-cards-tile'),
      icon: 'cards',
      title: 'Tarjetas del Inicio',
      subtitle: 'Reordenar arrastrando y ocultar',
      iconColor: colors.brandAt(2),
      onTap: () {
        Haptics.tick();
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const HomeCardsScreen()));
      },
    ),
    SettingsSegmentTile<HomeHeadline>(
      key: const ValueKey('settings-home-headline'),
      icon: 'gauge',
      title: 'Número principal',
      subtitle: 'Información destacada en la portada',
      iconColor: colors.brandAt(2),
      selectedValue:
          ref.watch(homeHeadlineProvider).value ?? HomeHeadline.monthSpent,
      options: const [
        (value: HomeHeadline.safeToSpend, label: 'Podés gastar hoy'),
        (value: HomeHeadline.monthSpent, label: 'Gastado en el mes'),
      ],
      onSelected: (val) => repo.set(SettingsKeys.homeHeadline, val.name),
    ),
    SettingsSegmentTile<int>(
      key: const ValueKey('settings-recent-count'),
      icon: 'list-numbers',
      title: 'Movimientos recientes',
      subtitle: 'Cantidad mostrada en el Inicio',
      iconColor: colors.brandAt(2),
      selectedValue: ref.watch(recentCountProvider).value ?? 5,
      options: const [
        (value: 5, label: '5'),
        (value: 10, label: '10'),
        (value: 20, label: '20'),
      ],
      onSelected: (val) =>
          repo.set(SettingsKeys.homeRecentCount, val.toString()),
    ),
    SettingsSegmentTile<GlowMode>(
      key: const ValueKey('settings-glow-mode'),
      icon: 'sun',
      title: 'Resplandor aurora',
      subtitle: 'Intensidad del resplandor de fondo',
      iconColor: colors.brandAt(2),
      selectedValue: ref.watch(glowModeProvider).value ?? GlowMode.subtle,
      options: const [
        (value: GlowMode.off, label: 'Apagada'),
        (value: GlowMode.subtle, label: 'Sutil'),
        (value: GlowMode.full, label: 'Plena'),
      ],
      onSelected: (mode) => repo.set(SettingsKeys.glowMode, mode.name),
    ),
    SettingsSwitchTile(
      key: const ValueKey('settings-glow-reacts-switch'),
      icon: 'gauge',
      title: 'Aurora reacciona al presupuesto',
      subtitle: 'Vira a ámbar o rojo según el gasto',
      iconColor: colors.brandAt(2),
      value: ref.watch(glowReactsToBudgetProvider).value ?? true,
      onChanged: (val) =>
          repo.set(SettingsKeys.glowReactsToBudget, val.toString()),
    ),
    SettingsSegmentTile<WeekStart>(
      key: const ValueKey('settings-week-start'),
      icon: 'calendar-blank',
      title: 'La semana empieza',
      subtitle: 'Primer día en los calendarios',
      iconColor: colors.brandAt(2),
      selectedValue: ref.watch(weekStartProvider).value ?? WeekStart.monday,
      options: const [
        (value: WeekStart.monday, label: 'Lunes'),
        (value: WeekStart.sunday, label: 'Domingo'),
      ],
      onSelected: (val) => repo.set(SettingsKeys.calendarWeekStart, val.name),
    ),
    SettingsSwitchTile(
      key: const ValueKey('settings-motion-reduce-switch'),
      icon: 'film-strip',
      title: 'Reducir animaciones',
      subtitle: 'Desactiva efectos de movimiento en Pockt',
      iconColor: colors.brandAt(2),
      value: ref.watch(motionReduceProvider).value ?? false,
      onChanged: (val) => repo.set(SettingsKeys.motionReduce, val.toString()),
    ),
  ];
}
