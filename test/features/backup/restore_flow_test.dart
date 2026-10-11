import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/backup/data/backup_store.dart';
import 'package:pockt/features/backup/domain/backup_format.dart';
import 'package:pockt/features/backup/domain/restore_service.dart';
import 'package:pockt/features/backup/ui/restore_flow.dart';

class FakeRestoreService extends RestoreService {
  RestorePreview? previewResult;
  Exception? previewError;
  bool restoreCalled = false;
  String? lastRestoredId;
  String? lastRestoredPassword;

  FakeRestoreService({
    required super.store,
    required super.dbFileResolver,
    this.previewResult,
    this.previewError,
  });

  @override
  Future<RestorePreview> preview(String backupId, String password) async {
    if (previewError != null) {
      throw previewError!;
    }
    return previewResult ??
        RestorePreview(
          createdAt: DateTime(2026, 10, 10, 8, 0),
          transactionCount: 5,
          schemaVersion: 5,
        );
  }

  @override
  Future<void> restore(String backupId, String password) async {
    restoreCalled = true;
    lastRestoredId = backupId;
    lastRestoredPassword = password;
  }
}

void main() {
  late MemoryBackupStore store;
  late FakeRestoreService fakeService;

  setUp(() {
    store = MemoryBackupStore();
    fakeService = FakeRestoreService(
      store: store,
      dbFileResolver: () async => File('/tmp/pockt.sqlite'),
    );
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        backupStoreProvider.overrideWithValue(store),
        restoreServiceProvider.overrideWithValue(fakeService),
      ],
      child: const MaterialApp(
        home: RestoreFlowScreen(),
      ),
    );
  }

  Future<void> settle(WidgetTester tester, [Duration duration = const Duration(milliseconds: 300)]) async {
    await tester.pump();
    await tester.pump(duration);
  }

  group('RestoreFlowScreen', () {
    testWidgets('muestra estado vacío si no hay backups remotos', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await settle(tester);

      expect(find.text('Restaurar copia'), findsOneWidget);
      expect(find.text('No encontramos copias en tu Google Drive.'), findsOneWidget);
    });

    testWidgets('lista las copias disponibles y abre diálogo de contraseña al tocar una', (tester) async {
      await store.upload('pockt-20261010-080000.pockt', List.filled(2048, 0));

      await tester.pumpWidget(createTestWidget());
      await settle(tester);

      expect(find.text('pockt-20261010-080000.pockt'), findsOneWidget);

      await tester.tap(find.text('pockt-20261010-080000.pockt'));
      await settle(tester);

      expect(find.text('Contraseña de la copia'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('contraseña incorrecta muestra mensaje de error', (tester) async {
      await store.upload('pockt-20261010-080000.pockt', List.filled(2048, 0));
      fakeService.previewError = const WrongPasswordException();

      await tester.pumpWidget(createTestWidget());
      await settle(tester);

      await tester.tap(find.text('pockt-20261010-080000.pockt'));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'wrong-password');
      await tester.tap(find.text('Continuar'));
      await settle(tester);

      expect(find.text('Contraseña incorrecta o copia alterada'), findsOneWidget);
    });

    testWidgets('contraseña correcta muestra vista previa y permite confirmar', (tester) async {
      await store.upload('pockt-20261010-080000.pockt', List.filled(2048, 0));
      fakeService.previewResult = RestorePreview(
        createdAt: DateTime(2026, 10, 10, 8, 0),
        transactionCount: 1243,
        schemaVersion: 5,
      );

      await tester.pumpWidget(createTestWidget());
      await settle(tester);

      await tester.tap(find.text('pockt-20261010-080000.pockt'));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'correct-password');
      await tester.tap(find.text('Continuar'));
      await settle(tester);

      // Debe mostrar la vista previa con 1.243 movimientos
      expect(find.textContaining('1.243 movimientos'), findsOneWidget);
      expect(find.text('Confirmar y restaurar'), findsOneWidget);

      await tester.tap(find.text('Confirmar y restaurar'));
      await settle(tester);

      expect(fakeService.restoreCalled, isTrue);
      expect(fakeService.lastRestoredPassword, equals('correct-password'));
    });
  });
}
