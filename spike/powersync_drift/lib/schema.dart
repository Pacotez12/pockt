import 'package:powersync/powersync.dart';

const schema = Schema([
  // Tabla descartable del spike inicial
  Table('spike_tx', [
    Column.text('user_id'),
    Column.integer('amount'),
    Column.text('note'),
    Column.integer('occurred_at'),
    Column.integer('updated_at'),
    Column.integer('deleted_at'),
  ]),

  // Tablas sincronizadas de Pockt (spec sección 4)
  Table('categories', [
    Column.text('name'),
    Column.text('icon'),
    Column.integer('color_dark'),
    Column.integer('color_light'),
    Column.text('kind'),
    Column.integer('sort_order'),
    Column.integer('archived'),
  ]),

  Table('transactions', [
    Column.text('type'),
    Column.integer('amount'),
    Column.text('currency'),
    Column.text('category_id'),
    Column.text('merchant'),
    Column.text('note'),
    Column.integer('occurred_at'),
    Column.integer('created_at'),
    Column.integer('updated_at'),
    Column.text('source'),
    Column.text('recurring_rule_id'),
    Column.text('suggestion_id'),
    Column.text('loan_id'),
    Column.integer('is_extra'),
    Column.text('event_id'),
    Column.integer('deleted_at'),
  ]),

  Table('recurring_rules', [
    Column.text('name'),
    Column.text('type'),
    Column.integer('amount'),
    Column.text('category_id'),
    Column.text('frequency'),
    Column.integer('day_of_month'),
    Column.integer('day_of_week'),
    Column.integer('month_of_year'),
    Column.integer('next_due_date'),
    Column.integer('active'),
  ]),

  Table('income_schedules', [
    Column.text('mode'),
    Column.text('pay_days'),
    Column.text('pay_day_rules'),
    Column.integer('monthly_amount'),
    Column.text('pay_split_percents'),
    Column.text('category_id'),
    Column.integer('effective_from'),
  ]),

  Table('salary_deductions', [
    Column.text('schedule_id'),
    Column.text('name'),
    Column.text('kind'),
    Column.integer('value'),
  ]),

  Table('budgets', [
    Column.text('category_id'),
    Column.integer('monthly_limit'),
    Column.text('alert80_sent_for'),
    Column.text('alert100_sent_for'),
  ]),

  Table('settings', [
    Column.text('key'),
    Column.text('value'),
  ]),

  Table('loans', [
    Column.text('direction'),
    Column.text('kind'),
    Column.text('name'),
    Column.text('counterparty'),
    Column.integer('total_amount'),
    Column.integer('installment_amount'),
    Column.integer('installments_total'),
    Column.integer('due_day'),
    Column.integer('start_date'),
    Column.integer('closed_at'),
    Column.integer('reminder_days'),
    Column.integer('paid_before_count'),
    Column.integer('created_at'),
    Column.integer('updated_at'),
  ]),

  Table('loan_installments', [
    Column.text('loan_id'),
    Column.integer('number'),
    Column.integer('due_date'),
    Column.integer('amount'),
  ]),

  Table('goals', [
    Column.text('name'),
    Column.text('icon'),
    Column.integer('target_amount'),
    Column.integer('target_date'),
    Column.integer('created_at'),
    Column.integer('archived'),
  ]),

  Table('goal_contributions', [
    Column.text('goal_id'),
    Column.integer('amount'),
    Column.integer('date'),
    Column.text('note'),
    Column.integer('created_at'),
  ]),

  Table('events', [
    Column.text('name'),
    Column.text('icon'),
    Column.integer('start_date'),
    Column.integer('end_date'),
    Column.integer('is_active'),
    Column.integer('created_at'),
  ]),
]);
