import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/home/ui/home_cards_screen.dart';
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
    PackageInfo.setMockInitialValues(
      appName: 'Pockt',
      packageName: 'app.pockt',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    testDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    notifier = FakeNotifier();
  });

  tearDown(() async {
    await testDb.close();
  });

  Future<void> pumpSettingsScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.pumpWidget(const SizedBox());
    });

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

  Future<void> openSection(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Future<void> goBack(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Volver').last);
    await tester.pumpAndSettle();
  }

  testWidgets('la portada de Ajustes muestra solo las cinco secciones', (tester) async {
    await pumpSettingsScreen(tester);

    expect(find.text('Ajustes'), findsOneWidget);
    for (final t in ['Tu dinero', 'Carga', 'Inicio y apariencia', 'Avisos', 'Privacidad y datos']) {
      expect(find.text(t), findsOneWidget);
    }
    // Las opciones viven dentro de cada sección, no en la portada.
    expect(find.text('Tecla rápida'), findsNothing);
    expect(find.text('Borrar todos los datos'), findsNothing);
  });

  testWidgets('cada sección abre su pantalla con todas sus filas', (tester) async {
    await pumpSettingsScreen(tester);
    const sections = {
      'Tu dinero': ['Esquema de cobro', 'Inicio del mes', 'Categorías', 'Recurrentes', 'Préstamos y cuotas'],
      'Carga': ['Orden de categorías', 'Tecla rápida', 'Pedir nota al guardar', 'Vibración'],
      'Inicio y apariencia': ['Apariencia', 'Tarjetas del Inicio', 'Movimientos recientes', 'Resplandor aurora',
          'Aurora reacciona al presupuesto', 'La semana empieza', 'Reducir animaciones'],
      'Avisos': ['Recordatorios', 'Alertas de presupuesto', 'Umbral de advertencia', 'Umbral de límite'],
      'Privacidad y datos': ['Bloqueo con huella', 'Tiempo hasta bloquear', 'Ocultar montos', 'Copia de seguridad',
          'Exportar a CSV', 'Borrar todos los datos', 'Acerca de Pockt'],
    };
    for (final entry in sections.entries) {
      await openSection(tester, entry.key);
      for (final row in entry.value) {
        expect(find.text(row), findsOneWidget, reason: '${entry.key} → $row');
      }
      await goBack(tester);
    }
  });

  testWidgets('tocar Categorías navega a CategoryKeywordsScreen', (tester) async {
    await pumpSettingsScreen(tester);
    await openSection(tester, 'Tu dinero');
    await tester.tap(find.text('Categorías'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryKeywordsScreen), findsOneWidget);
  });

  testWidgets('tocar Esquema de cobro navega a IncomeScheduleScreen', (tester) async {
    await pumpSettingsScreen(tester);
    await openSection(tester, 'Tu dinero');
    await tester.tap(find.text('Esquema de cobro'));
    await tester.pumpAndSettle();
    expect(find.byType(IncomeScheduleScreen), findsOneWidget);
  });

  testWidgets('tocar Recurrentes navega a RecurringScreen', (tester) async {
    await pumpSettingsScreen(tester);
    await openSection(tester, 'Tu dinero');
    await tester.tap(find.text('Recurrentes'));
    await tester.pumpAndSettle();
    expect(find.byType(RecurringScreen), findsOneWidget);
  });

  testWidgets('tocar Apariencia navega a AppearanceScreen', (tester) async {
    await pumpSettingsScreen(tester);
    await openSection(tester, 'Inicio y apariencia');
    await tester.tap(find.text('Apariencia'));
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceScreen), findsOneWidget);
  });

  testWidgets('tocar Tarjetas del Inicio navega a HomeCardsScreen', (tester) async {
    await pumpSettingsScreen(tester);
    await openSection(tester, 'Inicio y apariencia');
    await tester.tap(find.text('Tarjetas del Inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeCardsScreen), findsOneWidget);
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

  testWidgets('SettingsScreen organiza las secciones con brandAt en íconos', (tester) async {
    await pumpSettingsScreen(tester);
    final c = PocktColors.dark;

    Color iconColorOf(String key) {
      final tile = find.byKey(ValueKey(key));
      return tester.widget<Icon>(find.descendant(of: tile, matching: find.byType(Icon)).first).color!;
    }

    expect(iconColorOf('settings-section-money'), c.brandAt(0));
    expect(iconColorOf('settings-section-entry'), c.brandAt(1));
    expect(iconColorOf('settings-section-home'), c.brandAt(2));
    expect(iconColorOf('settings-section-alerts'), c.brandAt(3));
    expect(iconColorOf('settings-section-privacy'), c.brandAt(3));

    await openSection(tester, 'Tu dinero');
    expect(iconColorOf('settings-categories-tile'), c.brandAt(0));
    expect(iconColorOf('settings-income-schedule-tile'), c.brandAt(0));
    expect(iconColorOf('settings-recurring-tile'), c.brandAt(0));
    await goBack(tester);

    await openSection(tester, 'Carga');
    expect(iconColorOf('settings-quick-key'), c.brandAt(1));
    await goBack(tester);

    await openSection(tester, 'Inicio y apariencia');
    expect(iconColorOf('settings-appearance-tile'), c.brandAt(2));
    await goBack(tester);

    await openSection(tester, 'Avisos');
    expect(iconColorOf('settings-reminders-tile'), c.brandAt(3));
    await goBack(tester);

    await openSection(tester, 'Privacidad y datos');
    expect(iconColorOf('settings-backup-tile'), c.brandAt(3));
  });

  testWidgets('Copia de seguridad muestra color warning cuando el backup está atrasado', (tester) async {
    final settingsRepo = SettingsRepository(testDb);
    // Configurar último backup hace 10 días para que esté overdue
    final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10)).toIso8601String();
    await settingsRepo.set(SettingsKeys.backupLastSuccessAt, tenDaysAgo);

    await pumpSettingsScreen(tester);
    await openSection(tester, 'Privacidad y datos');

    final backupTile = find.byKey(const ValueKey('settings-backup-tile'));
    final backupIcon = tester.widget<Icon>(find.descendant(of: backupTile, matching: find.byType(Icon)).first);
    expect(backupIcon.color, equals(PocktColors.dark.warning));
  });

  testWidgets('cambiar un segmento o switch en línea guarda el ajuste en SettingsRepository', (tester) async {
    final settingsRepo = SettingsRepository(testDb);
    await pumpSettingsScreen(tester);

    // 1. Tecla rápida a '00'
    await openSection(tester, 'Carga');
    await tester.tap(find.text('00'));
    await tester.pumpAndSettle();
    expect(await settingsRepo.get(SettingsKeys.entryQuickKey), equals('00'));

    // 2. Movimientos recientes a '10'
    await goBack(tester);
    await openSection(tester, 'Inicio y apariencia');
    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();
    expect(await settingsRepo.get(SettingsKeys.homeRecentCount), equals('10'));

    // 3. Inicio del mes a 'Desde el cobro'
    await goBack(tester);
    await openSection(tester, 'Tu dinero');
    await tester.tap(find.text('Desde el cobro'));
    await tester.pumpAndSettle();
    expect(await settingsRepo.get(SettingsKeys.periodMonthStart), equals('payday'));

    // 4. La semana empieza a 'Domingo'
    await goBack(tester);
    await openSection(tester, 'Inicio y apariencia');
    await tester.tap(find.text('Domingo'));
    await tester.pumpAndSettle();
    expect(await settingsRepo.get(SettingsKeys.calendarWeekStart), equals('sunday'));

    // 5. Umbral de advertencia a '90 %'
    await goBack(tester);
    await openSection(tester, 'Avisos');
    await tester.tap(find.text('90 %'));
    await tester.pumpAndSettle();
    expect(await settingsRepo.get(SettingsKeys.budgetAlertLow), equals('90'));

    // 6. Tiempo hasta bloquear a '5 min'
    await goBack(tester);
    await openSection(tester, 'Privacidad y datos');
    await tester.tap(find.text('5 min'));
    await tester.pumpAndSettle();
    expect(await settingsRepo.get(SettingsKeys.securityLockAfter), equals('5'));

    // 7. Switch de pedir nota
    await goBack(tester);
    await openSection(tester, 'Carga');
    await tester.tap(find.byKey(const ValueKey('settings-ask-note-switch')));
    await tester.pumpAndSettle();
    expect(await settingsRepo.get(SettingsKeys.entryAskNote), equals('true'));

    // 8. Switch de ocultar montos
    await goBack(tester);
    await openSection(tester, 'Privacidad y datos');
    await tester.tap(find.byKey(const ValueKey('settings-hide-amounts-switch')));
    await tester.pumpAndSettle();
    expect(await settingsRepo.get(SettingsKeys.privacyHideAmounts), equals('true'));
  });
}
