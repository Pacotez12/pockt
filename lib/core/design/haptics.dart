import 'package:flutter/services.dart';

abstract final class Haptics {
  /// Feedback leve al presionar una tecla del teclado numérico.
  static Future<void> key() => HapticFeedback.lightImpact();

  /// Feedback medio al guardar un movimiento.
  static Future<void> save() => HapticFeedback.mediumImpact();

  /// Tic al cambiar de mes o paso discreto.
  static Future<void> tick() => HapticFeedback.selectionClick();
}
