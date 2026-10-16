import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/features/backup/domain/backup_service.dart';

/// Notificador que cuenta confirmaciones consecutivas de sugerencias
/// para disparar un backup automático al confirmar 3 o más sugerencias (Plan 4).
class ConsecutiveConfirmationsNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void recordConfirmation() {
    state++;
    if (state >= 3) {
      state = 0;
      ref.read(backupServiceProvider).backupNow();
    }
  }
}

final consecutiveConfirmationsProvider =
    NotifierProvider<ConsecutiveConfirmationsNotifier, int>(
      ConsecutiveConfirmationsNotifier.new,
    );
