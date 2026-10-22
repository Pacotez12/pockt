import 'package:drift/drift.dart';
import 'package:pockt/features/income/domain/salary_deduction.dart';

enum TxType { expense, income, transfer }

enum CategoryKind { expense, income }

enum TxSource { manual, recurring, incomeSchedule, capture }

enum LoanDirection { owe, lent }

enum LoanKind { loan, installments }

enum TransferDirection { incoming, outgoing }

enum CounterpartyAction {
  income,
  expense,
  loanRepayment,
  loanLent,
  loanPayment,
  ignore,
}

class Loans extends Table {
  TextColumn get id => text()();
  TextColumn get direction => textEnum<LoanDirection>()();
  TextColumn get kind => textEnum<LoanKind>()();
  TextColumn get name => text()();
  TextColumn get counterparty => text().nullable()();
  IntColumn get totalAmount => integer()();
  IntColumn get installmentAmount => integer().nullable()();
  IntColumn get installmentsTotal => integer().nullable()();
  IntColumn get dueDay => integer().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  IntColumn get reminderDays => integer().withDefault(const Constant(2))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LoanInstallments extends Table {
  TextColumn get loanId => text().references(Loans, #id)();
  IntColumn get number => integer()();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get amount => integer()();

  @override
  Set<Column> get primaryKey => {loanId, number};
}

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

class Events extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class EntryShortcuts extends Table {
  TextColumn get id => text()();
  TextColumn get merchant => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get amount => integer()();
  TextColumn get categoryId => text().references(Categories, #id)();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isDismissed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

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
  TextColumn get loanId => text().nullable().references(Loans, #id)();

  /// Pago extra / adelanto de un préstamo (no cuenta como cuota regular).
  BoolColumn get isExtra => boolean().withDefault(const Constant(false))();

  /// Evento especial al que se asigna el gasto (Plan 5c / spec §7d).
  TextColumn get eventId => text().nullable().references(Events, #id)();
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
  TextColumn get transactionId =>
      text().nullable().references(Transactions, #id)();
  TextColumn get rawText => text().nullable()();
  TextColumn get fingerprint => text().nullable()();
  TextColumn get captureMeta => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {source, sourceRef, occurredAt},
  ];
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
  TextColumn get payDayRules => text()();
  IntColumn get monthlyAmount => integer().nullable()();
  TextColumn get paySplitPercents => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  DateTimeColumn get effectiveFrom => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName.custom(implementing: [SalaryDeductionLike])
class SalaryDeductions extends Table {
  TextColumn get id => text()();
  TextColumn get scheduleId => text().references(IncomeSchedules, #id)();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  IntColumn get value => integer()();

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
  BoolColumn get autoConfirm => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {merchantKey, categoryId};
}

class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  IntColumn get targetAmount => integer()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class GoalContributions extends Table {
  TextColumn get id => text()();
  TextColumn get goalId => text().references(Goals, #id)();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CounterpartyRules extends Table {
  TextColumn get id => text()();
  TextColumn get nameKey => text()();
  TextColumn get direction => textEnum<TransferDirection>()();
  TextColumn get action => textEnum<CounterpartyAction>()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get loanId => text().nullable().references(Loans, #id)();
  BoolColumn get autoApply => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {nameKey, direction},
  ];
}

