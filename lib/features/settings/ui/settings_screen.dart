import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/settings/ui/settings_alerts_items.dart';
import 'package:pockt/features/settings/ui/settings_entry_items.dart';
import 'package:pockt/features/settings/ui/settings_home_items.dart';
import 'package:pockt/features/settings/ui/settings_money_items.dart';
import 'package:pockt/features/settings/ui/settings_privacy_items.dart';
import 'package:pockt/features/settings/ui/settings_section_page.dart';
import 'package:pockt/features/settings/ui/settings_tiles.dart';

export 'package:pockt/features/settings/ui/about_pockt_dialog.dart';
export 'package:pockt/features/settings/ui/lock_settings_tile.dart';
export 'package:pockt/features/settings/ui/settings_section_page.dart';
export 'package:pockt/features/settings/ui/settings_tiles.dart';
export 'package:pockt/features/settings/ui/wipe_data_dialog.dart';

/// Hub principal de Ajustes (spec §7b).
/// Organizado en cinco secciones con tarjetas de vidrio y controles en línea:
/// 1. Tu dinero
/// 2. Carga
/// 3. Inicio y apariencia
/// 4. Avisos
/// 5. Privacidad y datos
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Pressable(
                    semanticLabel: 'Volver',
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
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  SettingsGroup(
                    children: [
                      SettingsSectionEntry(
                        key: const ValueKey('settings-section-money'),
                        icon: 'coins',
                        title: 'Tu dinero',
                        subtitle: 'Sueldo, inicio del mes, categorías, recurrentes y préstamos',
                        color: colors.brandAt(0),
                        builder: moneySettingsItems,
                      ),
                      SettingsSectionEntry(
                        key: const ValueKey('settings-section-entry'),
                        icon: 'keyboard',
                        title: 'Carga',
                        subtitle: 'Orden de categorías, tecla rápida, nota y vibración',
                        color: colors.brandAt(1),
                        builder: entrySettingsItems,
                      ),
                      SettingsSectionEntry(
                        key: const ValueKey('settings-section-home'),
                        icon: 'paint-brush',
                        title: 'Inicio y apariencia',
                        subtitle:
                            'Tema, tarjetas, aurora, semana y animaciones',
                        color: colors.brandAt(2),
                        builder: homeSettingsItems,
                      ),
                      SettingsSectionEntry(
                        key: const ValueKey('settings-section-alerts'),
                        icon: 'bell',
                        title: 'Avisos',
                        subtitle: 'Recordatorios y alertas de presupuesto',
                        color: colors.brandAt(3),
                        builder: alertsSettingsItems,
                      ),
                      SettingsSectionEntry(
                        key: const ValueKey('settings-section-privacy'),
                        icon: 'lock',
                        title: 'Privacidad y datos',
                        subtitle: 'Bloqueo, montos ocultos, copias, exportar y borrar',
                        color: colors.brandAt(3),
                        builder: privacySettingsItems,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
