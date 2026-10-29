import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/sync/powersync_schema.dart';
import 'package:powersync/powersync.dart' as ps;

const syncedTables = {
  'transactions',
  'categories',
  'loans',
  'loan_installments',
  'goals',
  'goal_contributions',
  'budgets',
  'recurring_rules',
  'income_schedules',
  'salary_deductions',
  'events',
  'settings',
};

const localTables = {
  'suggested_transactions',
  'merchant_memory',
  'category_keywords',
  'counterparty_rules',
  'entry_shortcuts',
  'day_marks',
};

ps.ColumnType storageType(drift.GeneratedColumn column) =>
    switch (column.type) {
      drift.DriftSqlType.string => ps.ColumnType.text,
      drift.DriftSqlType.int ||
      drift.DriftSqlType.bigInt ||
      drift.DriftSqlType.bool ||
      drift.DriftSqlType.dateTime => ps.ColumnType.integer,
      drift.DriftSqlType.double => ps.ColumnType.real,
      _ => throw UnsupportedError(
        'Tipo de Drift sin equivalente PowerSync: ${column.type}',
      ),
    };

void main() {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  tearDownAll(db.close);

  test('schema válido con exactamente las 12 tablas sync y las 6 locales', () {
    expect(pocktPowerSyncSchema.validate, returnsNormally);
    final expected = {...syncedTables, ...localTables};
    expect(
      db.allTables.map((table) => table.actualTableName),
      unorderedEquals(expected),
    );
    expect(
      pocktPowerSyncSchema.tables.map((table) => table.name),
      unorderedEquals(expected),
    );
  });

  for (final driftTable in db.allTables) {
    final name = driftTable.actualTableName;
    test(
      '$name: columnas, tipos de almacenamiento y alcance iguales a Drift',
      () {
        final matches = pocktPowerSyncSchema.tables.where(
          (table) => table.name == name,
        );
        expect(
          matches,
          hasLength(1),
          reason: 'Debe existir una sola tabla $name',
        );
        final table = matches.single;
        expect(
          table.localOnly,
          localTables.contains(name),
          reason: '$name: alcance de sync',
        );
        // PowerSync agrega id; no depende de cuándo 2.1 lo agregue a Drift.
        final expected = {
          for (final column in driftTable.$columns)
            if (column.$name != 'id') column.$name: storageType(column),
        };
        expect(
          table.columns,
          hasLength(expected.length),
          reason: '$name: sin columnas extra ni duplicadas',
        );
        expect(
          {for (final column in table.columns) column.name: column.type},
          expected,
          reason:
              '$name: nombres SQL y tipos reales de Drift, sin id implícito',
        );
      },
    );
  }
}
