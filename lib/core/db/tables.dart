import 'package:drift/drift.dart';

enum TxType { expense, income }

enum CategoryKind { expense, income }

enum TxSource { manual, recurring, incomeSchedule, capture }

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  IntColumn get colorDark => integer()();
  IntColumn get colorLight => integer()();
  TextColumn get kind => textEnum<CategoryKind>()();
  IntColumn get sortOrder => integer()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => textEnum<TxType>()();
  IntColumn get amount => integer()();
  TextColumn get currency => text().withDefault(const Constant('PYG'))();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get merchant => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get source => textEnum<TxSource>()();
  TextColumn get recurringRuleId => text().nullable()();
  TextColumn get suggestionId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SuggestedTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => textEnum<TxType>()();
  IntColumn get amount => integer()();
  TextColumn get currency => text().withDefault(const Constant('PYG'))();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get merchant => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get source => textEnum<TxSource>()();
  TextColumn get sourceRef => text().nullable()();
  TextColumn get status => text()();
  TextColumn get transactionId => text().nullable().references(Transactions, #id)();
  TextColumn get rawText => text().nullable()();
  TextColumn get fingerprint => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class RecurringRules extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => textEnum<TxType>()();
  IntColumn get amount => integer()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get frequency => text()();
  IntColumn get dayOfMonth => integer().nullable()();
  IntColumn get dayOfWeek => integer().nullable()();
  IntColumn get monthOfYear => integer().nullable()();
  DateTimeColumn get nextDueDate => dateTime()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class IncomeSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get mode => text()();
  TextColumn get payDays => text()();
  BoolColumn get shiftToPreviousBusinessDay => boolean()();
  IntColumn get expectedAmount => integer().nullable()();
  TextColumn get categoryId => text().references(Categories, #id)();
  DateTimeColumn get effectiveFrom => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get monthlyLimit => integer()();
  TextColumn get alert80SentFor => text().nullable()();
  TextColumn get alert100SentFor => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DayMarks extends Table {
  TextColumn get date => text()();
  BoolColumn get noSpend => boolean()();

  @override
  Set<Column> get primaryKey => {date};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

enum KeywordSource { seed, user }

class CategoryKeywords extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get keyword => text()();
  TextColumn get source => textEnum<KeywordSource>()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {categoryId, keyword},
      ];
}

class MerchantMemory extends Table {
  TextColumn get merchantKey => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get uses => integer()();
  DateTimeColumn get lastUsedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {merchantKey, categoryId};
}
