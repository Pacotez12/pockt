import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/income/data/income_schedule_repository.dart';
import 'package:pockt/features/income/ui/income_schedule_screen.dart';

void main() {
  late AppDatabase testDb;
  late FakeNotifier notifier;
  late IncomeScheduleRepository scheduleRepo;

  setUp(() async {
    setLocalZone('America/Asuncion');
    testDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    notifier = FakeNotifier();
    scheduleRepo = IncomeScheduleRepository(
      testDb,
      clock: () => DateTime(2026, 10, 8, 12, 0),
    );
  });

  tearDown(() async {
    await testDb.close();
  });

  Future<void> pumpIncomeScheduleScreen(
    WidgetTester tester, {
    DateTime? nowLocal,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          notifierProvider.overrideWithValue(notifier),
          incomeScheduleRepositoryProvider.overrideWithValue(scheduleRepo),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: IncomeScheduleScreen(
            nowLocal: nowLocal ?? DateTime(2026, 10, 8, 12, 0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('esquema de cobro: cambiar a mensual día 30 muestra el próximo cobro correcto', (tester) async {
    await pumpIncomeScheduleScreen(tester);

    expect(find.text('Esquema de cobro'), findsOneWidget);
    expect(find.text('Quincenal'), findsOneWidget);
    expect(find.text('Mensual'), findsOneWidget);

    // Cambiar a Mensual
    await tester.tap(find.text('Mensual'));
    await tester.pumpAndSettle();

    // Seleccionar día 30
    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();

    // El 30 de octubre de 2026 es viernes
    expect(find.textContaining('Próximo cobro: viernes 30 de octubre'), findsOneWidget);
  });

  testWidgets('guardar esquema persiste en base de datos', (tester) async {
    await pumpIncomeScheduleScreen(tester);

    // Cambiar a Mensual día 30 y guardar
    await tester.tap(find.text('Mensual'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('Guardar esquema'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final current = await tester.runAsync(() => scheduleRepo.watchCurrent().first);
    expect(current, isNotNull);
    expect(current!.mode, 'monthly');
    expect(current.payDays, contains('30'));
  });

  testWidgets('selector de regla por día de cobro actualiza preview y persiste payDayRules', (tester) async {
    // 10 de noviembre de 2026: el 15/11/2026 es domingo
    await pumpIncomeScheduleScreen(tester, nowLocal: DateTime(2026, 11, 10, 10, 0));

    // Por defecto quincenal [15, -1] con día 1 en either -> rango viernes 13 a lunes 16
    expect(find.textContaining('entre el viernes 13 y el lunes 16 de noviembre'), findsOneWidget);

    // En el selector del 1er cobro, cambiar a "El anterior"
    final ruleSelector1 = find.byKey(const ValueKey('rule-selector-day1'));
    expect(ruleSelector1, findsOneWidget);
    await tester.tap(find.descendant(of: ruleSelector1, matching: find.text('El anterior')));
    await tester.pumpAndSettle();

    // Ahora sólo viernes 13
    expect(find.textContaining('viernes 13 de noviembre'), findsOneWidget);

    // Guardar
    await tester.runAsync(() async {
      await tester.tap(find.text('Guardar esquema'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final current = await tester.runAsync(() => scheduleRepo.watchCurrent().first);
    expect(current, isNotNull);
    expect(current!.payDayRules, equals('["previous","previous"]'));
  });
}
