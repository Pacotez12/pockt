import { column, Schema, Table } from '@powersync/web';

export const AppSchema = new Schema({
  transactions: new Table({
    type: column.text,
    amount: column.integer,
    currency: column.text,
    category_id: column.text,
    merchant: column.text,
    note: column.text,
    occurred_at: column.integer,
    created_at: column.integer,
    updated_at: column.integer,
    source: column.text,
    recurring_rule_id: column.text,
    suggestion_id: column.text,
    loan_id: column.text,
    is_extra: column.integer,
    event_id: column.text,
    deleted_at: column.integer,
  }),
  categories: new Table({
    name: column.text,
    icon: column.text,
    color_dark: column.integer,
    color_light: column.integer,
    kind: column.text,
    sort_order: column.integer,
    archived: column.integer,
    updated_at: column.integer,
  }),
  loans: new Table({
    direction: column.text,
    kind: column.text,
    name: column.text,
    counterparty: column.text,
    total_amount: column.integer,
    installment_amount: column.integer,
    installments_total: column.integer,
    due_day: column.integer,
    start_date: column.integer,
    closed_at: column.integer,
    reminder_days: column.integer,
    paid_before_count: column.integer,
    created_at: column.integer,
    updated_at: column.integer,
  }),
  loan_installments: new Table({
    loan_id: column.text,
    number: column.integer,
    due_date: column.integer,
    amount: column.integer,
    updated_at: column.integer,
  }),
  goals: new Table({
    name: column.text,
    icon: column.text,
    target_amount: column.integer,
    target_date: column.integer,
    created_at: column.integer,
    archived: column.integer,
    updated_at: column.integer,
  }),
  goal_contributions: new Table({
    goal_id: column.text,
    amount: column.integer,
    date: column.integer,
    note: column.text,
    created_at: column.integer,
    updated_at: column.integer,
  }),
  budgets: new Table({
    category_id: column.text,
    monthly_limit: column.integer,
    alert80_sent_for: column.text,
    alert100_sent_for: column.text,
    updated_at: column.integer,
  }),
  recurring_rules: new Table({
    name: column.text,
    type: column.text,
    amount: column.integer,
    category_id: column.text,
    frequency: column.text,
    day_of_month: column.integer,
    day_of_week: column.integer,
    month_of_year: column.integer,
    next_due_date: column.integer,
    active: column.integer,
    updated_at: column.integer,
  }),
  income_schedules: new Table({
    mode: column.text,
    pay_days: column.text,
    pay_day_rules: column.text,
    monthly_amount: column.integer,
    pay_split_percents: column.text,
    category_id: column.text,
    effective_from: column.integer,
    updated_at: column.integer,
  }),
  salary_deductions: new Table({
    schedule_id: column.text,
    name: column.text,
    kind: column.text,
    value: column.integer,
    updated_at: column.integer,
  }),
  events: new Table({
    name: column.text,
    icon: column.text,
    start_date: column.integer,
    end_date: column.integer,
    is_active: column.integer,
    created_at: column.integer,
    updated_at: column.integer,
  }),
  settings: new Table({
    key: column.text,
    value: column.text,
    updated_at: column.integer,
  }),
});

export type TransactionRow = (typeof AppSchema.types)['transactions'];
export type CategoryRow = (typeof AppSchema.types)['categories'];
export type LoanRow = (typeof AppSchema.types)['loans'];
export type LoanInstallmentRow = (typeof AppSchema.types)['loan_installments'];
export type GoalRow = (typeof AppSchema.types)['goals'];
export type GoalContributionRow = (typeof AppSchema.types)['goal_contributions'];
export type BudgetRow = (typeof AppSchema.types)['budgets'];
export type RecurringRuleRow = (typeof AppSchema.types)['recurring_rules'];
export type IncomeScheduleRow = (typeof AppSchema.types)['income_schedules'];
export type SalaryDeductionRow = (typeof AppSchema.types)['salary_deductions'];
export type EventRow = (typeof AppSchema.types)['events'];
export type SettingRow = (typeof AppSchema.types)['settings'];
