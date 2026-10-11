import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/design/wordmark.dart';
import 'package:pockt/core/settings/settings_repository.dart';

/// Disponibilidad del bloqueo en el dispositivo (Plan 4, Task 6).
enum AppLockAvailability {
  ready,
  noDeviceLock,
  unsupported,
}

/// Canal de plataforma nativo para controlar FLAG_SECURE en Android.
const _kSecurityChannel = MethodChannel('pockt/secure');

/// Controlador del ciclo de vida y estado de bloqueo de la app.
class AppLockController with ChangeNotifier {
  final LocalAuthentication auth;
  final SettingsRepository settings;
  final DateTime Function() clock;
  final Future<void> Function(bool enabled)? onSecurityChanged;

  bool _locked = false;
  bool _isLockEnabled = false;
  DateTime? _pausedAt;

  bool get locked => _locked;
  bool get isLockEnabled => _isLockEnabled;

  AppLockController({
    required this.auth,
    required this.settings,
    DateTime Function()? clock,
    this.onSecurityChanged,
  }) : clock = clock ?? DateTime.now;

  /// Inicializa leyendo el ajuste `security.lock` y aplicando FLAG_SECURE.
  Future<void> init() async {
    final value = await settings.get(SettingsKeys.securityLock);
    _isLockEnabled = (value == 'on');
    _locked = _isLockEnabled;
    await _applyFlagSecure(_isLockEnabled);
    notifyListeners();
  }

  /// Desbloquea la app mediante biometría o PIN del dispositivo.
  Future<bool> unlock() async {
    try {
      final success = await auth.authenticate(
        localizedReason: 'Desbloquear Pockt',
        biometricOnly: false,
      );
      if (success) {
        _locked = false;
        Haptics.save();
        notifyListeners();
        return true;
      }
    } catch (_) {}

    _locked = true;
    Haptics.danger();
    notifyListeners();
    return false;
  }

  /// Guarda el timestamp al pasar a segundo plano.
  void onPaused() {
    _pausedAt = clock();
  }

  /// Al volver al primer plano, si pasó ≥ 1 minuto, bloquea la app.
  void onResumed() {
    if (!_isLockEnabled) return;
    if (_pausedAt != null) {
      final elapsed = clock().difference(_pausedAt!);
      if (elapsed >= const Duration(minutes: 1)) {
        _locked = true;
        notifyListeners();
      }
    }
  }

  /// Verifica la compatibilidad del dispositivo con el bloqueo local.
  Future<AppLockAvailability> availability() async {
    try {
      final isSupported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;
      if (isSupported) {
        return AppLockAvailability.ready;
      }
      if (canCheck) {
        return AppLockAvailability.noDeviceLock;
      }
      return AppLockAvailability.unsupported;
    } catch (_) {
      return AppLockAvailability.unsupported;
    }
  }

  /// Activa o desactiva el bloqueo de la app y sincroniza FLAG_SECURE.
  Future<void> setLockEnabled(bool enabled) async {
    _isLockEnabled = enabled;
    await settings.set(SettingsKeys.securityLock, enabled ? 'on' : 'off');
    await _applyFlagSecure(enabled);
    if (!enabled) {
      _locked = false;
    }
    notifyListeners();
  }

  Future<void> _applyFlagSecure(bool enabled) async {
    if (onSecurityChanged != null) {
      await onSecurityChanged!(enabled);
    } else {
      try {
        await _kSecurityChannel.invokeMethod('setSecure', {'enabled': enabled});
      } catch (_) {}
    }
  }
}

/// Provider de Riverpod para [AppLockController].
final appLockControllerProvider =
    ChangeNotifierProvider<AppLockController>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final controller = AppLockController(
    auth: LocalAuthentication(),
    settings: settingsRepo,
  );
  controller.init();
  return controller;
});

/// Pantalla de bloqueo elegante (Apple / Emil design) con el orbe y logotipo.
class AppLockScreen extends StatelessWidget {
  const AppLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              const PocktOrb(size: 88, showGlow: true),
              const SizedBox(height: 24),
              const PocktWordmark(size: 32),
              const SizedBox(height: 8),
              Text(
                'Tu información financiera está protegida',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.textTertiary,
                ),
              ),
              const Spacer(flex: 4),
              Consumer(
                builder: (context, ref, _) {
                  final controller = ref.watch(appLockControllerProvider);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Pressable(
                      onTap: () {
                        Haptics.tick();
                        controller.unlock();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.brandStart, colors.brandEnd],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: colors.brandStart.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              uiIcon('fingerprint'),
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Desbloquear',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

/// Envoltorio que muestra la pantalla de bloqueo cuando [controller.locked] es true.
class AppLockGate extends ConsumerWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appLockControllerProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: controller.locked
          ? const AppLockScreen(key: ValueKey('app-lock-screen'))
          : KeyedSubtree(
              key: const ValueKey('app-unlocked-content'),
              child: child,
            ),
    );
  }
}
