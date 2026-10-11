import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/income/data/income_schedule_repository.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:pockt/features/income/domain/salary_deduction.dart';

void main() {
  late AppDatabase db;
  late IncomeScheduleRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    repo = IncomeScheduleRepository(
      db,
      clock: () => DateTime(2026, 10, 15, 10, 0),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('watchCurrent devuelve null si no hay esquema', () async {
    final current = await repo.watchCurrent().first;
    expect(current, isNull);
  });

  test('setSchedule guarda esquema y watchCurrent devuelve el vigente', () async {
    const sueldoCatId = '018f0000-0000-7000-8000-000000000011';

    await repo.setSchedule(
      mode: PayMode.biweekly,
      payDays: [15, -1],
      payDayRules: [PayDayRule.either, PayDayRule.previous],
      monthlyAmount: 7000000,
      paySplitPercents: [30, 70],
      categoryId: sueldoCatId,
    );

    final current = await repo.watchCurrent().first;
    expect(current, isNotNull);
    expect(current!.mode, 'biweekly');
    expect(current.payDays, '[15,-1]');
    expect(current.payDayRules, '["either","previous"]');
    expect(current.monthlyAmount, 7000000);
    expect(current.paySplitPercents, '[30,70]');
    expect(current.categoryId, sueldoCatId);
    expect(current.effectiveFrom, DateTime(2026, 10, 15));
  });

  test('guardar dos veces el mismo día actualiza el esquema de hoy (gana el último)', () async {
    const sueldoCatId = '018f0000-0000-7000-8000-000000000011';
    await repo.setSchedule(
      mode: PayMode.biweekly,
      payDays: [15, -1],
      monthlyAmount: 7000000,
      paySplitPercents: [50, 50],
      categoryId: sueldoCatId,
    );
    await repo.setSchedule(
      mode: PayMode.biweekly,
      payDays: [15, -1],
      monthlyAmount: 5000000,
      paySplitPercents: [30, 70],
      categoryId: sueldoCatId,
    );

    final current = await repo.watchCurrent().first;
    expect(current!.monthlyAmount, 5000000);
    expect(current.paySplitPercents, '[30,70]');
    expect(await db.select(db.incomeSchedules).get(), hasLength(1));
  });

  test('cambiar de modo inserta nueva fila y watchCurrent toma la más reciente sin borrar la anterior', () async {
    const sueldoCatId = '018f0000-0000-7000-8000-000000000011';

    // Primer esquema: 10/10/2026
    var testTime = DateTime(2026, 10, 10);
    final repoWithTime = IncomeScheduleRepository(db, clock: () => testTime);

    await repoWithTime.setSchedule(
      mode: PayMode.biweekly,
      payDays: [15, -1],
      shiftToPreviousBusinessDay: false,
      categoryId: sueldoCatId,
    );

    // Segundo esquema: 15/10/2026 mensual día 30
    testTime = DateTime(2026, 10, 15);
    await repoWithTime.setSchedule(
      mode: PayMode.monthly,
      payDays: [30],
      shiftToPreviousBusinessDay: true,
      categoryId: sueldoCatId,
    );

    // Todas las filas siguen existiendo en la tabla
    final allRows = await db.select(db.incomeSchedules).get();
    expect(allRows, hasLength(2));

    // El vigente es el del 15/10
    final current = await repoWithTime.watchCurrent().first;
    expect(current!.mode, 'monthly');
    expect(current.payDays, '[30]');
  });

  test('guardar el primer esquema el 9/10 crea la sugerencia del 30/09 por el 70 %; guardar otra vez no la duplica', () async {
    const sueldoCatId = '018f0000-0000-7000-8000-000000000011';
    final repoWithClock = IncomeScheduleRepository(
      db,
      clock: () => DateTime(2026, 10, 9, 10, 0),
    );

    // 1. Guardar primer esquema
    await repoWithClock.setSchedule(
      mode: PayMode.biweekly,
      payDays: [15, -1],
      payDayRules: [PayDayRule.either, PayDayRule.previous],
      monthlyAmount: 7000000,
      paySplitPercents: [30, 70],
      categoryId: sueldoCatId,
    );

    // Verifica que se creó la sugerencia del cobro anterior (30/09) por el 70% (4.900.000)
    final sugs = await db.select(db.suggestedTransactions).get();
    expect(sugs, hasLength(1));
    final sug = sugs.first;
    expect(sug.type, TxType.income);
    expect(sug.amount, 4900000);
    expect(sug.occurredAt, DateTime(2026, 9, 30));
    expect(sug.source, TxSource.incomeSchedule);
    expect(sug.categoryId, sueldoCatId);
    expect(sug.status, 'pending');

    // 2. Guardar otra vez no la duplica
    await repoWithClock.setSchedule(
      mode: PayMode.biweekly,
      payDays: [15, -1],
      payDayRules: [PayDayRule.either, PayDayRule.previous],
      monthlyAmount: 7000000,
      paySplitPercents: [30, 70],
      categoryId: sueldoCatId,
    );

    final sugsAfter = await db.select(db.suggestedTransactions).get();
    expect(sugsAfter, hasLength(1));
  });

  test('guardar esquema con descuentos guarda deducciones y la sugerencia de cobro inicial usa el neto', () async {
    const sueldoCatId = '018f0000-0000-7000-8000-000000000011';
    final repoWithClock = IncomeScheduleRepository(
      db,
      clock: () => DateTime(2026, 10, 9, 10, 0),
    );

    final deductions = [
      const SalaryDeductionItem(name: 'IPS', kind: 'percent', value: 900),
      const SalaryDeductionItem(name: 'Seguro', kind: 'fixed', value: 40000),
    ];

    await repoWithClock.setSchedule(
      mode: PayMode.biweekly,
      payDays: [15, -1],
      payDayRules: [PayDayRule.either, PayDayRule.previous],
      monthlyAmount: 4000000,
      paySplitPercents: [30, 70],
      categoryId: sueldoCatId,
      deductions: deductions,
    );

    final current = await repoWithClock.watchCurrent().first;
    expect(current, isNotNull);

    // Deducciones guardadas
    final savedDeds = await repoWithClock.getDeductionsFor(current!.id);
    expect(savedDeds, hasLength(2));
    expect(savedDeds[0].name, 'IPS');
    expect(savedDeds[0].value, 900);
    expect(savedDeds[1].name, 'Seguro');
    expect(savedDeds[1].value, 40000);

    // Sugerencia inicial usa el neto: bruto 2.800.000 - 400.000 deducciones = 2.400.000
    final sugs = await db.select(db.suggestedTransactions).get();
    expect(sugs, hasLength(1));
    expect(sugs.first.amount, 2400000);
  });

  test('guardar esquema con descuentos otro día genera nuevos UUIDs de descuentos sin colisión y preserva el historial', () async {
    const sueldoCatId = '018f0000-0000-7000-8000-000000000011';
    var currentDate = DateTime(2026, 10, 1, 10, 0);
    final repoWithClock = IncomeScheduleRepository(
      db,
      clock: () => currentDate,
    );

    final initialDeductions = [
      const SalaryDeductionItem(name: 'IPS', kind: 'percent', value: 900),
      const SalaryDeductionItem(name: 'Seguro', kind: 'fixed', value: 40000),
    ];

    // Día 1: guardar esquema
    await repoWithClock.setSchedule(
      mode: PayMode.monthly,
      payDays: [-1],
      payDayRules: [PayDayRule.previous],
      monthlyAmount: 4000000,
      paySplitPercents: [100],
      categoryId: sueldoCatId,
      deductions: initialDeductions,
    );

    final schedule1 = await repoWithClock.watchCurrent().first;
    expect(schedule1, isNotNull);
    final savedDeds1 = await repoWithClock.getDeductionsFor(schedule1!.id);
    expect(savedDeds1, hasLength(2));
    expect(savedDeds1.every((d) => d.id.isNotEmpty), isTrue);

    // Mapear como hace la UI (que conserva los IDs de los descuentos existentes)
    final dedsFromUi = savedDeds1
        .map((d) => SalaryDeductionItem(
              id: d.id,
              scheduleId: d.scheduleId,
              name: d.name,
              kind: d.kind,
              value: d.value,
            ))
        .toList();

    // Día 2: el usuario carga los descuentos existentes (que traen d.id) y vuelve a guardar
    currentDate = DateTime(2026, 10, 2, 10, 0);
    await repoWithClock.setSchedule(
      mode: PayMode.monthly,
      payDays: [-1],
      payDayRules: [PayDayRule.previous],
      monthlyAmount: 4500000,
      paySplitPercents: [100],
      categoryId: sueldoCatId,
      deductions: dedsFromUi,
    );

    final schedule2 = await repoWithClock.watchCurrent().first;
    expect(schedule2, isNotNull);
    expect(schedule2!.id, isNot(equals(schedule1.id)));

    // El esquema viejo conserva sus descuentos
    final oldDeds = await repoWithClock.getDeductionsFor(schedule1.id);
    expect(oldDeds, hasLength(2));

    // El esquema nuevo tiene sus propios descuentos con IDs distintos
    final newDeds = await repoWithClock.getDeductionsFor(schedule2.id);
    expect(newDeds, hasLength(2));
    final oldIds = oldDeds.map((d) => d.id).toSet();
    final newIds = newDeds.map((d) => d.id).toSet();
    expect(oldIds.intersection(newIds), isEmpty);
  });
}

