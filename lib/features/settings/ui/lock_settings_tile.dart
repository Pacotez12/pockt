import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/security/app_lock.dart';
import 'package:pockt/features/settings/ui/settings_tiles.dart';

class LockSettingsTile extends ConsumerStatefulWidget {
  const LockSettingsTile({super.key});

  @override
  ConsumerState<LockSettingsTile> createState() => LockSettingsTileState();
}

class LockSettingsTileState extends ConsumerState<LockSettingsTile> {
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
      subtitle =
          'El dispositivo no tiene bloqueo configurado (PIN, patrón o huella)';
    } else if (isUnsupported) {
      subtitle = 'No soportado en este dispositivo';
    } else if (isEnabled) {
      subtitle = 'Activo (huella o PIN)';
    } else {
      subtitle = 'Pedir huella o PIN al abrir la app';
    }

    return SettingsTileShell(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.brandAt(3).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(PocktRadii.m),
            ),
            child: Center(
              child: Icon(
                uiIcon('fingerprint'),
                size: 20,
                color: colors.brandAt(3),
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
                    color: isNoDeviceLock
                        ? colors.warning
                        : colors.textTertiary,
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
