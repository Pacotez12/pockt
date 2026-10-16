import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/backup/domain/backup_service.dart';
import 'package:pockt/features/backup/ui/backup_screen.dart';
import 'package:pockt/features/security/app_lock.dart';
import 'package:pockt/features/settings/domain/export_csv.dart';
import 'package:pockt/features/settings/ui/settings_tiles.dart';
import 'package:pockt/features/settings/ui/wipe_data_dialog.dart';
import 'package:pockt/features/settings/ui/about_pockt_dialog.dart';
import 'package:pockt/features/settings/ui/lock_settings_tile.dart';

List<Widget> privacySettingsItems(BuildContext context, WidgetRef ref) {
  final colors = context.pockt;
  final repo = ref.watch(settingsRepositoryProvider);
  return [
    const LockSettingsTile(),
    SettingsSegmentTile<int>(
      key: const ValueKey('settings-lock-after'),
      icon: 'timer',
      title: 'Tiempo hasta bloquear',
      subtitle: 'Espera en segundo plano antes de pedir huella',
      iconColor: colors.brandAt(3),
      selectedValue: ref.watch(securityLockAfterProvider).value ?? 1,
      options: const [
        (value: 0, label: 'Al instante'),
        (value: 1, label: '1 min'),
        (value: 5, label: '5 min'),
        (value: 15, label: '15 min'),
      ],
      onSelected: (val) =>
          ref.read(appLockControllerProvider).setLockAfter(val),
    ),
    SettingsSwitchTile(
      key: const ValueKey('settings-hide-amounts-switch'),
      icon: 'eye-slash',
      title: 'Ocultar montos',
      subtitle: 'Muestra •••• hasta tocar el total',
      iconColor: colors.brandAt(3),
      value: ref.watch(privacyHideAmountsProvider).value ?? false,
      onChanged: (val) =>
          repo.set(SettingsKeys.privacyHideAmounts, val.toString()),
    ),
    StreamBuilder<BackupStatus>(
      stream: ref.watch(backupServiceProvider).watchStatus(),
      builder: (context, snapshot) {
        final status = snapshot.data;
        final isOverdue = status?.isOverdue ?? false;
        final subtitle = status?.lastSuccessAt != null
            ? 'Último: ${DateFormat('dd/MM/yyyy').format(status!.lastSuccessAt!)}'
            : 'Respaldo automático y cifrado';
        return SettingsTile(
          key: const ValueKey('settings-backup-tile'),
          icon: 'cloud-arrow-up',
          title: 'Copia de seguridad',
          subtitle: subtitle,
          iconColor: isOverdue ? colors.warning : colors.brandAt(3),
          onTap: () {
            Haptics.tick();
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const BackupScreen()));
          },
        );
      },
    ),
    SettingsTile(
      key: const ValueKey('settings-export-csv-tile'),
      icon: 'file-csv',
      title: 'Exportar a CSV',
      subtitle: 'Movimientos en formato Excel (; y UTF-8)',
      iconColor: colors.brandAt(3),
      onTap: () async {
        Haptics.tick();
        final txRepo = ref.read(transactionsRepositoryProvider);
        final items = await txRepo.getAllActive();
        await exportAndShareCsv(items);
      },
    ),
    SettingsTile(
      key: const ValueKey('settings-wipe-data-tile'),
      icon: 'trash',
      title: 'Borrar todos los datos',
      subtitle: 'Restablecer movimientos y ajustes a fábrica',
      iconColor: colors.danger,
      onTap: () {
        Haptics.danger();
        showWipeDataDialog(context, ref);
      },
    ),
    SettingsTile(
      key: const ValueKey('settings-about-tile'),
      icon: 'info',
      title: 'Acerca de Pockt',
      subtitle: 'Versión, licencias y código',
      iconColor: colors.brandAt(3),
      onTap: () {
        Haptics.tick();
        showAboutPocktDialog(context);
      },
    ),
  ];
}
