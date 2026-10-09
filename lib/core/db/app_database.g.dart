// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorDarkMeta = const VerificationMeta(
    'colorDark',
  );
  @override
  late final GeneratedColumn<int> colorDark = GeneratedColumn<int>(
    'color_dark',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorLightMeta = const VerificationMeta(
    'colorLight',
  );
  @override
  late final GeneratedColumn<int> colorLight = GeneratedColumn<int>(
    'color_light',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CategoryKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CategoryKind>($CategoriesTable.$converterkind);
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    icon,
    colorDark,
    colorLight,
    kind,
    sortOrder,
    archived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('color_dark')) {
      context.handle(
        _colorDarkMeta,
        colorDark.isAcceptableOrUnknown(data['color_dark']!, _colorDarkMeta),
      );
    } else if (isInserting) {
      context.missing(_colorDarkMeta);
    }
    if (data.containsKey('color_light')) {
      context.handle(
        _colorLightMeta,
        colorLight.isAcceptableOrUnknown(data['color_light']!, _colorLightMeta),
      );
    } else if (isInserting) {
      context.missing(_colorLightMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      colorDark: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_dark'],
      )!,
      colorLight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_light'],
      )!,
      kind: $CategoriesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CategoryKind, String, String> $converterkind =
      const EnumNameConverter<CategoryKind>(CategoryKind.values);
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String name;
  final String icon;
  final int colorDark;
  final int colorLight;
  final CategoryKind kind;
  final int sortOrder;
  final bool archived;
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorDark,
    required this.colorLight,
    required this.kind,
    required this.sortOrder,
    required this.archived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    map['color_dark'] = Variable<int>(colorDark);
    map['color_light'] = Variable<int>(colorLight);
    {
      map['kind'] = Variable<String>(
        $CategoriesTable.$converterkind.toSql(kind),
      );
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      icon: Value(icon),
      colorDark: Value(colorDark),
      colorLight: Value(colorLight),
      kind: Value(kind),
      sortOrder: Value(sortOrder),
      archived: Value(archived),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      colorDark: serializer.fromJson<int>(json['colorDark']),
      colorLight: serializer.fromJson<int>(json['colorLight']),
      kind: $CategoriesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'colorDark': serializer.toJson<int>(colorDark),
      'colorLight': serializer.toJson<int>(colorLight),
      'kind': serializer.toJson<String>(
        $CategoriesTable.$converterkind.toJson(kind),
      ),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    int? colorDark,
    int? colorLight,
    CategoryKind? kind,
    int? sortOrder,
    bool? archived,
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    colorDark: colorDark ?? this.colorDark,
    colorLight: colorLight ?? this.colorLight,
    kind: kind ?? this.kind,
    sortOrder: sortOrder ?? this.sortOrder,
    archived: archived ?? this.archived,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      colorDark: data.colorDark.present ? data.colorDark.value : this.colorDark,
      colorLight: data.colorLight.present
          ? data.colorLight.value
          : this.colorLight,
      kind: data.kind.present ? data.kind.value : this.kind,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('colorDark: $colorDark, ')
          ..write('colorLight: $colorLight, ')
          ..write('kind: $kind, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    icon,
    colorDark,
    colorLight,
    kind,
    sortOrder,
    archived,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.colorDark == this.colorDark &&
          other.colorLight == this.colorLight &&
          other.kind == this.kind &&
          other.sortOrder == this.sortOrder &&
          other.archived == this.archived);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> icon;
  final Value<int> colorDark;
  final Value<int> colorLight;
  final Value<CategoryKind> kind;
  final Value<int> sortOrder;
  final Value<bool> archived;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.colorDark = const Value.absent(),
    this.colorLight = const Value.absent(),
    this.kind = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String name,
    required String icon,
    required int colorDark,
    required int colorLight,
    required CategoryKind kind,
    required int sortOrder,
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       icon = Value(icon),
       colorDark = Value(colorDark),
       colorLight = Value(colorLight),
       kind = Value(kind),
       sortOrder = Value(sortOrder);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<int>? colorDark,
    Expression<int>? colorLight,
    Expression<String>? kind,
    Expression<int>? sortOrder,
    Expression<bool>? archived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (colorDark != null) 'color_dark': colorDark,
      if (colorLight != null) 'color_light': colorLight,
      if (kind != null) 'kind': kind,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (archived != null) 'archived': archived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? icon,
    Value<int>? colorDark,
    Value<int>? colorLight,
    Value<CategoryKind>? kind,
    Value<int>? sortOrder,
    Value<bool>? archived,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorDark: colorDark ?? this.colorDark,
      colorLight: colorLight ?? this.colorLight,
      kind: kind ?? this.kind,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (colorDark.present) {
      map['color_dark'] = Variable<int>(colorDark.value);
    }
    if (colorLight.present) {
      map['color_light'] = Variable<int>(colorLight.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $CategoriesTable.$converterkind.toSql(kind.value),
      );
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('colorDark: $colorDark, ')
          ..write('colorLight: $colorLight, ')
          ..write('kind: $kind, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TxType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TxType>($TransactionsTable.$convertertype);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PYG'),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _merchantMeta = const VerificationMeta(
    'merchant',
  );
  @override
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
    'merchant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TxSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TxSource>($TransactionsTable.$convertersource);
  static const VerificationMeta _recurringRuleIdMeta = const VerificationMeta(
    'recurringRuleId',
  );
  @override
  late final GeneratedColumn<String> recurringRuleId = GeneratedColumn<String>(
    'recurring_rule_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _suggestionIdMeta = const VerificationMeta(
    'suggestionId',
  );
  @override
  late final GeneratedColumn<String> suggestionId = GeneratedColumn<String>(
    'suggestion_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    amount,
    currency,
    categoryId,
    merchant,
    note,
    occurredAt,
    createdAt,
    updatedAt,
    source,
    recurringRuleId,
    suggestionId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('merchant')) {
      context.handle(
        _merchantMeta,
        merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta),
      );
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('recurring_rule_id')) {
      context.handle(
        _recurringRuleIdMeta,
        recurringRuleId.isAcceptableOrUnknown(
          data['recurring_rule_id']!,
          _recurringRuleIdMeta,
        ),
      );
    }
    if (data.containsKey('suggestion_id')) {
      context.handle(
        _suggestionIdMeta,
        suggestionId.isAcceptableOrUnknown(
          data['suggestion_id']!,
          _suggestionIdMeta,
        ),
      );
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
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: $TransactionsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      merchant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      source: $TransactionsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      recurringRuleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurring_rule_id'],
      ),
      suggestionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggestion_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TxType, String, String> $convertertype =
      const EnumNameConverter<TxType>(TxType.values);
  static JsonTypeConverter2<TxSource, String, String> $convertersource =
      const EnumNameConverter<TxSource>(TxSource.values);
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final String id;
  final TxType type;
  final int amount;
  final String currency;
  final String categoryId;
  final String? merchant;
  final String? note;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TxSource source;
  final String? recurringRuleId;
  final String? suggestionId;
  final DateTime? deletedAt;
  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.categoryId,
    this.merchant,
    this.note,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    required this.source,
    this.recurringRuleId,
    this.suggestionId,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['type'] = Variable<String>(
        $TransactionsTable.$convertertype.toSql(type),
      );
    }
    map['amount'] = Variable<int>(amount);
    map['currency'] = Variable<String>(currency);
    map['category_id'] = Variable<String>(categoryId);
    if (!nullToAbsent || merchant != null) {
      map['merchant'] = Variable<String>(merchant);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    {
      map['source'] = Variable<String>(
        $TransactionsTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || recurringRuleId != null) {
      map['recurring_rule_id'] = Variable<String>(recurringRuleId);
    }
    if (!nullToAbsent || suggestionId != null) {
      map['suggestion_id'] = Variable<String>(suggestionId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      type: Value(type),
      amount: Value(amount),
      currency: Value(currency),
      categoryId: Value(categoryId),
      merchant: merchant == null && nullToAbsent
          ? const Value.absent()
          : Value(merchant),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      occurredAt: Value(occurredAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      source: Value(source),
      recurringRuleId: recurringRuleId == null && nullToAbsent
          ? const Value.absent()
          : Value(recurringRuleId),
      suggestionId: suggestionId == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestionId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<String>(json['id']),
      type: $TransactionsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      amount: serializer.fromJson<int>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      merchant: serializer.fromJson<String?>(json['merchant']),
      note: serializer.fromJson<String?>(json['note']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      source: $TransactionsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      recurringRuleId: serializer.fromJson<String?>(json['recurringRuleId']),
      suggestionId: serializer.fromJson<String?>(json['suggestionId']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(
        $TransactionsTable.$convertertype.toJson(type),
      ),
      'amount': serializer.toJson<int>(amount),
      'currency': serializer.toJson<String>(currency),
      'categoryId': serializer.toJson<String>(categoryId),
      'merchant': serializer.toJson<String?>(merchant),
      'note': serializer.toJson<String?>(note),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'source': serializer.toJson<String>(
        $TransactionsTable.$convertersource.toJson(source),
      ),
      'recurringRuleId': serializer.toJson<String?>(recurringRuleId),
      'suggestionId': serializer.toJson<String?>(suggestionId),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Transaction copyWith({
    String? id,
    TxType? type,
    int? amount,
    String? currency,
    String? categoryId,
    Value<String?> merchant = const Value.absent(),
    Value<String?> note = const Value.absent(),
    DateTime? occurredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    TxSource? source,
    Value<String?> recurringRuleId = const Value.absent(),
    Value<String?> suggestionId = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Transaction(
    id: id ?? this.id,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    categoryId: categoryId ?? this.categoryId,
    merchant: merchant.present ? merchant.value : this.merchant,
    note: note.present ? note.value : this.note,
    occurredAt: occurredAt ?? this.occurredAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    source: source ?? this.source,
    recurringRuleId: recurringRuleId.present
        ? recurringRuleId.value
        : this.recurringRuleId,
    suggestionId: suggestionId.present ? suggestionId.value : this.suggestionId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      note: data.note.present ? data.note.value : this.note,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      source: data.source.present ? data.source.value : this.source,
      recurringRuleId: data.recurringRuleId.present
          ? data.recurringRuleId.value
          : this.recurringRuleId,
      suggestionId: data.suggestionId.present
          ? data.suggestionId.value
          : this.suggestionId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('categoryId: $categoryId, ')
          ..write('merchant: $merchant, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('source: $source, ')
          ..write('recurringRuleId: $recurringRuleId, ')
          ..write('suggestionId: $suggestionId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    amount,
    currency,
    categoryId,
    merchant,
    note,
    occurredAt,
    createdAt,
    updatedAt,
    source,
    recurringRuleId,
    suggestionId,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.categoryId == this.categoryId &&
          other.merchant == this.merchant &&
          other.note == this.note &&
          other.occurredAt == this.occurredAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.source == this.source &&
          other.recurringRuleId == this.recurringRuleId &&
          other.suggestionId == this.suggestionId &&
          other.deletedAt == this.deletedAt);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<String> id;
  final Value<TxType> type;
  final Value<int> amount;
  final Value<String> currency;
  final Value<String> categoryId;
  final Value<String?> merchant;
  final Value<String?> note;
  final Value<DateTime> occurredAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<TxSource> source;
  final Value<String?> recurringRuleId;
  final Value<String?> suggestionId;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.merchant = const Value.absent(),
    this.note = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.source = const Value.absent(),
    this.recurringRuleId = const Value.absent(),
    this.suggestionId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    required TxType type,
    required int amount,
    this.currency = const Value.absent(),
    required String categoryId,
    this.merchant = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime occurredAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    required TxSource source,
    this.recurringRuleId = const Value.absent(),
    this.suggestionId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       amount = Value(amount),
       categoryId = Value(categoryId),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       source = Value(source);
  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<int>? amount,
    Expression<String>? currency,
    Expression<String>? categoryId,
    Expression<String>? merchant,
    Expression<String>? note,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? source,
    Expression<String>? recurringRuleId,
    Expression<String>? suggestionId,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (categoryId != null) 'category_id': categoryId,
      if (merchant != null) 'merchant': merchant,
      if (note != null) 'note': note,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (source != null) 'source': source,
      if (recurringRuleId != null) 'recurring_rule_id': recurringRuleId,
      if (suggestionId != null) 'suggestion_id': suggestionId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<TxType>? type,
    Value<int>? amount,
    Value<String>? currency,
    Value<String>? categoryId,
    Value<String?>? merchant,
    Value<String?>? note,
    Value<DateTime>? occurredAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<TxSource>? source,
    Value<String?>? recurringRuleId,
    Value<String?>? suggestionId,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      merchant: merchant ?? this.merchant,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
      recurringRuleId: recurringRuleId ?? this.recurringRuleId,
      suggestionId: suggestionId ?? this.suggestionId,
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
    if (type.present) {
      map['type'] = Variable<String>(
        $TransactionsTable.$convertertype.toSql(type.value),
      );
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $TransactionsTable.$convertersource.toSql(source.value),
      );
    }
    if (recurringRuleId.present) {
      map['recurring_rule_id'] = Variable<String>(recurringRuleId.value);
    }
    if (suggestionId.present) {
      map['suggestion_id'] = Variable<String>(suggestionId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('categoryId: $categoryId, ')
          ..write('merchant: $merchant, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('source: $source, ')
          ..write('recurringRuleId: $recurringRuleId, ')
          ..write('suggestionId: $suggestionId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SuggestedTransactionsTable extends SuggestedTransactions
    with TableInfo<$SuggestedTransactionsTable, SuggestedTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SuggestedTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TxType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TxType>($SuggestedTransactionsTable.$convertertype);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PYG'),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _merchantMeta = const VerificationMeta(
    'merchant',
  );
  @override
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
    'merchant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TxSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TxSource>($SuggestedTransactionsTable.$convertersource);
  static const VerificationMeta _sourceRefMeta = const VerificationMeta(
    'sourceRef',
  );
  @override
  late final GeneratedColumn<String> sourceRef = GeneratedColumn<String>(
    'source_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id)',
    ),
  );
  static const VerificationMeta _rawTextMeta = const VerificationMeta(
    'rawText',
  );
  @override
  late final GeneratedColumn<String> rawText = GeneratedColumn<String>(
    'raw_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    amount,
    currency,
    categoryId,
    merchant,
    occurredAt,
    source,
    sourceRef,
    status,
    transactionId,
    rawText,
    fingerprint,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'suggested_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SuggestedTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('merchant')) {
      context.handle(
        _merchantMeta,
        merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta),
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
    if (data.containsKey('source_ref')) {
      context.handle(
        _sourceRefMeta,
        sourceRef.isAcceptableOrUnknown(data['source_ref']!, _sourceRefMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    }
    if (data.containsKey('raw_text')) {
      context.handle(
        _rawTextMeta,
        rawText.isAcceptableOrUnknown(data['raw_text']!, _rawTextMeta),
      );
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {source, sourceRef, occurredAt},
  ];
  @override
  SuggestedTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SuggestedTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: $SuggestedTransactionsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      merchant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      source: $SuggestedTransactionsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      sourceRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_ref'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      ),
      rawText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_text'],
      ),
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SuggestedTransactionsTable createAlias(String alias) {
    return $SuggestedTransactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TxType, String, String> $convertertype =
      const EnumNameConverter<TxType>(TxType.values);
  static JsonTypeConverter2<TxSource, String, String> $convertersource =
      const EnumNameConverter<TxSource>(TxSource.values);
}

class SuggestedTransaction extends DataClass
    implements Insertable<SuggestedTransaction> {
  final String id;
  final TxType type;
  final int amount;
  final String currency;
  final String? categoryId;
  final String? merchant;
  final DateTime occurredAt;
  final TxSource source;
  final String? sourceRef;
  final String status;
  final String? transactionId;
  final String? rawText;
  final String? fingerprint;
  final DateTime createdAt;
  const SuggestedTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    this.categoryId,
    this.merchant,
    required this.occurredAt,
    required this.source,
    this.sourceRef,
    required this.status,
    this.transactionId,
    this.rawText,
    this.fingerprint,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['type'] = Variable<String>(
        $SuggestedTransactionsTable.$convertertype.toSql(type),
      );
    }
    map['amount'] = Variable<int>(amount);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || merchant != null) {
      map['merchant'] = Variable<String>(merchant);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    {
      map['source'] = Variable<String>(
        $SuggestedTransactionsTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || sourceRef != null) {
      map['source_ref'] = Variable<String>(sourceRef);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<String>(transactionId);
    }
    if (!nullToAbsent || rawText != null) {
      map['raw_text'] = Variable<String>(rawText);
    }
    if (!nullToAbsent || fingerprint != null) {
      map['fingerprint'] = Variable<String>(fingerprint);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SuggestedTransactionsCompanion toCompanion(bool nullToAbsent) {
    return SuggestedTransactionsCompanion(
      id: Value(id),
      type: Value(type),
      amount: Value(amount),
      currency: Value(currency),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      merchant: merchant == null && nullToAbsent
          ? const Value.absent()
          : Value(merchant),
      occurredAt: Value(occurredAt),
      source: Value(source),
      sourceRef: sourceRef == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRef),
      status: Value(status),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      rawText: rawText == null && nullToAbsent
          ? const Value.absent()
          : Value(rawText),
      fingerprint: fingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(fingerprint),
      createdAt: Value(createdAt),
    );
  }

  factory SuggestedTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SuggestedTransaction(
      id: serializer.fromJson<String>(json['id']),
      type: $SuggestedTransactionsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      amount: serializer.fromJson<int>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      merchant: serializer.fromJson<String?>(json['merchant']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      source: $SuggestedTransactionsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      sourceRef: serializer.fromJson<String?>(json['sourceRef']),
      status: serializer.fromJson<String>(json['status']),
      transactionId: serializer.fromJson<String?>(json['transactionId']),
      rawText: serializer.fromJson<String?>(json['rawText']),
      fingerprint: serializer.fromJson<String?>(json['fingerprint']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(
        $SuggestedTransactionsTable.$convertertype.toJson(type),
      ),
      'amount': serializer.toJson<int>(amount),
      'currency': serializer.toJson<String>(currency),
      'categoryId': serializer.toJson<String?>(categoryId),
      'merchant': serializer.toJson<String?>(merchant),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'source': serializer.toJson<String>(
        $SuggestedTransactionsTable.$convertersource.toJson(source),
      ),
      'sourceRef': serializer.toJson<String?>(sourceRef),
      'status': serializer.toJson<String>(status),
      'transactionId': serializer.toJson<String?>(transactionId),
      'rawText': serializer.toJson<String?>(rawText),
      'fingerprint': serializer.toJson<String?>(fingerprint),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SuggestedTransaction copyWith({
    String? id,
    TxType? type,
    int? amount,
    String? currency,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> merchant = const Value.absent(),
    DateTime? occurredAt,
    TxSource? source,
    Value<String?> sourceRef = const Value.absent(),
    String? status,
    Value<String?> transactionId = const Value.absent(),
    Value<String?> rawText = const Value.absent(),
    Value<String?> fingerprint = const Value.absent(),
    DateTime? createdAt,
  }) => SuggestedTransaction(
    id: id ?? this.id,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    merchant: merchant.present ? merchant.value : this.merchant,
    occurredAt: occurredAt ?? this.occurredAt,
    source: source ?? this.source,
    sourceRef: sourceRef.present ? sourceRef.value : this.sourceRef,
    status: status ?? this.status,
    transactionId: transactionId.present
        ? transactionId.value
        : this.transactionId,
    rawText: rawText.present ? rawText.value : this.rawText,
    fingerprint: fingerprint.present ? fingerprint.value : this.fingerprint,
    createdAt: createdAt ?? this.createdAt,
  );
  SuggestedTransaction copyWithCompanion(SuggestedTransactionsCompanion data) {
    return SuggestedTransaction(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      source: data.source.present ? data.source.value : this.source,
      sourceRef: data.sourceRef.present ? data.sourceRef.value : this.sourceRef,
      status: data.status.present ? data.status.value : this.status,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      rawText: data.rawText.present ? data.rawText.value : this.rawText,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SuggestedTransaction(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('categoryId: $categoryId, ')
          ..write('merchant: $merchant, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('source: $source, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('status: $status, ')
          ..write('transactionId: $transactionId, ')
          ..write('rawText: $rawText, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    amount,
    currency,
    categoryId,
    merchant,
    occurredAt,
    source,
    sourceRef,
    status,
    transactionId,
    rawText,
    fingerprint,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SuggestedTransaction &&
          other.id == this.id &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.categoryId == this.categoryId &&
          other.merchant == this.merchant &&
          other.occurredAt == this.occurredAt &&
          other.source == this.source &&
          other.sourceRef == this.sourceRef &&
          other.status == this.status &&
          other.transactionId == this.transactionId &&
          other.rawText == this.rawText &&
          other.fingerprint == this.fingerprint &&
          other.createdAt == this.createdAt);
}

class SuggestedTransactionsCompanion
    extends UpdateCompanion<SuggestedTransaction> {
  final Value<String> id;
  final Value<TxType> type;
  final Value<int> amount;
  final Value<String> currency;
  final Value<String?> categoryId;
  final Value<String?> merchant;
  final Value<DateTime> occurredAt;
  final Value<TxSource> source;
  final Value<String?> sourceRef;
  final Value<String> status;
  final Value<String?> transactionId;
  final Value<String?> rawText;
  final Value<String?> fingerprint;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SuggestedTransactionsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.merchant = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceRef = const Value.absent(),
    this.status = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.rawText = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SuggestedTransactionsCompanion.insert({
    required String id,
    required TxType type,
    required int amount,
    this.currency = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.merchant = const Value.absent(),
    required DateTime occurredAt,
    required TxSource source,
    this.sourceRef = const Value.absent(),
    required String status,
    this.transactionId = const Value.absent(),
    this.rawText = const Value.absent(),
    this.fingerprint = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       amount = Value(amount),
       occurredAt = Value(occurredAt),
       source = Value(source),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<SuggestedTransaction> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<int>? amount,
    Expression<String>? currency,
    Expression<String>? categoryId,
    Expression<String>? merchant,
    Expression<DateTime>? occurredAt,
    Expression<String>? source,
    Expression<String>? sourceRef,
    Expression<String>? status,
    Expression<String>? transactionId,
    Expression<String>? rawText,
    Expression<String>? fingerprint,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (categoryId != null) 'category_id': categoryId,
      if (merchant != null) 'merchant': merchant,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (source != null) 'source': source,
      if (sourceRef != null) 'source_ref': sourceRef,
      if (status != null) 'status': status,
      if (transactionId != null) 'transaction_id': transactionId,
      if (rawText != null) 'raw_text': rawText,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SuggestedTransactionsCompanion copyWith({
    Value<String>? id,
    Value<TxType>? type,
    Value<int>? amount,
    Value<String>? currency,
    Value<String?>? categoryId,
    Value<String?>? merchant,
    Value<DateTime>? occurredAt,
    Value<TxSource>? source,
    Value<String?>? sourceRef,
    Value<String>? status,
    Value<String?>? transactionId,
    Value<String?>? rawText,
    Value<String?>? fingerprint,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SuggestedTransactionsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      merchant: merchant ?? this.merchant,
      occurredAt: occurredAt ?? this.occurredAt,
      source: source ?? this.source,
      sourceRef: sourceRef ?? this.sourceRef,
      status: status ?? this.status,
      transactionId: transactionId ?? this.transactionId,
      rawText: rawText ?? this.rawText,
      fingerprint: fingerprint ?? this.fingerprint,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $SuggestedTransactionsTable.$convertertype.toSql(type.value),
      );
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $SuggestedTransactionsTable.$convertersource.toSql(source.value),
      );
    }
    if (sourceRef.present) {
      map['source_ref'] = Variable<String>(sourceRef.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (rawText.present) {
      map['raw_text'] = Variable<String>(rawText.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SuggestedTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('categoryId: $categoryId, ')
          ..write('merchant: $merchant, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('source: $source, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('status: $status, ')
          ..write('transactionId: $transactionId, ')
          ..write('rawText: $rawText, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecurringRulesTable extends RecurringRules
    with TableInfo<$RecurringRulesTable, RecurringRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TxType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TxType>($RecurringRulesTable.$convertertype);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayOfMonthMeta = const VerificationMeta(
    'dayOfMonth',
  );
  @override
  late final GeneratedColumn<int> dayOfMonth = GeneratedColumn<int>(
    'day_of_month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayOfWeekMeta = const VerificationMeta(
    'dayOfWeek',
  );
  @override
  late final GeneratedColumn<int> dayOfWeek = GeneratedColumn<int>(
    'day_of_week',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monthOfYearMeta = const VerificationMeta(
    'monthOfYear',
  );
  @override
  late final GeneratedColumn<int> monthOfYear = GeneratedColumn<int>(
    'month_of_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextDueDateMeta = const VerificationMeta(
    'nextDueDate',
  );
  @override
  late final GeneratedColumn<DateTime> nextDueDate = GeneratedColumn<DateTime>(
    'next_due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    amount,
    categoryId,
    frequency,
    dayOfMonth,
    dayOfWeek,
    monthOfYear,
    nextDueDate,
    active,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurringRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    } else if (isInserting) {
      context.missing(_frequencyMeta);
    }
    if (data.containsKey('day_of_month')) {
      context.handle(
        _dayOfMonthMeta,
        dayOfMonth.isAcceptableOrUnknown(
          data['day_of_month']!,
          _dayOfMonthMeta,
        ),
      );
    }
    if (data.containsKey('day_of_week')) {
      context.handle(
        _dayOfWeekMeta,
        dayOfWeek.isAcceptableOrUnknown(data['day_of_week']!, _dayOfWeekMeta),
      );
    }
    if (data.containsKey('month_of_year')) {
      context.handle(
        _monthOfYearMeta,
        monthOfYear.isAcceptableOrUnknown(
          data['month_of_year']!,
          _monthOfYearMeta,
        ),
      );
    }
    if (data.containsKey('next_due_date')) {
      context.handle(
        _nextDueDateMeta,
        nextDueDate.isAcceptableOrUnknown(
          data['next_due_date']!,
          _nextDueDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextDueDateMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: $RecurringRulesTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency'],
      )!,
      dayOfMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_month'],
      ),
      dayOfWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_week'],
      ),
      monthOfYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month_of_year'],
      ),
      nextDueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_due_date'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
    );
  }

  @override
  $RecurringRulesTable createAlias(String alias) {
    return $RecurringRulesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TxType, String, String> $convertertype =
      const EnumNameConverter<TxType>(TxType.values);
}

class RecurringRule extends DataClass implements Insertable<RecurringRule> {
  final String id;
  final String name;
  final TxType type;
  final int amount;
  final String categoryId;
  final String frequency;
  final int? dayOfMonth;
  final int? dayOfWeek;
  final int? monthOfYear;
  final DateTime nextDueDate;
  final bool active;
  const RecurringRule({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.frequency,
    this.dayOfMonth,
    this.dayOfWeek,
    this.monthOfYear,
    required this.nextDueDate,
    required this.active,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    {
      map['type'] = Variable<String>(
        $RecurringRulesTable.$convertertype.toSql(type),
      );
    }
    map['amount'] = Variable<int>(amount);
    map['category_id'] = Variable<String>(categoryId);
    map['frequency'] = Variable<String>(frequency);
    if (!nullToAbsent || dayOfMonth != null) {
      map['day_of_month'] = Variable<int>(dayOfMonth);
    }
    if (!nullToAbsent || dayOfWeek != null) {
      map['day_of_week'] = Variable<int>(dayOfWeek);
    }
    if (!nullToAbsent || monthOfYear != null) {
      map['month_of_year'] = Variable<int>(monthOfYear);
    }
    map['next_due_date'] = Variable<DateTime>(nextDueDate);
    map['active'] = Variable<bool>(active);
    return map;
  }

  RecurringRulesCompanion toCompanion(bool nullToAbsent) {
    return RecurringRulesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      amount: Value(amount),
      categoryId: Value(categoryId),
      frequency: Value(frequency),
      dayOfMonth: dayOfMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfMonth),
      dayOfWeek: dayOfWeek == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfWeek),
      monthOfYear: monthOfYear == null && nullToAbsent
          ? const Value.absent()
          : Value(monthOfYear),
      nextDueDate: Value(nextDueDate),
      active: Value(active),
    );
  }

  factory RecurringRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringRule(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: $RecurringRulesTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      amount: serializer.fromJson<int>(json['amount']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      frequency: serializer.fromJson<String>(json['frequency']),
      dayOfMonth: serializer.fromJson<int?>(json['dayOfMonth']),
      dayOfWeek: serializer.fromJson<int?>(json['dayOfWeek']),
      monthOfYear: serializer.fromJson<int?>(json['monthOfYear']),
      nextDueDate: serializer.fromJson<DateTime>(json['nextDueDate']),
      active: serializer.fromJson<bool>(json['active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(
        $RecurringRulesTable.$convertertype.toJson(type),
      ),
      'amount': serializer.toJson<int>(amount),
      'categoryId': serializer.toJson<String>(categoryId),
      'frequency': serializer.toJson<String>(frequency),
      'dayOfMonth': serializer.toJson<int?>(dayOfMonth),
      'dayOfWeek': serializer.toJson<int?>(dayOfWeek),
      'monthOfYear': serializer.toJson<int?>(monthOfYear),
      'nextDueDate': serializer.toJson<DateTime>(nextDueDate),
      'active': serializer.toJson<bool>(active),
    };
  }

  RecurringRule copyWith({
    String? id,
    String? name,
    TxType? type,
    int? amount,
    String? categoryId,
    String? frequency,
    Value<int?> dayOfMonth = const Value.absent(),
    Value<int?> dayOfWeek = const Value.absent(),
    Value<int?> monthOfYear = const Value.absent(),
    DateTime? nextDueDate,
    bool? active,
  }) => RecurringRule(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    categoryId: categoryId ?? this.categoryId,
    frequency: frequency ?? this.frequency,
    dayOfMonth: dayOfMonth.present ? dayOfMonth.value : this.dayOfMonth,
    dayOfWeek: dayOfWeek.present ? dayOfWeek.value : this.dayOfWeek,
    monthOfYear: monthOfYear.present ? monthOfYear.value : this.monthOfYear,
    nextDueDate: nextDueDate ?? this.nextDueDate,
    active: active ?? this.active,
  );
  RecurringRule copyWithCompanion(RecurringRulesCompanion data) {
    return RecurringRule(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      dayOfMonth: data.dayOfMonth.present
          ? data.dayOfMonth.value
          : this.dayOfMonth,
      dayOfWeek: data.dayOfWeek.present ? data.dayOfWeek.value : this.dayOfWeek,
      monthOfYear: data.monthOfYear.present
          ? data.monthOfYear.value
          : this.monthOfYear,
      nextDueDate: data.nextDueDate.present
          ? data.nextDueDate.value
          : this.nextDueDate,
      active: data.active.present ? data.active.value : this.active,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringRule(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('frequency: $frequency, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('monthOfYear: $monthOfYear, ')
          ..write('nextDueDate: $nextDueDate, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    amount,
    categoryId,
    frequency,
    dayOfMonth,
    dayOfWeek,
    monthOfYear,
    nextDueDate,
    active,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringRule &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.categoryId == this.categoryId &&
          other.frequency == this.frequency &&
          other.dayOfMonth == this.dayOfMonth &&
          other.dayOfWeek == this.dayOfWeek &&
          other.monthOfYear == this.monthOfYear &&
          other.nextDueDate == this.nextDueDate &&
          other.active == this.active);
}

class RecurringRulesCompanion extends UpdateCompanion<RecurringRule> {
  final Value<String> id;
  final Value<String> name;
  final Value<TxType> type;
  final Value<int> amount;
  final Value<String> categoryId;
  final Value<String> frequency;
  final Value<int?> dayOfMonth;
  final Value<int?> dayOfWeek;
  final Value<int?> monthOfYear;
  final Value<DateTime> nextDueDate;
  final Value<bool> active;
  final Value<int> rowid;
  const RecurringRulesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.frequency = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.monthOfYear = const Value.absent(),
    this.nextDueDate = const Value.absent(),
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecurringRulesCompanion.insert({
    required String id,
    required String name,
    required TxType type,
    required int amount,
    required String categoryId,
    required String frequency,
    this.dayOfMonth = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.monthOfYear = const Value.absent(),
    required DateTime nextDueDate,
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type),
       amount = Value(amount),
       categoryId = Value(categoryId),
       frequency = Value(frequency),
       nextDueDate = Value(nextDueDate);
  static Insertable<RecurringRule> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<int>? amount,
    Expression<String>? categoryId,
    Expression<String>? frequency,
    Expression<int>? dayOfMonth,
    Expression<int>? dayOfWeek,
    Expression<int>? monthOfYear,
    Expression<DateTime>? nextDueDate,
    Expression<bool>? active,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (categoryId != null) 'category_id': categoryId,
      if (frequency != null) 'frequency': frequency,
      if (dayOfMonth != null) 'day_of_month': dayOfMonth,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      if (monthOfYear != null) 'month_of_year': monthOfYear,
      if (nextDueDate != null) 'next_due_date': nextDueDate,
      if (active != null) 'active': active,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecurringRulesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<TxType>? type,
    Value<int>? amount,
    Value<String>? categoryId,
    Value<String>? frequency,
    Value<int?>? dayOfMonth,
    Value<int?>? dayOfWeek,
    Value<int?>? monthOfYear,
    Value<DateTime>? nextDueDate,
    Value<bool>? active,
    Value<int>? rowid,
  }) {
    return RecurringRulesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      frequency: frequency ?? this.frequency,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      monthOfYear: monthOfYear ?? this.monthOfYear,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      active: active ?? this.active,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $RecurringRulesTable.$convertertype.toSql(type.value),
      );
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (dayOfMonth.present) {
      map['day_of_month'] = Variable<int>(dayOfMonth.value);
    }
    if (dayOfWeek.present) {
      map['day_of_week'] = Variable<int>(dayOfWeek.value);
    }
    if (monthOfYear.present) {
      map['month_of_year'] = Variable<int>(monthOfYear.value);
    }
    if (nextDueDate.present) {
      map['next_due_date'] = Variable<DateTime>(nextDueDate.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringRulesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('frequency: $frequency, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('monthOfYear: $monthOfYear, ')
          ..write('nextDueDate: $nextDueDate, ')
          ..write('active: $active, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IncomeSchedulesTable extends IncomeSchedules
    with TableInfo<$IncomeSchedulesTable, IncomeSchedule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IncomeSchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payDaysMeta = const VerificationMeta(
    'payDays',
  );
  @override
  late final GeneratedColumn<String> payDays = GeneratedColumn<String>(
    'pay_days',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payDayRulesMeta = const VerificationMeta(
    'payDayRules',
  );
  @override
  late final GeneratedColumn<String> payDayRules = GeneratedColumn<String>(
    'pay_day_rules',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthlyAmountMeta = const VerificationMeta(
    'monthlyAmount',
  );
  @override
  late final GeneratedColumn<int> monthlyAmount = GeneratedColumn<int>(
    'monthly_amount',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paySplitPercentsMeta = const VerificationMeta(
    'paySplitPercents',
  );
  @override
  late final GeneratedColumn<String> paySplitPercents = GeneratedColumn<String>(
    'pay_split_percents',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _effectiveFromMeta = const VerificationMeta(
    'effectiveFrom',
  );
  @override
  late final GeneratedColumn<DateTime> effectiveFrom =
      GeneratedColumn<DateTime>(
        'effective_from',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mode,
    payDays,
    payDayRules,
    monthlyAmount,
    paySplitPercents,
    categoryId,
    effectiveFrom,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'income_schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<IncomeSchedule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('pay_days')) {
      context.handle(
        _payDaysMeta,
        payDays.isAcceptableOrUnknown(data['pay_days']!, _payDaysMeta),
      );
    } else if (isInserting) {
      context.missing(_payDaysMeta);
    }
    if (data.containsKey('pay_day_rules')) {
      context.handle(
        _payDayRulesMeta,
        payDayRules.isAcceptableOrUnknown(
          data['pay_day_rules']!,
          _payDayRulesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payDayRulesMeta);
    }
    if (data.containsKey('monthly_amount')) {
      context.handle(
        _monthlyAmountMeta,
        monthlyAmount.isAcceptableOrUnknown(
          data['monthly_amount']!,
          _monthlyAmountMeta,
        ),
      );
    }
    if (data.containsKey('pay_split_percents')) {
      context.handle(
        _paySplitPercentsMeta,
        paySplitPercents.isAcceptableOrUnknown(
          data['pay_split_percents']!,
          _paySplitPercentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paySplitPercentsMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('effective_from')) {
      context.handle(
        _effectiveFromMeta,
        effectiveFrom.isAcceptableOrUnknown(
          data['effective_from']!,
          _effectiveFromMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_effectiveFromMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  IncomeSchedule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IncomeSchedule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      payDays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pay_days'],
      )!,
      payDayRules: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pay_day_rules'],
      )!,
      monthlyAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}monthly_amount'],
      ),
      paySplitPercents: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pay_split_percents'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      effectiveFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}effective_from'],
      )!,
    );
  }

  @override
  $IncomeSchedulesTable createAlias(String alias) {
    return $IncomeSchedulesTable(attachedDatabase, alias);
  }
}

class IncomeSchedule extends DataClass implements Insertable<IncomeSchedule> {
  final String id;
  final String mode;
  final String payDays;
  final String payDayRules;
  final int? monthlyAmount;
  final String paySplitPercents;
  final String categoryId;
  final DateTime effectiveFrom;
  const IncomeSchedule({
    required this.id,
    required this.mode,
    required this.payDays,
    required this.payDayRules,
    this.monthlyAmount,
    required this.paySplitPercents,
    required this.categoryId,
    required this.effectiveFrom,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mode'] = Variable<String>(mode);
    map['pay_days'] = Variable<String>(payDays);
    map['pay_day_rules'] = Variable<String>(payDayRules);
    if (!nullToAbsent || monthlyAmount != null) {
      map['monthly_amount'] = Variable<int>(monthlyAmount);
    }
    map['pay_split_percents'] = Variable<String>(paySplitPercents);
    map['category_id'] = Variable<String>(categoryId);
    map['effective_from'] = Variable<DateTime>(effectiveFrom);
    return map;
  }

  IncomeSchedulesCompanion toCompanion(bool nullToAbsent) {
    return IncomeSchedulesCompanion(
      id: Value(id),
      mode: Value(mode),
      payDays: Value(payDays),
      payDayRules: Value(payDayRules),
      monthlyAmount: monthlyAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(monthlyAmount),
      paySplitPercents: Value(paySplitPercents),
      categoryId: Value(categoryId),
      effectiveFrom: Value(effectiveFrom),
    );
  }

  factory IncomeSchedule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IncomeSchedule(
      id: serializer.fromJson<String>(json['id']),
      mode: serializer.fromJson<String>(json['mode']),
      payDays: serializer.fromJson<String>(json['payDays']),
      payDayRules: serializer.fromJson<String>(json['payDayRules']),
      monthlyAmount: serializer.fromJson<int?>(json['monthlyAmount']),
      paySplitPercents: serializer.fromJson<String>(json['paySplitPercents']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      effectiveFrom: serializer.fromJson<DateTime>(json['effectiveFrom']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mode': serializer.toJson<String>(mode),
      'payDays': serializer.toJson<String>(payDays),
      'payDayRules': serializer.toJson<String>(payDayRules),
      'monthlyAmount': serializer.toJson<int?>(monthlyAmount),
      'paySplitPercents': serializer.toJson<String>(paySplitPercents),
      'categoryId': serializer.toJson<String>(categoryId),
      'effectiveFrom': serializer.toJson<DateTime>(effectiveFrom),
    };
  }

  IncomeSchedule copyWith({
    String? id,
    String? mode,
    String? payDays,
    String? payDayRules,
    Value<int?> monthlyAmount = const Value.absent(),
    String? paySplitPercents,
    String? categoryId,
    DateTime? effectiveFrom,
  }) => IncomeSchedule(
    id: id ?? this.id,
    mode: mode ?? this.mode,
    payDays: payDays ?? this.payDays,
    payDayRules: payDayRules ?? this.payDayRules,
    monthlyAmount: monthlyAmount.present
        ? monthlyAmount.value
        : this.monthlyAmount,
    paySplitPercents: paySplitPercents ?? this.paySplitPercents,
    categoryId: categoryId ?? this.categoryId,
    effectiveFrom: effectiveFrom ?? this.effectiveFrom,
  );
  IncomeSchedule copyWithCompanion(IncomeSchedulesCompanion data) {
    return IncomeSchedule(
      id: data.id.present ? data.id.value : this.id,
      mode: data.mode.present ? data.mode.value : this.mode,
      payDays: data.payDays.present ? data.payDays.value : this.payDays,
      payDayRules: data.payDayRules.present
          ? data.payDayRules.value
          : this.payDayRules,
      monthlyAmount: data.monthlyAmount.present
          ? data.monthlyAmount.value
          : this.monthlyAmount,
      paySplitPercents: data.paySplitPercents.present
          ? data.paySplitPercents.value
          : this.paySplitPercents,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      effectiveFrom: data.effectiveFrom.present
          ? data.effectiveFrom.value
          : this.effectiveFrom,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IncomeSchedule(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('payDays: $payDays, ')
          ..write('payDayRules: $payDayRules, ')
          ..write('monthlyAmount: $monthlyAmount, ')
          ..write('paySplitPercents: $paySplitPercents, ')
          ..write('categoryId: $categoryId, ')
          ..write('effectiveFrom: $effectiveFrom')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mode,
    payDays,
    payDayRules,
    monthlyAmount,
    paySplitPercents,
    categoryId,
    effectiveFrom,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IncomeSchedule &&
          other.id == this.id &&
          other.mode == this.mode &&
          other.payDays == this.payDays &&
          other.payDayRules == this.payDayRules &&
          other.monthlyAmount == this.monthlyAmount &&
          other.paySplitPercents == this.paySplitPercents &&
          other.categoryId == this.categoryId &&
          other.effectiveFrom == this.effectiveFrom);
}

class IncomeSchedulesCompanion extends UpdateCompanion<IncomeSchedule> {
  final Value<String> id;
  final Value<String> mode;
  final Value<String> payDays;
  final Value<String> payDayRules;
  final Value<int?> monthlyAmount;
  final Value<String> paySplitPercents;
  final Value<String> categoryId;
  final Value<DateTime> effectiveFrom;
  final Value<int> rowid;
  const IncomeSchedulesCompanion({
    this.id = const Value.absent(),
    this.mode = const Value.absent(),
    this.payDays = const Value.absent(),
    this.payDayRules = const Value.absent(),
    this.monthlyAmount = const Value.absent(),
    this.paySplitPercents = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.effectiveFrom = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IncomeSchedulesCompanion.insert({
    required String id,
    required String mode,
    required String payDays,
    required String payDayRules,
    this.monthlyAmount = const Value.absent(),
    required String paySplitPercents,
    required String categoryId,
    required DateTime effectiveFrom,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mode = Value(mode),
       payDays = Value(payDays),
       payDayRules = Value(payDayRules),
       paySplitPercents = Value(paySplitPercents),
       categoryId = Value(categoryId),
       effectiveFrom = Value(effectiveFrom);
  static Insertable<IncomeSchedule> custom({
    Expression<String>? id,
    Expression<String>? mode,
    Expression<String>? payDays,
    Expression<String>? payDayRules,
    Expression<int>? monthlyAmount,
    Expression<String>? paySplitPercents,
    Expression<String>? categoryId,
    Expression<DateTime>? effectiveFrom,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mode != null) 'mode': mode,
      if (payDays != null) 'pay_days': payDays,
      if (payDayRules != null) 'pay_day_rules': payDayRules,
      if (monthlyAmount != null) 'monthly_amount': monthlyAmount,
      if (paySplitPercents != null) 'pay_split_percents': paySplitPercents,
      if (categoryId != null) 'category_id': categoryId,
      if (effectiveFrom != null) 'effective_from': effectiveFrom,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IncomeSchedulesCompanion copyWith({
    Value<String>? id,
    Value<String>? mode,
    Value<String>? payDays,
    Value<String>? payDayRules,
    Value<int?>? monthlyAmount,
    Value<String>? paySplitPercents,
    Value<String>? categoryId,
    Value<DateTime>? effectiveFrom,
    Value<int>? rowid,
  }) {
    return IncomeSchedulesCompanion(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      payDays: payDays ?? this.payDays,
      payDayRules: payDayRules ?? this.payDayRules,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      paySplitPercents: paySplitPercents ?? this.paySplitPercents,
      categoryId: categoryId ?? this.categoryId,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (payDays.present) {
      map['pay_days'] = Variable<String>(payDays.value);
    }
    if (payDayRules.present) {
      map['pay_day_rules'] = Variable<String>(payDayRules.value);
    }
    if (monthlyAmount.present) {
      map['monthly_amount'] = Variable<int>(monthlyAmount.value);
    }
    if (paySplitPercents.present) {
      map['pay_split_percents'] = Variable<String>(paySplitPercents.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (effectiveFrom.present) {
      map['effective_from'] = Variable<DateTime>(effectiveFrom.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IncomeSchedulesCompanion(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('payDays: $payDays, ')
          ..write('payDayRules: $payDayRules, ')
          ..write('monthlyAmount: $monthlyAmount, ')
          ..write('paySplitPercents: $paySplitPercents, ')
          ..write('categoryId: $categoryId, ')
          ..write('effectiveFrom: $effectiveFrom, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, Budget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _monthlyLimitMeta = const VerificationMeta(
    'monthlyLimit',
  );
  @override
  late final GeneratedColumn<int> monthlyLimit = GeneratedColumn<int>(
    'monthly_limit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alert80SentForMeta = const VerificationMeta(
    'alert80SentFor',
  );
  @override
  late final GeneratedColumn<String> alert80SentFor = GeneratedColumn<String>(
    'alert80_sent_for',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _alert100SentForMeta = const VerificationMeta(
    'alert100SentFor',
  );
  @override
  late final GeneratedColumn<String> alert100SentFor = GeneratedColumn<String>(
    'alert100_sent_for',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    categoryId,
    monthlyLimit,
    alert80SentFor,
    alert100SentFor,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Budget> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('monthly_limit')) {
      context.handle(
        _monthlyLimitMeta,
        monthlyLimit.isAcceptableOrUnknown(
          data['monthly_limit']!,
          _monthlyLimitMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_monthlyLimitMeta);
    }
    if (data.containsKey('alert80_sent_for')) {
      context.handle(
        _alert80SentForMeta,
        alert80SentFor.isAcceptableOrUnknown(
          data['alert80_sent_for']!,
          _alert80SentForMeta,
        ),
      );
    }
    if (data.containsKey('alert100_sent_for')) {
      context.handle(
        _alert100SentForMeta,
        alert100SentFor.isAcceptableOrUnknown(
          data['alert100_sent_for']!,
          _alert100SentForMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Budget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Budget(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      monthlyLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}monthly_limit'],
      )!,
      alert80SentFor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alert80_sent_for'],
      ),
      alert100SentFor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alert100_sent_for'],
      ),
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class Budget extends DataClass implements Insertable<Budget> {
  final String id;
  final String categoryId;
  final int monthlyLimit;
  final String? alert80SentFor;
  final String? alert100SentFor;
  const Budget({
    required this.id,
    required this.categoryId,
    required this.monthlyLimit,
    this.alert80SentFor,
    this.alert100SentFor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category_id'] = Variable<String>(categoryId);
    map['monthly_limit'] = Variable<int>(monthlyLimit);
    if (!nullToAbsent || alert80SentFor != null) {
      map['alert80_sent_for'] = Variable<String>(alert80SentFor);
    }
    if (!nullToAbsent || alert100SentFor != null) {
      map['alert100_sent_for'] = Variable<String>(alert100SentFor);
    }
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      monthlyLimit: Value(monthlyLimit),
      alert80SentFor: alert80SentFor == null && nullToAbsent
          ? const Value.absent()
          : Value(alert80SentFor),
      alert100SentFor: alert100SentFor == null && nullToAbsent
          ? const Value.absent()
          : Value(alert100SentFor),
    );
  }

  factory Budget.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Budget(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      monthlyLimit: serializer.fromJson<int>(json['monthlyLimit']),
      alert80SentFor: serializer.fromJson<String?>(json['alert80SentFor']),
      alert100SentFor: serializer.fromJson<String?>(json['alert100SentFor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String>(categoryId),
      'monthlyLimit': serializer.toJson<int>(monthlyLimit),
      'alert80SentFor': serializer.toJson<String?>(alert80SentFor),
      'alert100SentFor': serializer.toJson<String?>(alert100SentFor),
    };
  }

  Budget copyWith({
    String? id,
    String? categoryId,
    int? monthlyLimit,
    Value<String?> alert80SentFor = const Value.absent(),
    Value<String?> alert100SentFor = const Value.absent(),
  }) => Budget(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    monthlyLimit: monthlyLimit ?? this.monthlyLimit,
    alert80SentFor: alert80SentFor.present
        ? alert80SentFor.value
        : this.alert80SentFor,
    alert100SentFor: alert100SentFor.present
        ? alert100SentFor.value
        : this.alert100SentFor,
  );
  Budget copyWithCompanion(BudgetsCompanion data) {
    return Budget(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      monthlyLimit: data.monthlyLimit.present
          ? data.monthlyLimit.value
          : this.monthlyLimit,
      alert80SentFor: data.alert80SentFor.present
          ? data.alert80SentFor.value
          : this.alert80SentFor,
      alert100SentFor: data.alert100SentFor.present
          ? data.alert100SentFor.value
          : this.alert100SentFor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Budget(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('monthlyLimit: $monthlyLimit, ')
          ..write('alert80SentFor: $alert80SentFor, ')
          ..write('alert100SentFor: $alert100SentFor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    categoryId,
    monthlyLimit,
    alert80SentFor,
    alert100SentFor,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Budget &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.monthlyLimit == this.monthlyLimit &&
          other.alert80SentFor == this.alert80SentFor &&
          other.alert100SentFor == this.alert100SentFor);
}

class BudgetsCompanion extends UpdateCompanion<Budget> {
  final Value<String> id;
  final Value<String> categoryId;
  final Value<int> monthlyLimit;
  final Value<String?> alert80SentFor;
  final Value<String?> alert100SentFor;
  final Value<int> rowid;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.monthlyLimit = const Value.absent(),
    this.alert80SentFor = const Value.absent(),
    this.alert100SentFor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetsCompanion.insert({
    required String id,
    required String categoryId,
    required int monthlyLimit,
    this.alert80SentFor = const Value.absent(),
    this.alert100SentFor = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       categoryId = Value(categoryId),
       monthlyLimit = Value(monthlyLimit);
  static Insertable<Budget> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<int>? monthlyLimit,
    Expression<String>? alert80SentFor,
    Expression<String>? alert100SentFor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (monthlyLimit != null) 'monthly_limit': monthlyLimit,
      if (alert80SentFor != null) 'alert80_sent_for': alert80SentFor,
      if (alert100SentFor != null) 'alert100_sent_for': alert100SentFor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetsCompanion copyWith({
    Value<String>? id,
    Value<String>? categoryId,
    Value<int>? monthlyLimit,
    Value<String?>? alert80SentFor,
    Value<String?>? alert100SentFor,
    Value<int>? rowid,
  }) {
    return BudgetsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      alert80SentFor: alert80SentFor ?? this.alert80SentFor,
      alert100SentFor: alert100SentFor ?? this.alert100SentFor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (monthlyLimit.present) {
      map['monthly_limit'] = Variable<int>(monthlyLimit.value);
    }
    if (alert80SentFor.present) {
      map['alert80_sent_for'] = Variable<String>(alert80SentFor.value);
    }
    if (alert100SentFor.present) {
      map['alert100_sent_for'] = Variable<String>(alert100SentFor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('monthlyLimit: $monthlyLimit, ')
          ..write('alert80SentFor: $alert80SentFor, ')
          ..write('alert100SentFor: $alert100SentFor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DayMarksTable extends DayMarks with TableInfo<$DayMarksTable, DayMark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayMarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noSpendMeta = const VerificationMeta(
    'noSpend',
  );
  @override
  late final GeneratedColumn<bool> noSpend = GeneratedColumn<bool>(
    'no_spend',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("no_spend" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [date, noSpend];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_marks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayMark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('no_spend')) {
      context.handle(
        _noSpendMeta,
        noSpend.isAcceptableOrUnknown(data['no_spend']!, _noSpendMeta),
      );
    } else if (isInserting) {
      context.missing(_noSpendMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  DayMark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayMark(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      noSpend: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}no_spend'],
      )!,
    );
  }

  @override
  $DayMarksTable createAlias(String alias) {
    return $DayMarksTable(attachedDatabase, alias);
  }
}

class DayMark extends DataClass implements Insertable<DayMark> {
  final String date;
  final bool noSpend;
  const DayMark({required this.date, required this.noSpend});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    map['no_spend'] = Variable<bool>(noSpend);
    return map;
  }

  DayMarksCompanion toCompanion(bool nullToAbsent) {
    return DayMarksCompanion(date: Value(date), noSpend: Value(noSpend));
  }

  factory DayMark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayMark(
      date: serializer.fromJson<String>(json['date']),
      noSpend: serializer.fromJson<bool>(json['noSpend']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'noSpend': serializer.toJson<bool>(noSpend),
    };
  }

  DayMark copyWith({String? date, bool? noSpend}) =>
      DayMark(date: date ?? this.date, noSpend: noSpend ?? this.noSpend);
  DayMark copyWithCompanion(DayMarksCompanion data) {
    return DayMark(
      date: data.date.present ? data.date.value : this.date,
      noSpend: data.noSpend.present ? data.noSpend.value : this.noSpend,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayMark(')
          ..write('date: $date, ')
          ..write('noSpend: $noSpend')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, noSpend);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayMark &&
          other.date == this.date &&
          other.noSpend == this.noSpend);
}

class DayMarksCompanion extends UpdateCompanion<DayMark> {
  final Value<String> date;
  final Value<bool> noSpend;
  final Value<int> rowid;
  const DayMarksCompanion({
    this.date = const Value.absent(),
    this.noSpend = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayMarksCompanion.insert({
    required String date,
    required bool noSpend,
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       noSpend = Value(noSpend);
  static Insertable<DayMark> custom({
    Expression<String>? date,
    Expression<bool>? noSpend,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (noSpend != null) 'no_spend': noSpend,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayMarksCompanion copyWith({
    Value<String>? date,
    Value<bool>? noSpend,
    Value<int>? rowid,
  }) {
    return DayMarksCompanion(
      date: date ?? this.date,
      noSpend: noSpend ?? this.noSpend,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (noSpend.present) {
      map['no_spend'] = Variable<bool>(noSpend.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayMarksCompanion(')
          ..write('date: $date, ')
          ..write('noSpend: $noSpend, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoryKeywordsTable extends CategoryKeywords
    with TableInfo<$CategoryKeywordsTable, CategoryKeyword> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryKeywordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _keywordMeta = const VerificationMeta(
    'keyword',
  );
  @override
  late final GeneratedColumn<String> keyword = GeneratedColumn<String>(
    'keyword',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<KeywordSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<KeywordSource>($CategoryKeywordsTable.$convertersource);
  @override
  List<GeneratedColumn> get $columns => [id, categoryId, keyword, source];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_keywords';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryKeyword> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('keyword')) {
      context.handle(
        _keywordMeta,
        keyword.isAcceptableOrUnknown(data['keyword']!, _keywordMeta),
      );
    } else if (isInserting) {
      context.missing(_keywordMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {categoryId, keyword},
  ];
  @override
  CategoryKeyword map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryKeyword(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      keyword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keyword'],
      )!,
      source: $CategoryKeywordsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
    );
  }

  @override
  $CategoryKeywordsTable createAlias(String alias) {
    return $CategoryKeywordsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<KeywordSource, String, String> $convertersource =
      const EnumNameConverter<KeywordSource>(KeywordSource.values);
}

class CategoryKeyword extends DataClass implements Insertable<CategoryKeyword> {
  final String id;
  final String categoryId;
  final String keyword;
  final KeywordSource source;
  const CategoryKeyword({
    required this.id,
    required this.categoryId,
    required this.keyword,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category_id'] = Variable<String>(categoryId);
    map['keyword'] = Variable<String>(keyword);
    {
      map['source'] = Variable<String>(
        $CategoryKeywordsTable.$convertersource.toSql(source),
      );
    }
    return map;
  }

  CategoryKeywordsCompanion toCompanion(bool nullToAbsent) {
    return CategoryKeywordsCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      keyword: Value(keyword),
      source: Value(source),
    );
  }

  factory CategoryKeyword.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryKeyword(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      keyword: serializer.fromJson<String>(json['keyword']),
      source: $CategoryKeywordsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String>(categoryId),
      'keyword': serializer.toJson<String>(keyword),
      'source': serializer.toJson<String>(
        $CategoryKeywordsTable.$convertersource.toJson(source),
      ),
    };
  }

  CategoryKeyword copyWith({
    String? id,
    String? categoryId,
    String? keyword,
    KeywordSource? source,
  }) => CategoryKeyword(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    keyword: keyword ?? this.keyword,
    source: source ?? this.source,
  );
  CategoryKeyword copyWithCompanion(CategoryKeywordsCompanion data) {
    return CategoryKeyword(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      keyword: data.keyword.present ? data.keyword.value : this.keyword,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryKeyword(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('keyword: $keyword, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, categoryId, keyword, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryKeyword &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.keyword == this.keyword &&
          other.source == this.source);
}

class CategoryKeywordsCompanion extends UpdateCompanion<CategoryKeyword> {
  final Value<String> id;
  final Value<String> categoryId;
  final Value<String> keyword;
  final Value<KeywordSource> source;
  final Value<int> rowid;
  const CategoryKeywordsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.keyword = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryKeywordsCompanion.insert({
    required String id,
    required String categoryId,
    required String keyword,
    required KeywordSource source,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       categoryId = Value(categoryId),
       keyword = Value(keyword),
       source = Value(source);
  static Insertable<CategoryKeyword> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? keyword,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (keyword != null) 'keyword': keyword,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryKeywordsCompanion copyWith({
    Value<String>? id,
    Value<String>? categoryId,
    Value<String>? keyword,
    Value<KeywordSource>? source,
    Value<int>? rowid,
  }) {
    return CategoryKeywordsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      keyword: keyword ?? this.keyword,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (keyword.present) {
      map['keyword'] = Variable<String>(keyword.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $CategoryKeywordsTable.$convertersource.toSql(source.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryKeywordsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('keyword: $keyword, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MerchantMemoryTable extends MerchantMemory
    with TableInfo<$MerchantMemoryTable, MerchantMemoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MerchantMemoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _merchantKeyMeta = const VerificationMeta(
    'merchantKey',
  );
  @override
  late final GeneratedColumn<String> merchantKey = GeneratedColumn<String>(
    'merchant_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _usesMeta = const VerificationMeta('uses');
  @override
  late final GeneratedColumn<int> uses = GeneratedColumn<int>(
    'uses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    merchantKey,
    categoryId,
    uses,
    lastUsedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'merchant_memory';
  @override
  VerificationContext validateIntegrity(
    Insertable<MerchantMemoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('merchant_key')) {
      context.handle(
        _merchantKeyMeta,
        merchantKey.isAcceptableOrUnknown(
          data['merchant_key']!,
          _merchantKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_merchantKeyMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('uses')) {
      context.handle(
        _usesMeta,
        uses.isAcceptableOrUnknown(data['uses']!, _usesMeta),
      );
    } else if (isInserting) {
      context.missing(_usesMeta);
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUsedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {merchantKey, categoryId};
  @override
  MerchantMemoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MerchantMemoryData(
      merchantKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_key'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      uses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uses'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      )!,
    );
  }

  @override
  $MerchantMemoryTable createAlias(String alias) {
    return $MerchantMemoryTable(attachedDatabase, alias);
  }
}

class MerchantMemoryData extends DataClass
    implements Insertable<MerchantMemoryData> {
  final String merchantKey;
  final String categoryId;
  final int uses;
  final DateTime lastUsedAt;
  const MerchantMemoryData({
    required this.merchantKey,
    required this.categoryId,
    required this.uses,
    required this.lastUsedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['merchant_key'] = Variable<String>(merchantKey);
    map['category_id'] = Variable<String>(categoryId);
    map['uses'] = Variable<int>(uses);
    map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    return map;
  }

  MerchantMemoryCompanion toCompanion(bool nullToAbsent) {
    return MerchantMemoryCompanion(
      merchantKey: Value(merchantKey),
      categoryId: Value(categoryId),
      uses: Value(uses),
      lastUsedAt: Value(lastUsedAt),
    );
  }

  factory MerchantMemoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MerchantMemoryData(
      merchantKey: serializer.fromJson<String>(json['merchantKey']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      uses: serializer.fromJson<int>(json['uses']),
      lastUsedAt: serializer.fromJson<DateTime>(json['lastUsedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'merchantKey': serializer.toJson<String>(merchantKey),
      'categoryId': serializer.toJson<String>(categoryId),
      'uses': serializer.toJson<int>(uses),
      'lastUsedAt': serializer.toJson<DateTime>(lastUsedAt),
    };
  }

  MerchantMemoryData copyWith({
    String? merchantKey,
    String? categoryId,
    int? uses,
    DateTime? lastUsedAt,
  }) => MerchantMemoryData(
    merchantKey: merchantKey ?? this.merchantKey,
    categoryId: categoryId ?? this.categoryId,
    uses: uses ?? this.uses,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
  );
  MerchantMemoryData copyWithCompanion(MerchantMemoryCompanion data) {
    return MerchantMemoryData(
      merchantKey: data.merchantKey.present
          ? data.merchantKey.value
          : this.merchantKey,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      uses: data.uses.present ? data.uses.value : this.uses,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MerchantMemoryData(')
          ..write('merchantKey: $merchantKey, ')
          ..write('categoryId: $categoryId, ')
          ..write('uses: $uses, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(merchantKey, categoryId, uses, lastUsedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MerchantMemoryData &&
          other.merchantKey == this.merchantKey &&
          other.categoryId == this.categoryId &&
          other.uses == this.uses &&
          other.lastUsedAt == this.lastUsedAt);
}

class MerchantMemoryCompanion extends UpdateCompanion<MerchantMemoryData> {
  final Value<String> merchantKey;
  final Value<String> categoryId;
  final Value<int> uses;
  final Value<DateTime> lastUsedAt;
  final Value<int> rowid;
  const MerchantMemoryCompanion({
    this.merchantKey = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.uses = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MerchantMemoryCompanion.insert({
    required String merchantKey,
    required String categoryId,
    required int uses,
    required DateTime lastUsedAt,
    this.rowid = const Value.absent(),
  }) : merchantKey = Value(merchantKey),
       categoryId = Value(categoryId),
       uses = Value(uses),
       lastUsedAt = Value(lastUsedAt);
  static Insertable<MerchantMemoryData> custom({
    Expression<String>? merchantKey,
    Expression<String>? categoryId,
    Expression<int>? uses,
    Expression<DateTime>? lastUsedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (merchantKey != null) 'merchant_key': merchantKey,
      if (categoryId != null) 'category_id': categoryId,
      if (uses != null) 'uses': uses,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MerchantMemoryCompanion copyWith({
    Value<String>? merchantKey,
    Value<String>? categoryId,
    Value<int>? uses,
    Value<DateTime>? lastUsedAt,
    Value<int>? rowid,
  }) {
    return MerchantMemoryCompanion(
      merchantKey: merchantKey ?? this.merchantKey,
      categoryId: categoryId ?? this.categoryId,
      uses: uses ?? this.uses,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (merchantKey.present) {
      map['merchant_key'] = Variable<String>(merchantKey.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (uses.present) {
      map['uses'] = Variable<int>(uses.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MerchantMemoryCompanion(')
          ..write('merchantKey: $merchantKey, ')
          ..write('categoryId: $categoryId, ')
          ..write('uses: $uses, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $SuggestedTransactionsTable suggestedTransactions =
      $SuggestedTransactionsTable(this);
  late final $RecurringRulesTable recurringRules = $RecurringRulesTable(this);
  late final $IncomeSchedulesTable incomeSchedules = $IncomeSchedulesTable(
    this,
  );
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $DayMarksTable dayMarks = $DayMarksTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $CategoryKeywordsTable categoryKeywords = $CategoryKeywordsTable(
    this,
  );
  late final $MerchantMemoryTable merchantMemory = $MerchantMemoryTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    transactions,
    suggestedTransactions,
    recurringRules,
    incomeSchedules,
    budgets,
    dayMarks,
    settings,
    categoryKeywords,
    merchantMemory,
  ];
}

typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required String name,
  required String icon,
  required int colorDark,
  required int colorLight,
  required CategoryKind kind,
  required int sortOrder,
  Value<bool> archived,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> icon,
  Value<int> colorDark,
  Value<int> colorLight,
  Value<CategoryKind> kind,
  Value<int> sortOrder,
  Value<bool> archived,
  Value<int> rowid,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'categories__id__transactions__category_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $SuggestedTransactionsTable,
    List<SuggestedTransaction>
  >
  _suggestedTransactionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.suggestedTransactions,
        aliasName: 'categories__id__suggested_transactions__category_id',
      );

  $$SuggestedTransactionsTableProcessedTableManager
  get suggestedTransactionsRefs {
    final manager = $$SuggestedTransactionsTableTableManager(
      $_db,
      $_db.suggestedTransactions,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _suggestedTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecurringRulesTable, List<RecurringRule>>
  _recurringRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recurringRules,
    aliasName: 'categories__id__recurring_rules__category_id',
  );

  $$RecurringRulesTableProcessedTableManager get recurringRulesRefs {
    final manager = $$RecurringRulesTableTableManager(
      $_db,
      $_db.recurringRules,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recurringRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$IncomeSchedulesTable, List<IncomeSchedule>>
  _incomeSchedulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.incomeSchedules,
    aliasName: 'categories__id__income_schedules__category_id',
  );

  $$IncomeSchedulesTableProcessedTableManager get incomeSchedulesRefs {
    final manager = $$IncomeSchedulesTableTableManager(
      $_db,
      $_db.incomeSchedules,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _incomeSchedulesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BudgetsTable, List<Budget>> _budgetsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.budgets,
    aliasName: 'categories__id__budgets__category_id',
  );

  $$BudgetsTableProcessedTableManager get budgetsRefs {
    final manager = $$BudgetsTableTableManager(
      $_db,
      $_db.budgets,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_budgetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CategoryKeywordsTable, List<CategoryKeyword>>
  _categoryKeywordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.categoryKeywords,
    aliasName: 'categories__id__category_keywords__category_id',
  );

  $$CategoryKeywordsTableProcessedTableManager get categoryKeywordsRefs {
    final manager = $$CategoryKeywordsTableTableManager(
      $_db,
      $_db.categoryKeywords,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _categoryKeywordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MerchantMemoryTable, List<MerchantMemoryData>>
  _merchantMemoryRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.merchantMemory,
    aliasName: 'categories__id__merchant_memory__category_id',
  );

  $$MerchantMemoryTableProcessedTableManager get merchantMemoryRefs {
    final manager = $$MerchantMemoryTableTableManager(
      $_db,
      $_db.merchantMemory,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_merchantMemoryRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorDark => $composableBuilder(
    column: $table.colorDark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorLight => $composableBuilder(
    column: $table.colorLight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CategoryKind, CategoryKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> suggestedTransactionsRefs(
    Expression<bool> Function($$SuggestedTransactionsTableFilterComposer f) f,
  ) {
    final $$SuggestedTransactionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.suggestedTransactions,
          getReferencedColumn: (t) => t.categoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SuggestedTransactionsTableFilterComposer(
                $db: $db,
                $table: $db.suggestedTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> recurringRulesRefs(
    Expression<bool> Function($$RecurringRulesTableFilterComposer f) f,
  ) {
    final $$RecurringRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recurringRules,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringRulesTableFilterComposer(
            $db: $db,
            $table: $db.recurringRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> incomeSchedulesRefs(
    Expression<bool> Function($$IncomeSchedulesTableFilterComposer f) f,
  ) {
    final $$IncomeSchedulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.incomeSchedules,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IncomeSchedulesTableFilterComposer(
            $db: $db,
            $table: $db.incomeSchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> budgetsRefs(
    Expression<bool> Function($$BudgetsTableFilterComposer f) f,
  ) {
    final $$BudgetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgets,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetsTableFilterComposer(
            $db: $db,
            $table: $db.budgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> categoryKeywordsRefs(
    Expression<bool> Function($$CategoryKeywordsTableFilterComposer f) f,
  ) {
    final $$CategoryKeywordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categoryKeywords,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryKeywordsTableFilterComposer(
            $db: $db,
            $table: $db.categoryKeywords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> merchantMemoryRefs(
    Expression<bool> Function($$MerchantMemoryTableFilterComposer f) f,
  ) {
    final $$MerchantMemoryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.merchantMemory,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantMemoryTableFilterComposer(
            $db: $db,
            $table: $db.merchantMemory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorDark => $composableBuilder(
    column: $table.colorDark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorLight => $composableBuilder(
    column: $table.colorLight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get colorDark =>
      $composableBuilder(column: $table.colorDark, builder: (column) => column);

  GeneratedColumn<int> get colorLight => $composableBuilder(
    column: $table.colorLight,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<CategoryKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> suggestedTransactionsRefs<T extends Object>(
    Expression<T> Function($$SuggestedTransactionsTableAnnotationComposer a) f,
  ) {
    final $$SuggestedTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.suggestedTransactions,
          getReferencedColumn: (t) => t.categoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SuggestedTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.suggestedTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> recurringRulesRefs<T extends Object>(
    Expression<T> Function($$RecurringRulesTableAnnotationComposer a) f,
  ) {
    final $$RecurringRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recurringRules,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.recurringRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> incomeSchedulesRefs<T extends Object>(
    Expression<T> Function($$IncomeSchedulesTableAnnotationComposer a) f,
  ) {
    final $$IncomeSchedulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.incomeSchedules,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IncomeSchedulesTableAnnotationComposer(
            $db: $db,
            $table: $db.incomeSchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> budgetsRefs<T extends Object>(
    Expression<T> Function($$BudgetsTableAnnotationComposer a) f,
  ) {
    final $$BudgetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgets,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetsTableAnnotationComposer(
            $db: $db,
            $table: $db.budgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> categoryKeywordsRefs<T extends Object>(
    Expression<T> Function($$CategoryKeywordsTableAnnotationComposer a) f,
  ) {
    final $$CategoryKeywordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categoryKeywords,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryKeywordsTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryKeywords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> merchantMemoryRefs<T extends Object>(
    Expression<T> Function($$MerchantMemoryTableAnnotationComposer a) f,
  ) {
    final $$MerchantMemoryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.merchantMemory,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantMemoryTableAnnotationComposer(
            $db: $db,
            $table: $db.merchantMemory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({
            bool transactionsRefs,
            bool suggestedTransactionsRefs,
            bool recurringRulesRefs,
            bool incomeSchedulesRefs,
            bool budgetsRefs,
            bool categoryKeywordsRefs,
            bool merchantMemoryRefs,
          })
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<int> colorDark = const Value.absent(),
                Value<int> colorLight = const Value.absent(),
                Value<CategoryKind> kind = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                icon: icon,
                colorDark: colorDark,
                colorLight: colorLight,
                kind: kind,
                sortOrder: sortOrder,
                archived: archived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String icon,
                required int colorDark,
                required int colorLight,
                required CategoryKind kind,
                required int sortOrder,
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                icon: icon,
                colorDark: colorDark,
                colorLight: colorLight,
                kind: kind,
                sortOrder: sortOrder,
                archived: archived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, Category>(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                transactionsRefs = false,
                suggestedTransactionsRefs = false,
                recurringRulesRefs = false,
                incomeSchedulesRefs = false,
                budgetsRefs = false,
                categoryKeywordsRefs = false,
                merchantMemoryRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionsRefs) db.transactions,
                    if (suggestedTransactionsRefs) db.suggestedTransactions,
                    if (recurringRulesRefs) db.recurringRules,
                    if (incomeSchedulesRefs) db.incomeSchedules,
                    if (budgetsRefs) db.budgets,
                    if (categoryKeywordsRefs) db.categoryKeywords,
                    if (merchantMemoryRefs) db.merchantMemory,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (suggestedTransactionsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          SuggestedTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._suggestedTransactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).suggestedTransactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (recurringRulesRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          RecurringRule
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._recurringRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).recurringRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (incomeSchedulesRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          IncomeSchedule
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._incomeSchedulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).incomeSchedulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (budgetsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          Budget
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._budgetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).budgetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (categoryKeywordsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          CategoryKeyword
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._categoryKeywordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).categoryKeywordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (merchantMemoryRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          MerchantMemoryData
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._merchantMemoryRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).merchantMemoryRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({
        bool transactionsRefs,
        bool suggestedTransactionsRefs,
        bool recurringRulesRefs,
        bool incomeSchedulesRefs,
        bool budgetsRefs,
        bool categoryKeywordsRefs,
        bool merchantMemoryRefs,
      })
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      required String id,
      required TxType type,
      required int amount,
      Value<String> currency,
      required String categoryId,
      Value<String?> merchant,
      Value<String?> note,
      required DateTime occurredAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      required TxSource source,
      Value<String?> recurringRuleId,
      Value<String?> suggestionId,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<TxType> type,
      Value<int> amount,
      Value<String> currency,
      Value<String> categoryId,
      Value<String?> merchant,
      Value<String?> note,
      Value<DateTime> occurredAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<TxSource> source,
      Value<String?> recurringRuleId,
      Value<String?> suggestionId,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$TransactionsTableReferences
    extends BaseReferences<_$AppDatabase, $TransactionsTable, Transaction> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('transactions__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $SuggestedTransactionsTable,
    List<SuggestedTransaction>
  >
  _suggestedTransactionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.suggestedTransactions,
        aliasName: 'transactions__id__suggested_transactions__transaction_id',
      );

  $$SuggestedTransactionsTableProcessedTableManager
  get suggestedTransactionsRefs {
    final manager = $$SuggestedTransactionsTableTableManager(
      $_db,
      $_db.suggestedTransactions,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _suggestedTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<TxType, TxType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TxSource, TxSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get recurringRuleId => $composableBuilder(
    column: $table.recurringRuleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestionId => $composableBuilder(
    column: $table.suggestionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> suggestedTransactionsRefs(
    Expression<bool> Function($$SuggestedTransactionsTableFilterComposer f) f,
  ) {
    final $$SuggestedTransactionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.suggestedTransactions,
          getReferencedColumn: (t) => t.transactionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SuggestedTransactionsTableFilterComposer(
                $db: $db,
                $table: $db.suggestedTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurringRuleId => $composableBuilder(
    column: $table.recurringRuleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestionId => $composableBuilder(
    column: $table.suggestionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TxType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TxSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get recurringRuleId => $composableBuilder(
    column: $table.recurringRuleId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestionId => $composableBuilder(
    column: $table.suggestionId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> suggestedTransactionsRefs<T extends Object>(
    Expression<T> Function($$SuggestedTransactionsTableAnnotationComposer a) f,
  ) {
    final $$SuggestedTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.suggestedTransactions,
          getReferencedColumn: (t) => t.transactionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SuggestedTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.suggestedTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (Transaction, $$TransactionsTableReferences),
          Transaction,
          PrefetchHooks Function({
            bool categoryId,
            bool suggestedTransactionsRefs,
          })
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<TxType> type = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String?> merchant = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<TxSource> source = const Value.absent(),
                Value<String?> recurringRuleId = const Value.absent(),
                Value<String?> suggestionId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                type: type,
                amount: amount,
                currency: currency,
                categoryId: categoryId,
                merchant: merchant,
                note: note,
                occurredAt: occurredAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                source: source,
                recurringRuleId: recurringRuleId,
                suggestionId: suggestionId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required TxType type,
                required int amount,
                Value<String> currency = const Value.absent(),
                required String categoryId,
                Value<String?> merchant = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required DateTime occurredAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                required TxSource source,
                Value<String?> recurringRuleId = const Value.absent(),
                Value<String?> suggestionId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                type: type,
                amount: amount,
                currency: currency,
                categoryId: categoryId,
                merchant: merchant,
                note: note,
                occurredAt: occurredAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                source: source,
                recurringRuleId: recurringRuleId,
                suggestionId: suggestionId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransactionsTable, Transaction>(table),
                  $$TransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({categoryId = false, suggestedTransactionsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (suggestedTransactionsRefs) db.suggestedTransactions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$TransactionsTableReferences
                                ._categoryIdTable(db),
                            referencedColumn: $$TransactionsTableReferences
                                ._categoryIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (suggestedTransactionsRefs)
                        await $_getPrefetchedData<
                          Transaction,
                          $TransactionsTable,
                          SuggestedTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._suggestedTransactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).suggestedTransactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (Transaction, $$TransactionsTableReferences),
      Transaction,
      PrefetchHooks Function({bool categoryId, bool suggestedTransactionsRefs})
    >;
typedef $$SuggestedTransactionsTableCreateCompanionBuilder =
    SuggestedTransactionsCompanion Function({
      required String id,
      required TxType type,
      required int amount,
      Value<String> currency,
      Value<String?> categoryId,
      Value<String?> merchant,
      required DateTime occurredAt,
      required TxSource source,
      Value<String?> sourceRef,
      required String status,
      Value<String?> transactionId,
      Value<String?> rawText,
      Value<String?> fingerprint,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SuggestedTransactionsTableUpdateCompanionBuilder =
    SuggestedTransactionsCompanion Function({
      Value<String> id,
      Value<TxType> type,
      Value<int> amount,
      Value<String> currency,
      Value<String?> categoryId,
      Value<String?> merchant,
      Value<DateTime> occurredAt,
      Value<TxSource> source,
      Value<String?> sourceRef,
      Value<String> status,
      Value<String?> transactionId,
      Value<String?> rawText,
      Value<String?> fingerprint,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$SuggestedTransactionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SuggestedTransactionsTable,
          SuggestedTransaction
        > {
  $$SuggestedTransactionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) => db.categories
      .createAlias('suggested_transactions__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TransactionsTable _transactionIdTable(_$AppDatabase db) => db
      .transactions
      .createAlias('suggested_transactions__transaction_id__transactions__id');

  $$TransactionsTableProcessedTableManager? get transactionId {
    final $_column = $_itemColumn<String>('transaction_id');
    if ($_column == null) return null;
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SuggestedTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $SuggestedTransactionsTable> {
  $$SuggestedTransactionsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<TxType, TxType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TxSource, TxSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SuggestedTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SuggestedTransactionsTable> {
  $$SuggestedTransactionsTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SuggestedTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SuggestedTransactionsTable> {
  $$SuggestedTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TxType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TxSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceRef =>
      $composableBuilder(column: $table.sourceRef, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get rawText =>
      $composableBuilder(column: $table.rawText, builder: (column) => column);

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SuggestedTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SuggestedTransactionsTable,
          SuggestedTransaction,
          $$SuggestedTransactionsTableFilterComposer,
          $$SuggestedTransactionsTableOrderingComposer,
          $$SuggestedTransactionsTableAnnotationComposer,
          $$SuggestedTransactionsTableCreateCompanionBuilder,
          $$SuggestedTransactionsTableUpdateCompanionBuilder,
          (SuggestedTransaction, $$SuggestedTransactionsTableReferences),
          SuggestedTransaction,
          PrefetchHooks Function({bool categoryId, bool transactionId})
        > {
  $$SuggestedTransactionsTableTableManager(
    _$AppDatabase db,
    $SuggestedTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SuggestedTransactionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SuggestedTransactionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SuggestedTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<TxType> type = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> merchant = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<TxSource> source = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> transactionId = const Value.absent(),
                Value<String?> rawText = const Value.absent(),
                Value<String?> fingerprint = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SuggestedTransactionsCompanion(
                id: id,
                type: type,
                amount: amount,
                currency: currency,
                categoryId: categoryId,
                merchant: merchant,
                occurredAt: occurredAt,
                source: source,
                sourceRef: sourceRef,
                status: status,
                transactionId: transactionId,
                rawText: rawText,
                fingerprint: fingerprint,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required TxType type,
                required int amount,
                Value<String> currency = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> merchant = const Value.absent(),
                required DateTime occurredAt,
                required TxSource source,
                Value<String?> sourceRef = const Value.absent(),
                required String status,
                Value<String?> transactionId = const Value.absent(),
                Value<String?> rawText = const Value.absent(),
                Value<String?> fingerprint = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SuggestedTransactionsCompanion.insert(
                id: id,
                type: type,
                amount: amount,
                currency: currency,
                categoryId: categoryId,
                merchant: merchant,
                occurredAt: occurredAt,
                source: source,
                sourceRef: sourceRef,
                status: status,
                transactionId: transactionId,
                rawText: rawText,
                fingerprint: fingerprint,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $SuggestedTransactionsTable,
                    SuggestedTransaction
                  >(table),
                  $$SuggestedTransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false, transactionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$SuggestedTransactionsTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$SuggestedTransactionsTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (transactionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.transactionId,
                        referencedTable: $$SuggestedTransactionsTableReferences
                            ._transactionIdTable(db),
                        referencedColumn: $$SuggestedTransactionsTableReferences
                            ._transactionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SuggestedTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SuggestedTransactionsTable,
      SuggestedTransaction,
      $$SuggestedTransactionsTableFilterComposer,
      $$SuggestedTransactionsTableOrderingComposer,
      $$SuggestedTransactionsTableAnnotationComposer,
      $$SuggestedTransactionsTableCreateCompanionBuilder,
      $$SuggestedTransactionsTableUpdateCompanionBuilder,
      (SuggestedTransaction, $$SuggestedTransactionsTableReferences),
      SuggestedTransaction,
      PrefetchHooks Function({bool categoryId, bool transactionId})
    >;
typedef $$RecurringRulesTableCreateCompanionBuilder =
    RecurringRulesCompanion Function({
      required String id,
      required String name,
      required TxType type,
      required int amount,
      required String categoryId,
      required String frequency,
      Value<int?> dayOfMonth,
      Value<int?> dayOfWeek,
      Value<int?> monthOfYear,
      required DateTime nextDueDate,
      Value<bool> active,
      Value<int> rowid,
    });
typedef $$RecurringRulesTableUpdateCompanionBuilder =
    RecurringRulesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<TxType> type,
      Value<int> amount,
      Value<String> categoryId,
      Value<String> frequency,
      Value<int?> dayOfMonth,
      Value<int?> dayOfWeek,
      Value<int?> monthOfYear,
      Value<DateTime> nextDueDate,
      Value<bool> active,
      Value<int> rowid,
    });

final class $$RecurringRulesTableReferences
    extends BaseReferences<_$AppDatabase, $RecurringRulesTable, RecurringRule> {
  $$RecurringRulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('recurring_rules__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecurringRulesTableFilterComposer
    extends Composer<_$AppDatabase, $RecurringRulesTable> {
  $$RecurringRulesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TxType, TxType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthOfYear => $composableBuilder(
    column: $table.monthOfYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextDueDate => $composableBuilder(
    column: $table.nextDueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecurringRulesTable> {
  $$RecurringRulesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthOfYear => $composableBuilder(
    column: $table.monthOfYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextDueDate => $composableBuilder(
    column: $table.nextDueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecurringRulesTable> {
  $$RecurringRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TxType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dayOfWeek =>
      $composableBuilder(column: $table.dayOfWeek, builder: (column) => column);

  GeneratedColumn<int> get monthOfYear => $composableBuilder(
    column: $table.monthOfYear,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextDueDate => $composableBuilder(
    column: $table.nextDueDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecurringRulesTable,
          RecurringRule,
          $$RecurringRulesTableFilterComposer,
          $$RecurringRulesTableOrderingComposer,
          $$RecurringRulesTableAnnotationComposer,
          $$RecurringRulesTableCreateCompanionBuilder,
          $$RecurringRulesTableUpdateCompanionBuilder,
          (RecurringRule, $$RecurringRulesTableReferences),
          RecurringRule,
          PrefetchHooks Function({bool categoryId})
        > {
  $$RecurringRulesTableTableManager(
    _$AppDatabase db,
    $RecurringRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecurringRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecurringRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<TxType> type = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> frequency = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                Value<int?> dayOfWeek = const Value.absent(),
                Value<int?> monthOfYear = const Value.absent(),
                Value<DateTime> nextDueDate = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringRulesCompanion(
                id: id,
                name: name,
                type: type,
                amount: amount,
                categoryId: categoryId,
                frequency: frequency,
                dayOfMonth: dayOfMonth,
                dayOfWeek: dayOfWeek,
                monthOfYear: monthOfYear,
                nextDueDate: nextDueDate,
                active: active,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required TxType type,
                required int amount,
                required String categoryId,
                required String frequency,
                Value<int?> dayOfMonth = const Value.absent(),
                Value<int?> dayOfWeek = const Value.absent(),
                Value<int?> monthOfYear = const Value.absent(),
                required DateTime nextDueDate,
                Value<bool> active = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringRulesCompanion.insert(
                id: id,
                name: name,
                type: type,
                amount: amount,
                categoryId: categoryId,
                frequency: frequency,
                dayOfMonth: dayOfMonth,
                dayOfWeek: dayOfWeek,
                monthOfYear: monthOfYear,
                nextDueDate: nextDueDate,
                active: active,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecurringRulesTable, RecurringRule>(table),
                  $$RecurringRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$RecurringRulesTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$RecurringRulesTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecurringRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecurringRulesTable,
      RecurringRule,
      $$RecurringRulesTableFilterComposer,
      $$RecurringRulesTableOrderingComposer,
      $$RecurringRulesTableAnnotationComposer,
      $$RecurringRulesTableCreateCompanionBuilder,
      $$RecurringRulesTableUpdateCompanionBuilder,
      (RecurringRule, $$RecurringRulesTableReferences),
      RecurringRule,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$IncomeSchedulesTableCreateCompanionBuilder =
    IncomeSchedulesCompanion Function({
      required String id,
      required String mode,
      required String payDays,
      required String payDayRules,
      Value<int?> monthlyAmount,
      required String paySplitPercents,
      required String categoryId,
      required DateTime effectiveFrom,
      Value<int> rowid,
    });
typedef $$IncomeSchedulesTableUpdateCompanionBuilder =
    IncomeSchedulesCompanion Function({
      Value<String> id,
      Value<String> mode,
      Value<String> payDays,
      Value<String> payDayRules,
      Value<int?> monthlyAmount,
      Value<String> paySplitPercents,
      Value<String> categoryId,
      Value<DateTime> effectiveFrom,
      Value<int> rowid,
    });

final class $$IncomeSchedulesTableReferences
    extends
        BaseReferences<_$AppDatabase, $IncomeSchedulesTable, IncomeSchedule> {
  $$IncomeSchedulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) => db.categories
      .createAlias('income_schedules__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$IncomeSchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $IncomeSchedulesTable> {
  $$IncomeSchedulesTableFilterComposer({
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

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payDays => $composableBuilder(
    column: $table.payDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payDayRules => $composableBuilder(
    column: $table.payDayRules,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthlyAmount => $composableBuilder(
    column: $table.monthlyAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paySplitPercents => $composableBuilder(
    column: $table.paySplitPercents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get effectiveFrom => $composableBuilder(
    column: $table.effectiveFrom,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IncomeSchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $IncomeSchedulesTable> {
  $$IncomeSchedulesTableOrderingComposer({
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

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payDays => $composableBuilder(
    column: $table.payDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payDayRules => $composableBuilder(
    column: $table.payDayRules,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthlyAmount => $composableBuilder(
    column: $table.monthlyAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paySplitPercents => $composableBuilder(
    column: $table.paySplitPercents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get effectiveFrom => $composableBuilder(
    column: $table.effectiveFrom,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IncomeSchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $IncomeSchedulesTable> {
  $$IncomeSchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get payDays =>
      $composableBuilder(column: $table.payDays, builder: (column) => column);

  GeneratedColumn<String> get payDayRules => $composableBuilder(
    column: $table.payDayRules,
    builder: (column) => column,
  );

  GeneratedColumn<int> get monthlyAmount => $composableBuilder(
    column: $table.monthlyAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paySplitPercents => $composableBuilder(
    column: $table.paySplitPercents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get effectiveFrom => $composableBuilder(
    column: $table.effectiveFrom,
    builder: (column) => column,
  );

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IncomeSchedulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IncomeSchedulesTable,
          IncomeSchedule,
          $$IncomeSchedulesTableFilterComposer,
          $$IncomeSchedulesTableOrderingComposer,
          $$IncomeSchedulesTableAnnotationComposer,
          $$IncomeSchedulesTableCreateCompanionBuilder,
          $$IncomeSchedulesTableUpdateCompanionBuilder,
          (IncomeSchedule, $$IncomeSchedulesTableReferences),
          IncomeSchedule,
          PrefetchHooks Function({bool categoryId})
        > {
  $$IncomeSchedulesTableTableManager(
    _$AppDatabase db,
    $IncomeSchedulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IncomeSchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IncomeSchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IncomeSchedulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> payDays = const Value.absent(),
                Value<String> payDayRules = const Value.absent(),
                Value<int?> monthlyAmount = const Value.absent(),
                Value<String> paySplitPercents = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<DateTime> effectiveFrom = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IncomeSchedulesCompanion(
                id: id,
                mode: mode,
                payDays: payDays,
                payDayRules: payDayRules,
                monthlyAmount: monthlyAmount,
                paySplitPercents: paySplitPercents,
                categoryId: categoryId,
                effectiveFrom: effectiveFrom,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String mode,
                required String payDays,
                required String payDayRules,
                Value<int?> monthlyAmount = const Value.absent(),
                required String paySplitPercents,
                required String categoryId,
                required DateTime effectiveFrom,
                Value<int> rowid = const Value.absent(),
              }) => IncomeSchedulesCompanion.insert(
                id: id,
                mode: mode,
                payDays: payDays,
                payDayRules: payDayRules,
                monthlyAmount: monthlyAmount,
                paySplitPercents: paySplitPercents,
                categoryId: categoryId,
                effectiveFrom: effectiveFrom,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IncomeSchedulesTable, IncomeSchedule>(table),
                  $$IncomeSchedulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$IncomeSchedulesTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$IncomeSchedulesTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$IncomeSchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IncomeSchedulesTable,
      IncomeSchedule,
      $$IncomeSchedulesTableFilterComposer,
      $$IncomeSchedulesTableOrderingComposer,
      $$IncomeSchedulesTableAnnotationComposer,
      $$IncomeSchedulesTableCreateCompanionBuilder,
      $$IncomeSchedulesTableUpdateCompanionBuilder,
      (IncomeSchedule, $$IncomeSchedulesTableReferences),
      IncomeSchedule,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$BudgetsTableCreateCompanionBuilder = BudgetsCompanion Function({
  required String id,
  required String categoryId,
  required int monthlyLimit,
  Value<String?> alert80SentFor,
  Value<String?> alert100SentFor,
  Value<int> rowid,
});
typedef $$BudgetsTableUpdateCompanionBuilder = BudgetsCompanion Function({
  Value<String> id,
  Value<String> categoryId,
  Value<int> monthlyLimit,
  Value<String?> alert80SentFor,
  Value<String?> alert100SentFor,
  Value<int> rowid,
});

final class $$BudgetsTableReferences
    extends BaseReferences<_$AppDatabase, $BudgetsTable, Budget> {
  $$BudgetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('budgets__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
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

  ColumnFilters<int> get monthlyLimit => $composableBuilder(
    column: $table.monthlyLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alert80SentFor => $composableBuilder(
    column: $table.alert80SentFor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alert100SentFor => $composableBuilder(
    column: $table.alert100SentFor,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
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

  ColumnOrderings<int> get monthlyLimit => $composableBuilder(
    column: $table.monthlyLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alert80SentFor => $composableBuilder(
    column: $table.alert80SentFor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alert100SentFor => $composableBuilder(
    column: $table.alert100SentFor,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get monthlyLimit => $composableBuilder(
    column: $table.monthlyLimit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alert80SentFor => $composableBuilder(
    column: $table.alert80SentFor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alert100SentFor => $composableBuilder(
    column: $table.alert100SentFor,
    builder: (column) => column,
  );

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetsTable,
          Budget,
          $$BudgetsTableFilterComposer,
          $$BudgetsTableOrderingComposer,
          $$BudgetsTableAnnotationComposer,
          $$BudgetsTableCreateCompanionBuilder,
          $$BudgetsTableUpdateCompanionBuilder,
          (Budget, $$BudgetsTableReferences),
          Budget,
          PrefetchHooks Function({bool categoryId})
        > {
  $$BudgetsTableTableManager(_$AppDatabase db, $BudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<int> monthlyLimit = const Value.absent(),
                Value<String?> alert80SentFor = const Value.absent(),
                Value<String?> alert100SentFor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion(
                id: id,
                categoryId: categoryId,
                monthlyLimit: monthlyLimit,
                alert80SentFor: alert80SentFor,
                alert100SentFor: alert100SentFor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String categoryId,
                required int monthlyLimit,
                Value<String?> alert80SentFor = const Value.absent(),
                Value<String?> alert100SentFor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion.insert(
                id: id,
                categoryId: categoryId,
                monthlyLimit: monthlyLimit,
                alert80SentFor: alert80SentFor,
                alert100SentFor: alert100SentFor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BudgetsTable, Budget>(table),
                  $$BudgetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$BudgetsTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$BudgetsTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetsTable,
      Budget,
      $$BudgetsTableFilterComposer,
      $$BudgetsTableOrderingComposer,
      $$BudgetsTableAnnotationComposer,
      $$BudgetsTableCreateCompanionBuilder,
      $$BudgetsTableUpdateCompanionBuilder,
      (Budget, $$BudgetsTableReferences),
      Budget,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$DayMarksTableCreateCompanionBuilder = DayMarksCompanion Function({
  required String date,
  required bool noSpend,
  Value<int> rowid,
});
typedef $$DayMarksTableUpdateCompanionBuilder = DayMarksCompanion Function({
  Value<String> date,
  Value<bool> noSpend,
  Value<int> rowid,
});

class $$DayMarksTableFilterComposer
    extends Composer<_$AppDatabase, $DayMarksTable> {
  $$DayMarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get noSpend => $composableBuilder(
    column: $table.noSpend,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DayMarksTableOrderingComposer
    extends Composer<_$AppDatabase, $DayMarksTable> {
  $$DayMarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get noSpend => $composableBuilder(
    column: $table.noSpend,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DayMarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayMarksTable> {
  $$DayMarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<bool> get noSpend =>
      $composableBuilder(column: $table.noSpend, builder: (column) => column);
}

class $$DayMarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayMarksTable,
          DayMark,
          $$DayMarksTableFilterComposer,
          $$DayMarksTableOrderingComposer,
          $$DayMarksTableAnnotationComposer,
          $$DayMarksTableCreateCompanionBuilder,
          $$DayMarksTableUpdateCompanionBuilder,
          (DayMark, BaseReferences<_$AppDatabase, $DayMarksTable, DayMark>),
          DayMark,
          PrefetchHooks Function()
        > {
  $$DayMarksTableTableManager(_$AppDatabase db, $DayMarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayMarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayMarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayMarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> date = const Value.absent(),
            Value<bool> noSpend = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => DayMarksCompanion(date: date, noSpend: noSpend, rowid: rowid),
          createCompanionCallback:
              ({
                required String date,
                required bool noSpend,
                Value<int> rowid = const Value.absent(),
              }) => DayMarksCompanion.insert(
                date: date,
                noSpend: noSpend,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DayMarksTable, DayMark>(table),
                  BaseReferences<_$AppDatabase, $DayMarksTable, DayMark>(
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

typedef $$DayMarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayMarksTable,
      DayMark,
      $$DayMarksTableFilterComposer,
      $$DayMarksTableOrderingComposer,
      $$DayMarksTableAnnotationComposer,
      $$DayMarksTableCreateCompanionBuilder,
      $$DayMarksTableUpdateCompanionBuilder,
      (DayMark, BaseReferences<_$AppDatabase, $DayMarksTable, DayMark>),
      DayMark,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
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

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$CategoryKeywordsTableCreateCompanionBuilder =
    CategoryKeywordsCompanion Function({
      required String id,
      required String categoryId,
      required String keyword,
      required KeywordSource source,
      Value<int> rowid,
    });
typedef $$CategoryKeywordsTableUpdateCompanionBuilder =
    CategoryKeywordsCompanion Function({
      Value<String> id,
      Value<String> categoryId,
      Value<String> keyword,
      Value<KeywordSource> source,
      Value<int> rowid,
    });

final class $$CategoryKeywordsTableReferences
    extends
        BaseReferences<_$AppDatabase, $CategoryKeywordsTable, CategoryKeyword> {
  $$CategoryKeywordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) => db.categories
      .createAlias('category_keywords__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CategoryKeywordsTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryKeywordsTable> {
  $$CategoryKeywordsTableFilterComposer({
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

  ColumnFilters<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<KeywordSource, KeywordSource, String>
  get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryKeywordsTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryKeywordsTable> {
  $$CategoryKeywordsTableOrderingComposer({
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

  ColumnOrderings<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryKeywordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryKeywordsTable> {
  $$CategoryKeywordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get keyword =>
      $composableBuilder(column: $table.keyword, builder: (column) => column);

  GeneratedColumnWithTypeConverter<KeywordSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryKeywordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoryKeywordsTable,
          CategoryKeyword,
          $$CategoryKeywordsTableFilterComposer,
          $$CategoryKeywordsTableOrderingComposer,
          $$CategoryKeywordsTableAnnotationComposer,
          $$CategoryKeywordsTableCreateCompanionBuilder,
          $$CategoryKeywordsTableUpdateCompanionBuilder,
          (CategoryKeyword, $$CategoryKeywordsTableReferences),
          CategoryKeyword,
          PrefetchHooks Function({bool categoryId})
        > {
  $$CategoryKeywordsTableTableManager(
    _$AppDatabase db,
    $CategoryKeywordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryKeywordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryKeywordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryKeywordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> keyword = const Value.absent(),
                Value<KeywordSource> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryKeywordsCompanion(
                id: id,
                categoryId: categoryId,
                keyword: keyword,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String categoryId,
                required String keyword,
                required KeywordSource source,
                Value<int> rowid = const Value.absent(),
              }) => CategoryKeywordsCompanion.insert(
                id: id,
                categoryId: categoryId,
                keyword: keyword,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoryKeywordsTable, CategoryKeyword>(table),
                  $$CategoryKeywordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$CategoryKeywordsTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$CategoryKeywordsTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CategoryKeywordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoryKeywordsTable,
      CategoryKeyword,
      $$CategoryKeywordsTableFilterComposer,
      $$CategoryKeywordsTableOrderingComposer,
      $$CategoryKeywordsTableAnnotationComposer,
      $$CategoryKeywordsTableCreateCompanionBuilder,
      $$CategoryKeywordsTableUpdateCompanionBuilder,
      (CategoryKeyword, $$CategoryKeywordsTableReferences),
      CategoryKeyword,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$MerchantMemoryTableCreateCompanionBuilder =
    MerchantMemoryCompanion Function({
      required String merchantKey,
      required String categoryId,
      required int uses,
      required DateTime lastUsedAt,
      Value<int> rowid,
    });
typedef $$MerchantMemoryTableUpdateCompanionBuilder =
    MerchantMemoryCompanion Function({
      Value<String> merchantKey,
      Value<String> categoryId,
      Value<int> uses,
      Value<DateTime> lastUsedAt,
      Value<int> rowid,
    });

final class $$MerchantMemoryTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MerchantMemoryTable,
          MerchantMemoryData
        > {
  $$MerchantMemoryTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('merchant_memory__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MerchantMemoryTableFilterComposer
    extends Composer<_$AppDatabase, $MerchantMemoryTable> {
  $$MerchantMemoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get merchantKey => $composableBuilder(
    column: $table.merchantKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uses => $composableBuilder(
    column: $table.uses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MerchantMemoryTableOrderingComposer
    extends Composer<_$AppDatabase, $MerchantMemoryTable> {
  $$MerchantMemoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get merchantKey => $composableBuilder(
    column: $table.merchantKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uses => $composableBuilder(
    column: $table.uses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MerchantMemoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $MerchantMemoryTable> {
  $$MerchantMemoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get merchantKey => $composableBuilder(
    column: $table.merchantKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get uses =>
      $composableBuilder(column: $table.uses, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MerchantMemoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MerchantMemoryTable,
          MerchantMemoryData,
          $$MerchantMemoryTableFilterComposer,
          $$MerchantMemoryTableOrderingComposer,
          $$MerchantMemoryTableAnnotationComposer,
          $$MerchantMemoryTableCreateCompanionBuilder,
          $$MerchantMemoryTableUpdateCompanionBuilder,
          (MerchantMemoryData, $$MerchantMemoryTableReferences),
          MerchantMemoryData,
          PrefetchHooks Function({bool categoryId})
        > {
  $$MerchantMemoryTableTableManager(
    _$AppDatabase db,
    $MerchantMemoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MerchantMemoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MerchantMemoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MerchantMemoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> merchantKey = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<int> uses = const Value.absent(),
                Value<DateTime> lastUsedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MerchantMemoryCompanion(
                merchantKey: merchantKey,
                categoryId: categoryId,
                uses: uses,
                lastUsedAt: lastUsedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String merchantKey,
                required String categoryId,
                required int uses,
                required DateTime lastUsedAt,
                Value<int> rowid = const Value.absent(),
              }) => MerchantMemoryCompanion.insert(
                merchantKey: merchantKey,
                categoryId: categoryId,
                uses: uses,
                lastUsedAt: lastUsedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MerchantMemoryTable, MerchantMemoryData>(table),
                  $$MerchantMemoryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$MerchantMemoryTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$MerchantMemoryTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MerchantMemoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MerchantMemoryTable,
      MerchantMemoryData,
      $$MerchantMemoryTableFilterComposer,
      $$MerchantMemoryTableOrderingComposer,
      $$MerchantMemoryTableAnnotationComposer,
      $$MerchantMemoryTableCreateCompanionBuilder,
      $$MerchantMemoryTableUpdateCompanionBuilder,
      (MerchantMemoryData, $$MerchantMemoryTableReferences),
      MerchantMemoryData,
      PrefetchHooks Function({bool categoryId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$SuggestedTransactionsTableTableManager get suggestedTransactions =>
      $$SuggestedTransactionsTableTableManager(_db, _db.suggestedTransactions);
  $$RecurringRulesTableTableManager get recurringRules =>
      $$RecurringRulesTableTableManager(_db, _db.recurringRules);
  $$IncomeSchedulesTableTableManager get incomeSchedules =>
      $$IncomeSchedulesTableTableManager(_db, _db.incomeSchedules);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$DayMarksTableTableManager get dayMarks =>
      $$DayMarksTableTableManager(_db, _db.dayMarks);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$CategoryKeywordsTableTableManager get categoryKeywords =>
      $$CategoryKeywordsTableTableManager(_db, _db.categoryKeywords);
  $$MerchantMemoryTableTableManager get merchantMemory =>
      $$MerchantMemoryTableTableManager(_db, _db.merchantMemory);
}
