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
import 'package:pockt/features/income/domain/pay_days.dart';
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

    expect(find.text('Sueldo y cobros'), findsOneWidget);
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

  testWidgets('la pantalla muestra la vista previa con sueldo mensual y reparto, y en mensual se oculta el reparto', (tester) async {
    const sueldoCatId = '018f0000-0000-7000-8000-000000000011';
    await scheduleRepo.setSchedule(
      mode: PayMode.biweekly,
      payDays: [15, -1],
      payDayRules: [PayDayRule.either, PayDayRule.previous],
      monthlyAmount: 7000000,
      paySplitPercents: [30, 70],
      categoryId: sueldoCatId,
    );

    await pumpIncomeScheduleScreen(tester);

    // Sueldo mensual se muestra
    expect(find.text('Sueldo mensual'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('schedule-monthly-amount-tile')),
        matching: find.text('Gs. 7.000.000'),
      ),
      findsOneWidget,
    );

    // Reparto visible con vista previa de 30% / 70%
    expect(find.byKey(const ValueKey('schedule-split-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('schedule-split-slider')), findsOneWidget);
    expect(find.text('El 15 cobrás ~Gs. 2.100.000 · a fin de mes ~Gs. 4.900.000'), findsOneWidget);

    // Mover control deslizante hacia la derecha
    final slider = find.byKey(const ValueKey('schedule-split-slider'));
    await tester.drag(slider, const Offset(60, 0));
    await tester.pumpAndSettle();

    // La vista previa cambió (ya no es 2.100.000)
    expect(find.text('El 15 cobrás ~Gs. 2.100.000 · a fin de mes ~Gs. 4.900.000'), findsNothing);

    // Cambiar a Mensual: el reparto ya no se muestra
    await tester.tap(find.text('Mensual'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('schedule-split-section')), findsNothing);
    expect(find.byKey(const ValueKey('schedule-split-slider')), findsNothing);
  });

  testWidgets('sección Descuentos permite agregar, editar, borrar y muestra resumen Lo que cobrás', (tester) async {
    const sueldoCatId = '018f0000-0000-7000-8000-000000000011';
    await scheduleRepo.setSchedule(
      mode: PayMode.biweekly,
      payDays: [15, -1],
      payDayRules: [PayDayRule.either, PayDayRule.previous],
      monthlyAmount: 4000000,
      paySplitPercents: [30, 70],
      categoryId: sueldoCatId,
    );

    await pumpIncomeScheduleScreen(tester);

    // Título de la pantalla
    expect(find.text('Sueldo y cobros'), findsOneWidget);

    // Resumen "Lo que cobrás" presente
    expect(find.text('LO QUE COBRÁS'), findsOneWidget);

    // Sección Descuentos presente
    expect(find.text('DESCUENTOS'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-deduction-button')), findsOneWidget);

    // Tocar agregar descuento
    await tester.tap(find.byKey(const ValueKey('add-deduction-button')));
    await tester.pumpAndSettle();

    expect(find.text('Agregar descuento'), findsOneWidget);

    // Ingresar nombre "IPS"
    await tester.enterText(find.byKey(const ValueKey('deduction-name-input')), 'IPS');
    // Ingresar 9 (%)
    await tester.enterText(find.byKey(const ValueKey('deduction-value-input')), '9');
    await tester.pumpAndSettle();

    // Guardar descuento
    await tester.tap(find.byKey(const ValueKey('save-deduction-dialog-button')));
    await tester.pumpAndSettle();

    // Descuento en la lista
    expect(find.text('IPS'), findsOneWidget);
    expect(find.textContaining('9 % del bruto'), findsOneWidget);

    // En "Lo que cobrás", el segundo cobro (fin de mes) ahora refleja el descuento (2.800.000 - 360.000 = 2.440.000)
    expect(find.textContaining('2.440.000'), findsOneWidget);

    // Guardar esquema completo
    await tester.runAsync(() async {
      await tester.tap(find.text('Guardar esquema'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final current = await tester.runAsync(() => scheduleRepo.watchCurrent().first);
    expect(current, isNotNull);
    final savedDeds = await tester.runAsync(() => scheduleRepo.getDeductionsFor(current!.id));
    expect(savedDeds, hasLength(1));
    expect(savedDeds!.first.name, 'IPS');
    expect(savedDeds.first.value, 900);
  });
}
