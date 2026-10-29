// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SpikeTxTable extends SpikeTx with TableInfo<$SpikeTxTable, SpikeTxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpikeTxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<int> occurredAt = GeneratedColumn<int>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    amount,
    note,
    occurredAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spike_tx';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpikeTxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpikeTxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpikeTxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $SpikeTxTable createAlias(String alias) {
    return $SpikeTxTable(attachedDatabase, alias);
  }
}

class SpikeTxData extends DataClass implements Insertable<SpikeTxData> {
  final String id;
  final String userId;
  final int amount;
  final String? note;
  final int occurredAt;
  final int updatedAt;
  final int? deletedAt;
  const SpikeTxData({
    required this.id,
    required this.userId,
    required this.amount,
    this.note,
    required this.occurredAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['amount'] = Variable<int>(amount);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['occurred_at'] = Variable<int>(occurredAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  SpikeTxCompanion toCompanion(bool nullToAbsent) {
    return SpikeTxCompanion(
      id: Value(id),
      userId: Value(userId),
      amount: Value(amount),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      occurredAt: Value(occurredAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory SpikeTxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpikeTxData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      amount: serializer.fromJson<int>(json['amount']),
      note: serializer.fromJson<String?>(json['note']),
      occurredAt: serializer.fromJson<int>(json['occurredAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'amount': serializer.toJson<int>(amount),
      'note': serializer.toJson<String?>(note),
      'occurredAt': serializer.toJson<int>(occurredAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  SpikeTxData copyWith({
    String? id,
    String? userId,
    int? amount,
    Value<String?> note = const Value.absent(),
    int? occurredAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => SpikeTxData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    amount: amount ?? this.amount,
    note: note.present ? note.value : this.note,
    occurredAt: occurredAt ?? this.occurredAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  SpikeTxData copyWithCompanion(SpikeTxCompanion data) {
    return SpikeTxData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      amount: data.amount.present ? data.amount.value : this.amount,
      note: data.note.present ? data.note.value : this.note,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpikeTxData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('amount: $amount, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, amount, note, occurredAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpikeTxData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.amount == this.amount &&
          other.note == this.note &&
          other.occurredAt == this.occurredAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class SpikeTxCompanion extends UpdateCompanion<SpikeTxData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<int> amount;
  final Value<String?> note;
  final Value<int> occurredAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const SpikeTxCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.amount = const Value.absent(),
    this.note = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpikeTxCompanion.insert({
    required String id,
    required String userId,
    required int amount,
    this.note = const Value.absent(),
    required int occurredAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       amount = Value(amount),
       occurredAt = Value(occurredAt),
       updatedAt = Value(updatedAt);
  static Insertable<SpikeTxData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<int>? amount,
    Expression<String>? note,
    Expression<int>? occurredAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (amount != null) 'amount': amount,
      if (note != null) 'note': note,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpikeTxCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<int>? amount,
    Value<String?>? note,
    Value<int>? occurredAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return SpikeTxCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(occurredAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpikeTxCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('amount: $amount, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$SpikeDb extends GeneratedDatabase {
  _$SpikeDb(QueryExecutor e) : super(e);
  $SpikeDbManager get managers => $SpikeDbManager(this);
  late final $SpikeTxTable spikeTx = $SpikeTxTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [spikeTx];
}

typedef $$SpikeTxTableCreateCompanionBuilder = SpikeTxCompanion Function({
  required String id,
  required String userId,
  required int amount,
  Value<String?> note,
  required int occurredAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$SpikeTxTableUpdateCompanionBuilder = SpikeTxCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<int> amount,
  Value<String?> note,
  Value<int> occurredAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});

class $$SpikeTxTableFilterComposer extends Composer<_$SpikeDb, $SpikeTxTable> {
  $$SpikeTxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpikeTxTableOrderingComposer
    extends Composer<_$SpikeDb, $SpikeTxTable> {
  $$SpikeTxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpikeTxTableAnnotationComposer
    extends Composer<_$SpikeDb, $SpikeTxTable> {
  $$SpikeTxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$SpikeTxTableTableManager
    extends
        RootTableManager<
          _$SpikeDb,
          $SpikeTxTable,
          SpikeTxData,
          $$SpikeTxTableFilterComposer,
          $$SpikeTxTableOrderingComposer,
          $$SpikeTxTableAnnotationComposer,
          $$SpikeTxTableCreateCompanionBuilder,
          $$SpikeTxTableUpdateCompanionBuilder,
          (SpikeTxData, BaseReferences<_$SpikeDb, $SpikeTxTable, SpikeTxData>),
          SpikeTxData,
          PrefetchHooks Function()
        > {
  $$SpikeTxTableTableManager(_$SpikeDb db, $SpikeTxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpikeTxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpikeTxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpikeTxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> occurredAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpikeTxCompanion(
                id: id,
                userId: userId,
                amount: amount,
                note: note,
                occurredAt: occurredAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required int amount,
                Value<String?> note = const Value.absent(),
                required int occurredAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpikeTxCompanion.insert(
                id: id,
                userId: userId,
                amount: amount,
                note: note,
                occurredAt: occurredAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpikeTxTable, SpikeTxData>(table),
                  BaseReferences<_$SpikeDb, $SpikeTxTable, SpikeTxData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpikeTxTableProcessedTableManager =
    ProcessedTableManager<
      _$SpikeDb,
      $SpikeTxTable,
      SpikeTxData,
      $$SpikeTxTableFilterComposer,
      $$SpikeTxTableOrderingComposer,
      $$SpikeTxTableAnnotationComposer,
      $$SpikeTxTableCreateCompanionBuilder,
      $$SpikeTxTableUpdateCompanionBuilder,
      (SpikeTxData, BaseReferences<_$SpikeDb, $SpikeTxTable, SpikeTxData>),
      SpikeTxData,
      PrefetchHooks Function()
    >;

class $SpikeDbManager {
  final _$SpikeDb _db;
  $SpikeDbManager(this._db);
  $$SpikeTxTableTableManager get spikeTx =>
      $$SpikeTxTableTableManager(_db, _db.spikeTx);
}
