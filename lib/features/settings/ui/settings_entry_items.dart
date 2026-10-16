import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/settings/ui/settings_tiles.dart';

List<Widget> entrySettingsItems(BuildContext context, WidgetRef ref) {
  final colors = context.pockt;
  final repo = ref.watch(settingsRepositoryProvider);
  return [
    SettingsSegmentTile<CategoryOrder>(
      key: const ValueKey('settings-category-order'),
      icon: 'sort-ascending',
      title: 'Orden de categorías',
      subtitle: 'Disposición de la grilla de carga',
      iconColor: colors.brandAt(1),
      selectedValue:
          ref.watch(categoryOrderProvider).value ?? CategoryOrder.mostUsed,
      options: const [
        (value: CategoryOrder.mostUsed, label: 'Más usadas'),
        (value: CategoryOrder.manual, label: 'Manual'),
      ],
      onSelected: (val) => repo.set(SettingsKeys.entryCategoryOrder, val.name),
    ),
    SettingsSegmentTile<String>(
      key: const ValueKey('settings-quick-key'),
      icon: 'keyboard',
      title: 'Tecla rápida',
      subtitle: 'Acceso en el teclado numérico',
      iconColor: colors.brandAt(1),
      selectedValue: ref.watch(quickKeyProvider).value ?? '000',
      options: const [(value: '000', label: '000'), (value: '00', label: '00')],
      onSelected: (val) => repo.set(SettingsKeys.entryQuickKey, val),
    ),
    SettingsSwitchTile(
      key: const ValueKey('settings-ask-note-switch'),
      icon: 'note-pencil',
      title: 'Pedir nota al guardar',
      subtitle: 'Muestra campo de nota antes de guardar',
      iconColor: colors.brandAt(1),
      value: ref.watch(askNoteProvider).value ?? false,
      onChanged: (val) => repo.set(SettingsKeys.entryAskNote, val.toString()),
    ),
    SettingsSwitchTile(
      key: const ValueKey('settings-haptics-switch'),
      icon: 'waveform',
      title: 'Vibración',
      subtitle: 'Respuesta táctil al presionar botones',
      iconColor: colors.brandAt(1),
      value: ref.watch(hapticsEnabledProvider).value ?? true,
      onChanged: (val) =>
          repo.set(SettingsKeys.feedbackHaptics, val.toString()),
    ),
  ];
}
