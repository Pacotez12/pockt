import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class Haptics {
  /// Solo para tests: registra cada haptic disparado sin tocar el canal de
  /// plataforma (mockear SystemChannels.platform cuelga los tests de widgets).
  @visibleForTesting
  static void Function(String kind)? debugRecorder;

  static Future<void> _fire(String kind, Future<void> Function() feedback) {
    debugRecorder?.call(kind);
    return feedback();
  }

  /// Feedback leve al presionar una tecla del teclado numérico.
  static Future<void> key() => _fire('key', HapticFeedback.lightImpact);

  /// Feedback medio al guardar un movimiento.
  static Future<void> save() => _fire('save', HapticFeedback.mediumImpact);

  /// Tic al cambiar de mes o paso discreto.
  static Future<void> tick() => _fire('tick', HapticFeedback.selectionClick);

  /// Feedback al cruzar el 80 % del presupuesto (advertencia).
  static Future<void> warning() => _fire('warning', HapticFeedback.mediumImpact);

  /// Feedback al cruzar el 100 % del presupuesto (exceso).
  static Future<void> danger() => _fire('danger', HapticFeedback.heavyImpact);
}
