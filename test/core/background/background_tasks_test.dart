import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/background/background_tasks.dart';
import 'package:pockt/features/backup/domain/backup_service.dart';

void main() {
  group('shouldWorkmanagerComplete', () {
    test('devuelve true si el backup es exitoso', () {
      expect(shouldWorkmanagerComplete(BackupResult.success), isTrue);
    });

    test('devuelve true si falla por noPassword para no reintentar en bucle', () {
      expect(shouldWorkmanagerComplete(BackupResult.noPassword), isTrue);
    });

    test('devuelve true si falla por notSignedIn para no reintentar en bucle', () {
      expect(shouldWorkmanagerComplete(BackupResult.notSignedIn), isTrue);
    });

    test('devuelve false si falla por network para que Workmanager reintente', () {
      expect(shouldWorkmanagerComplete(BackupResult.network), isFalse);
    });

    test('devuelve false si falla por unknown para que Workmanager reintente', () {
      expect(shouldWorkmanagerComplete(BackupResult.unknown), isFalse);
    });
  });
}
