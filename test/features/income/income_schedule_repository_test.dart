import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/features/income/data/income_schedule_repository.dart';
import 'package:pockt/features/income/domain/pay_days.dart';

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
      expectedAmount: 4500000,
      categoryId: sueldoCatId,
    );

    final current = await repo.watchCurrent().first;
    expect(current, isNotNull);
    expect(current!.mode, 'biweekly');
    expect(current.payDays, '[15,-1]');
    expect(current.payDayRules, '["either","previous"]');
    expect(current.expectedAmount, 4500000);
    expect(current.categoryId, sueldoCatId);
    expect(current.effectiveFrom, DateTime(2026, 10, 15));
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
}
