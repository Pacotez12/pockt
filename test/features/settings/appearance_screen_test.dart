import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/app.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/settings/ui/appearance_screen.dart';

void main() {
  late AppDatabase testDb;
  late FakeNotifier notifier;
  late SettingsRepository settingsRepo;

  setUp(() async {
    testDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    notifier = FakeNotifier();
    settingsRepo = SettingsRepository(testDb);
  });

  tearDown(() async {
    await testDb.close();
  });

  Future<void> pumpAppearanceScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: const AppearanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra opciones Sistema, Claro y Oscuro con Sistema seleccionado por defecto', (tester) async {
    await pumpAppearanceScreen(tester);

    expect(find.text('Apariencia'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Oscuro'), findsOneWidget);

    // Con DB vacía, Sistema está activo
    expect(find.byKey(const ValueKey('check-system')), findsOneWidget);
    expect(find.byKey(const ValueKey('check-light')), findsNothing);
    expect(find.byKey(const ValueKey('check-dark')), findsNothing);
  });

  testWidgets('al tocar Oscuro se guarda dark en el repositorio y cambia la selección', (tester) async {
    await pumpAppearanceScreen(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('Oscuro'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(() => settingsRepo.get('appearance'));
    expect(saved, equals('dark'));
    expect(find.byKey(const ValueKey('check-dark')), findsOneWidget);
  });

  testWidgets('al tocar Claro se guarda light en el repositorio', (tester) async {
    await pumpAppearanceScreen(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('Claro'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(() => settingsRepo.get('appearance'));
    expect(saved, equals('light'));
    expect(find.byKey(const ValueKey('check-light')), findsOneWidget);
  });

  testWidgets('PocktApp aplica themeMode reactivamente y transición de 400ms', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          notifierProvider.overrideWithValue(notifier),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
        ],
        child: const PocktApp(),
      ),
    );
    await tester.pumpAndSettle();

    final appFinder = find.byType(MaterialApp);
    var app = tester.widget<MaterialApp>(appFinder);
    expect(app.themeMode, equals(ThemeMode.system));
    expect(app.themeAnimationDuration, equals(const Duration(milliseconds: 400)));
    expect(app.themeAnimationCurve, equals(Curves.easeInOut));

    // Cambiar a dark
    await tester.runAsync(() async {
      await settingsRepo.set('appearance', 'dark');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    app = tester.widget<MaterialApp>(appFinder);
    expect(app.themeMode, equals(ThemeMode.dark));
  });
}
