import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/loans/domain/loan_reminders.dart';
import 'package:pockt/features/reminders/domain/reminder_plan.dart';
import 'package:pockt/features/settings/domain/wipe_data.dart';
import 'package:pockt/features/settings/ui/settings_screen.dart';
import 'package:pockt/features/widget/home_widget_bridge.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  late AppDatabase db;
  late FakeNotifier notifier;
  late FakeHomeWidgetPlatform widget;

  setUp(() async {
    setLocalZone('America/Asuncion');
    PackageInfo.setMockInitialValues(
      appName: 'Pockt',
      packageName: 'app.pockt',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(db.close);
    notifier = FakeNotifier();
    widget = FakeHomeWidgetPlatform();
    addTearDown(widget.dispose);
  });

  /// Deja datos del usuario, avisos programados y un widget con datos viejos.
  Future<void> seedUserState() async {
    final now = DateTime(2026, 10, 1);
    await db.into(db.loans).insert(
          LoansCompanion.insert(
            id: 'loan-1',
            direction: LoanDirection.owe,
            kind: LoanKind.installments,
            name: 'Auto',
            totalAmount: 1200000,
            startDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await notifier.schedule(
      PlannedReminder(
        atLocal: DateTime(2026, 10, 20, 9),
        notificationId: 1001,
        title: 'Recordatorio',
        body: 'Anotá tus gastos',
      ),
    );
    await notifier.schedule(
      PlannedReminder(
        atLocal: DateTime(2026, 10, 13, 9),
        notificationId: loanNotificationId('loan-1'),
        title: 'Vence una cuota',
        body: 'Auto',
      ),
    );
    await widget.saveWidgetData<String>('category_name_0', 'Categoria vieja');
    await widget.saveWidgetData<int>('category_count', 99);
  }

  test('wipeAllUserData borra la base, cancela todos los avisos y refresca el widget', () async {
    await seedUserState();
    expect(notifier.scheduled, hasLength(2));

    await wipeAllUserData(
      db: db,
      notifier: notifier,
      homeWidget: widget,
      nowLocal: DateTime(2026, 10, 11, 12),
    );

    expect(await db.select(db.loans).get(), isEmpty);
    // Recordatorios y avisos de préstamos cancelados
    expect(notifier.cancelledAll, isTrue);
    expect(notifier.scheduled, isEmpty);
    // Widget redibujado con las categorías de fábrica, no con las viejas
    expect(widget.updateCallCount, equals(1));
    expect(widget.data['category_name_0'], isNot('Categoria vieja'));
    expect(widget.data['category_count'], equals(4));
  });

  testWidgets('"Borrar todo" en Ajustes cancela avisos y refresca el widget', (tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(seedUserState);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notifierProvider.overrideWithValue(notifier),
          homeWidgetPlatformProvider.overrideWithValue(widget),
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
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Privacidad y datos'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.scrollUntilVisible(
      find.text('Borrar todos los datos'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Borrar todos los datos'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byKey(const ValueKey('wipe-confirm-field')), 'BORRAR');
    await tester.pump(const Duration(milliseconds: 100));

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('wipe-confirm-button')));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump(const Duration(milliseconds: 300));

    expect(notifier.cancelledAll, isTrue);
    expect(notifier.scheduled, isEmpty);
    expect(widget.updateCallCount, equals(1));
    expect(widget.data['category_name_0'], isNot('Categoria vieja'));

    await tester.pumpWidget(const SizedBox());
  });
}
