import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/app.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/sync/sync_controller.dart';
import 'package:pockt/features/recurring/domain/suggestion_generator.dart';

class _FakeSyncController implements SyncController {
  @override
  bool get isSyncAvailable => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _SpySuggestionGenerator extends SuggestionGenerator {
  int runCount = 0;

  _SpySuggestionGenerator()
      : super(
          AppDatabase.forTesting(
            DatabaseConnection(NativeDatabase.memory(),
                closeStreamsSynchronously: true),
          ),
          FakeNotifier(),
        );

  @override
  Future<int> run() async {
    runCount++;
    return 0;
  }
}

void main() {
  testWidgets('PocktApp arranca y muestra el shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PocktApp()));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, 'Pockt');
  });

  testWidgets('PocktApp ejecuta SuggestionGenerator al iniciar y al volver de segundo plano', (tester) async {
    final spy = _SpySuggestionGenerator();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          suggestionGeneratorProvider.overrideWithValue(spy),
        ],
        child: const PocktApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(spy.runCount, 1);

    // Simula volver a primer plano (resumed)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(spy.runCount, 2);
  });

  testWidgets('PocktApp lee syncControllerProvider al iniciar sin bloquear el primer frame', (tester) async {
    var syncControllerInitialized = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncControllerProvider.overrideWith((ref) {
            syncControllerInitialized = true;
            return _FakeSyncController();
          }),
        ],
        child: const PocktApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(syncControllerInitialized, isTrue);
  });
}

