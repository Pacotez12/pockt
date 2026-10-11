import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/settings/settings_repository.dart';

/// Notifier que maneja si los montos fueron revelados temporalmente tocando el total.
final amountsRevealedProvider =
    NotifierProvider<AmountsRevealedNotifier, bool>(AmountsRevealedNotifier.new);

class AmountsRevealedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void reset() {
    state = false;
  }
}

/// Provider computado que determina si los montos deben mostrarse como '••••'.
/// Si privacy.hideAmounts está inactivo, nunca se ocultan.
/// Si está activo, se ocultan a menos que hayan sido revelados temporalmente.
final shouldObscureAmountsProvider = Provider<bool>((ref) {
  final hideAmounts = ref.watch(privacyHideAmountsProvider).value ?? false;
  if (!hideAmounts) return false;
  final isRevealed = ref.watch(amountsRevealedProvider);
  return !isRevealed;
});
