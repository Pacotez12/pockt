import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pockt/features/income/ui/income_schedule_screen.dart';
import 'package:pockt/features/recurring/ui/recurring_screen.dart';
import 'package:pockt/features/settings/ui/appearance_screen.dart';
import 'package:pockt/features/settings/ui/category_keywords_screen.dart';
import 'package:pockt/features/settings/ui/settings_screen.dart';

void main() {
  late AppDatabase testDb;
  late FakeNotifier notifier;

  setUp(() async {
    setLocalZone('America/Asuncion');
    testDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    notifier = FakeNotifier();
  });

  tearDown(() async {
    await testDb.close();
  });

  Future<void> pumpSettingsScreen(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          notifierProvider.overrideWithValue(notifier),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('SettingsScreen lista Categorías, Esquema de cobro, Recurrentes y Apariencia', (tester) async {
    await pumpSettingsScreen(tester);

    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Categorías'), findsOneWidget);
    expect(find.text('Esquema de cobro'), findsOneWidget);
    expect(find.text('Recurrentes'), findsOneWidget);
    expect(find.text('Apariencia'), findsOneWidget);
  });

  testWidgets('tocar Categorías navega a CategoryKeywordsScreen', (tester) async {
    await pumpSettingsScreen(tester);

    await tester.tap(find.text('Categorías'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryKeywordsScreen), findsOneWidget);
  });

  testWidgets('tocar Esquema de cobro navega a IncomeScheduleScreen', (tester) async {
    await pumpSettingsScreen(tester);

    await tester.tap(find.text('Esquema de cobro'));
    await tester.pumpAndSettle();

    expect(find.byType(IncomeScheduleScreen), findsOneWidget);
  });

  testWidgets('tocar Recurrentes navega a RecurringScreen', (tester) async {
    await pumpSettingsScreen(tester);

    await tester.tap(find.text('Recurrentes'));
    await tester.pumpAndSettle();

    expect(find.byType(RecurringScreen), findsOneWidget);
  });

  testWidgets('tocar Apariencia navega a AppearanceScreen', (tester) async {
    await pumpSettingsScreen(tester);

    await tester.tap(find.text('Apariencia'));
    await tester.pumpAndSettle();

    expect(find.byType(AppearanceScreen), findsOneWidget);
  });

  testWidgets('todas las claves de íconos que usa settings_screen.dart resuelven a un ícono real', (tester) async {
    await pumpSettingsScreen(tester);

    final iconWidgets = tester.widgetList<Icon>(find.byType(Icon));
    expect(iconWidgets, isNotEmpty);
    for (final iconWidget in iconWidgets) {
      expect(
        iconWidget.icon,
        isNot(equals(PhosphorIconsRegular.question)),
        reason: 'Un ícono en settings_screen cayó al fallback question mark',
      );
      expect(
        iconWidget.icon,
        isNot(equals(PhosphorIconsFill.question)),
        reason: 'Un ícono en settings_screen cayó al fallback question mark',
      );
    }
  });

  testWidgets('SettingsScreen organiza las secciones con brandAt en encabezados e íconos', (tester) async {
    await pumpSettingsScreen(tester);

    final darkColors = PocktColors.dark;

    // Encabezados de sección
    final tuDineroText = tester.widget<Text>(find.text('Tu dinero'));
    expect(tuDineroText.style?.color, equals(darkColors.brandAt(0)));

    final inicioAparienciaText = tester.widget<Text>(find.text('Inicio y apariencia'));
    expect(inicioAparienciaText.style?.color, equals(darkColors.brandAt(2)));

    final avisosPrivacidadText = tester.widget<Text>(find.text('Avisos y Privacidad'));
    expect(avisosPrivacidadText.style?.color, equals(darkColors.brandAt(3)));

    // Íconos por sección
    // Categorías: brandAt(0)
    final catTile = find.byKey(const ValueKey('settings-categories-tile'));
    final catIcon = tester.widget<Icon>(find.descendant(of: catTile, matching: find.byType(Icon)).first);
    expect(catIcon.color, equals(darkColors.brandAt(0)));

    // Esquema de cobro: brandAt(0)
    final incomeTile = find.byKey(const ValueKey('settings-income-schedule-tile'));
    final incomeIcon = tester.widget<Icon>(find.descendant(of: incomeTile, matching: find.byType(Icon)).first);
    expect(incomeIcon.color, equals(darkColors.brandAt(0)));

    // Recurrentes: brandAt(0)
    final recTile = find.byKey(const ValueKey('settings-recurring-tile'));
    final recIcon = tester.widget<Icon>(find.descendant(of: recTile, matching: find.byType(Icon)).first);
    expect(recIcon.color, equals(darkColors.brandAt(0)));

    // Apariencia: brandAt(2)
    final appTile = find.byKey(const ValueKey('settings-appearance-tile'));
    final appIcon = tester.widget<Icon>(find.descendant(of: appTile, matching: find.byType(Icon)).first);
    expect(appIcon.color, equals(darkColors.brandAt(2)));

    // Recordatorios: brandAt(3)
    final remTile = find.byKey(const ValueKey('settings-reminders-tile'));
    final remIcon = tester.widget<Icon>(find.descendant(of: remTile, matching: find.byType(Icon)).first);
    expect(remIcon.color, equals(darkColors.brandAt(3)));

    // Copia de seguridad: brandAt(3) cuando no está atrasada
    final backupTile = find.byKey(const ValueKey('settings-backup-tile'));
    final backupIcon = tester.widget<Icon>(find.descendant(of: backupTile, matching: find.byType(Icon)).first);
    expect(backupIcon.color, equals(darkColors.brandAt(3)));
  });

  testWidgets('Copia de seguridad muestra color warning cuando el backup está atrasado', (tester) async {
    final settingsRepo = SettingsRepository(testDb);
    // Configurar último backup hace 10 días para que esté overdue
    final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10)).toIso8601String();
    await settingsRepo.set(SettingsKeys.backupLastSuccessAt, tenDaysAgo);

    await pumpSettingsScreen(tester);

    final backupTile = find.byKey(const ValueKey('settings-backup-tile'));
    final backupIcon = tester.widget<Icon>(find.descendant(of: backupTile, matching: find.byType(Icon)).first);
    expect(backupIcon.color, equals(PocktColors.dark.warning));
  });
}
