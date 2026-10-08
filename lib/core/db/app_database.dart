import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:pockt/core/db/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Categories,
  Transactions,
  SuggestedTransactions,
  RecurringRules,
  IncomeSchedules,
  Budgets,
  DayMarks,
  Settings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _seedCategories();
      },
    );
  }

  Future<void> _seedCategories() async {
    final seed = <CategoriesCompanion>[
      // 10 categorías de gasto
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000001'),
        name: Value('Comida'),
        icon: Value('🍔'),
        colorDark: Value(0xFFFF9F43),
        colorLight: Value(0xFFD9771A),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(0),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000002'),
        name: Value('Transporte'),
        icon: Value('🚗'),
        colorDark: Value(0xFF54A0FF),
        colorLight: Value(0xFF1F6FD1),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(1),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000003'),
        name: Value('Hogar'),
        icon: Value('🏠'),
        colorDark: Value(0xFF1DD1A1),
        colorLight: Value(0xFF0E9673),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(2),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000004'),
        name: Value('Salud'),
        icon: Value('💊'),
        colorDark: Value(0xFFFF6B6B),
        colorLight: Value(0xFFD64545),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(3),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000005'),
        name: Value('Ocio'),
        icon: Value('🍿'),
        colorDark: Value(0xFFC56CF0),
        colorLight: Value(0xFF9B3FC9),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(4),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000006'),
        name: Value('Servicios'),
        icon: Value('⚡'),
        colorDark: Value(0xFF48DBFB),
        colorLight: Value(0xFF0E9CBF),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(5),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000007'),
        name: Value('Educación'),
        icon: Value('📚'),
        colorDark: Value(0xFFA4B0BE),
        colorLight: Value(0xFF5D6B7A),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(6),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000008'),
        name: Value('Regalos'),
        icon: Value('🎁'),
        colorDark: Value(0xFFFECA57),
        colorLight: Value(0xFFC9921A),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(7),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000009'),
        name: Value('Ropa'),
        icon: Value('👕'),
        colorDark: Value(0xFFF368E0),
        colorLight: Value(0xFFC43BB2),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(8),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000010'),
        name: Value('Otros'),
        icon: Value('📦'),
        colorDark: Value(0xFF8395A7),
        colorLight: Value(0xFF556677),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(9),
      ),

      // 3 categorías de ingreso
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000011'),
        name: Value('Sueldo'),
        icon: Value('💼'),
        colorDark: Value(0xFF10B981),
        colorLight: Value(0xFF059669),
        kind: Value(CategoryKind.income),
        sortOrder: Value(0),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000012'),
        name: Value('Extra'),
        icon: Value('✨'),
        colorDark: Value(0xFF06B6D4),
        colorLight: Value(0xFF0891B2),
        kind: Value(CategoryKind.income),
        sortOrder: Value(1),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000013'),
        name: Value('Otros ingresos'),
        icon: Value('📥'),
        colorDark: Value(0xFF6366F1),
        colorLight: Value(0xFF4338CA),
        kind: Value(CategoryKind.income),
        sortOrder: Value(2),
      ),
    ];

    await batch((b) {
      b.insertAll(categories, seed);
    });
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'pockt');
  }
}
