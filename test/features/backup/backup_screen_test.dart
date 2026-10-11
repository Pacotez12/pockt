import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/backup/data/backup_store.dart';
import 'package:pockt/features/backup/data/key_storage.dart';
import 'package:pockt/features/backup/domain/backup_service.dart';
import 'package:pockt/features/backup/ui/backup_screen.dart';

void main() {
  late AppDatabase db;
  late MemoryBackupStore store;
  late KeyStorage keys;
  late SettingsRepository settings;
  late BackupService service;
  var currentTime = DateTime(2026, 10, 10, 8, 12);

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    currentTime = DateTime(2026, 10, 10, 8, 12);
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    store = MemoryBackupStore(clock: () => currentTime);
    keys = KeyStorage.inMemory();
    settings = SettingsRepository(db);

    service = BackupService(
      db: db,
      store: store,
      keys: keys,
      settings: settings,
      clock: () => currentTime,
      argonIterations: 1,
      argonMemoryInKiB: 1024,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget({BackupService? customService}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWithValue(settings),
        backupStoreProvider.overrideWithValue(store),
        keyStorageProvider.overrideWithValue(keys),
        backupServiceProvider.overrideWithValue(customService ?? service),
      ],
      child: const MaterialApp(
        home: BackupScreen(),
      ),
    );
  }

  group('BackupScreen', () {
    testWidgets('muestra título y estado inicial sin backups', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Copia de seguridad'), findsOneWidget);
      expect(find.text('Respaldar ahora'), findsOneWidget);
      expect(find.text('Pockt · Backups'), findsOneWidget);
    });

    testWidgets('muestra fecha formateada del último backup exitoso', (tester) async {
      final now = DateTime.now();
      final todayBackup = DateTime(now.year, now.month, now.day, 8, 12);
      await settings.set(
        SettingsKeys.backupLastSuccessAt,
        todayBackup.toIso8601String(),
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('08:12'), findsOneWidget);
    });

    testWidgets('muestra aviso visible cuando el backup está vencido (5 días)', (tester) async {
      // Configurar fecha de más de 5 días atrás
      final oldDate = DateTime.now().subtract(const Duration(days: 6));
      await settings.set(
        SettingsKeys.backupLastSuccessAt,
        oldDate.toIso8601String(),
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('vencida'), findsOneWidget);
    });

    testWidgets('muestra mensaje de error cuando ocurre una falla', (tester) async {
      await settings.set(SettingsKeys.backupLastError, BackupResult.noPassword.name);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('contraseña'), findsWidgets);
    });

    testWidgets('tocar Respaldar ahora ejecuta el proceso y actualiza el estado', (tester) async {
      final testService = _TestBackupService(
        db: db,
        store: store,
        keys: keys,
        settings: settings,
      );

      await tester.pumpWidget(buildTestWidget(customService: testService));
      await tester.pumpAndSettle();

      final backupButton = find.text('Respaldar ahora');
      expect(backupButton, findsOneWidget);

      await tester.tap(backupButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(testService.backupNowCalled, isTrue);
    });
  });
}

class _TestBackupService extends BackupService {
  bool backupNowCalled = false;

  _TestBackupService({
    required super.db,
    required super.store,
    required super.keys,
    required super.settings,
  });

  @override
  Future<BackupResult> backupNow() async {
    backupNowCalled = true;
    await settings.set(
      SettingsKeys.backupLastSuccessAt,
      DateTime.now().toIso8601String(),
    );
    return BackupResult.success;
  }
}
