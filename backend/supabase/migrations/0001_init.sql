-- Drift: fechas/enteros en segundos Unix/bigint; booleanos integer 0/1;
-- enums y JSON serializado permanecen text. Sin foreign keys: uploads sin orden.
BEGIN;

CREATE TABLE public.transactions (
  id text PRIMARY KEY,
  user_id uuid NOT NULL DEFAULT auth.uid(),
  type text NOT NULL,
  amount bigint NOT NULL,
  currency text NOT NULL DEFAULT 'PYG',
  category_id text NOT NULL,
  merchant text,
  note text,
  occurred_at bigint NOT NULL,
  created_at bigint NOT NULL,
  updated_at bigint NOT NULL,
  source text NOT NULL,
  recurring_rule_id text,
  suggestion_id text,
  loan_id text,
  is_extra integer NOT NULL DEFAULT 0 CHECK (is_extra IN (0, 1)),
  event_id text,
  deleted_at bigint
);

CREATE TABLE public.categories (
  id text PRIMARY KEY,
  user_id uuid NOT NULL DEFAULT auth.uid(),
  name text NOT NULL,
  icon text NOT NULL,
  color_dark bigint NOT NULL,
  color_light bigint NOT NULL,
  kind text NOT NULL,
  sort_order bigint NOT NULL,
  archived integer NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)),
  updated_at bigint NOT NULL DEFAULT floor(extract(epoch FROM now()))::bigint
);

CREATE TABLE public.loans (
  id text PRIMARY KEY,
  user_id uuid NOT NULL DEFAULT auth.uid(),
  direction text NOT NULL,
  kind text NOT NULL,
  name text NOT NULL,
  counterparty text,
  total_amount bigint NOT NULL,
  installment_amount bigint,
  installments_total bigint,
  due_day bigint,
  start_date bigint NOT NULL,
  closed_at bigint,
  reminder_days bigint NOT NULL DEFAULT 2,
  paid_before_count bigint NOT NULL DEFAULT 0,
  created_at bigint NOT NULL,
  updated_at bigint NOT NULL
);

CREATE TABLE public.loan_installments (
  id text PRIMARY KEY,
  user_id uuid NOT NULL DEFAULT auth.uid(),
  loan_id text NOT NULL,
  number bigint NOT NULL,
  due_date bigint NOT NULL,
  amount bigint NOT NULL,
  updated_at bigint NOT NULL DEFAULT floor(extract(epoch FROM now()))::bigint,
  CONSTRAINT loan_installments_id_matches CHECK (id = loan_id || ':' || number::text)
);

CREATE TABLE public.goals (
  id text PRIMARY KEY,
  user_id uuid NOT NULL DEFAULT auth.uid(),
  name text NOT NULL,
  icon text NOT NULL,
  target_amount bigint NOT NULL,
  target_date bigint,
  created_at bigint NOT NULL,
  archived integer NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)),
  updated_at bigint NOT NULL DEFAULT floor(extract(epoch FROM now()))::bigint
);

CREATE TABLE public.goal_contributions (
  id text PRIMARY KEY,
  user_id uuid NOT NULL DEFAULT auth.uid(),
  goal_id text NOT NULL,
  amount bigint NOT NULL,
  date bigint NOT NULL,
  note text,
  created_at bigint NOT NULL,
  updated_at bigint NOT NULL DEFAULT floor(extract(epoch FROM now()))::bigint
);

CREATE TABLE public.budgets (
  id text PRIMARY KEY,
  user_id uuid NOT NULL DEFAULT auth.uid(),
  category_id text NOT NULL,
  monthly_limit bigint NOT NULL,
  alert80_sent_for text,
  alert100_sent_for text,
  updated_at bigint NOT NULL DEFAULT floor(extract(epoch FROM now()))::bigint
);

CREATE TABLE public.recurring_rules (
  id text PRIMARY KEY,
  user_id uuid NOT NULL DEFAULT auth.uid(),
  name text NOT NULL,
  type text NOT NULL,
  amount bigint NOT NULL,
  category_id text NOT NULL,
  frequency text NOT NULL,
  day_of_month bigint,
  day_of_week bigint,
  month_of_year bigint,
  next_due_date bigint NOT NULL,
  active integer NOT NULL DEFAULT 1 CHECK (active IN (0, 1)),
  updated_at bigint NOT NULL DEFAULT floor(extract(epoch FROM now()))::bigint
);

CREATE TABLE public.income_schedules (
  id text PRIMARY KEY,
  user_id uuid NOT NULL DEFAULT auth.uid(),
  mode text NOT NULL,
  pay_days text NOT NULL,
  pay_day_rules text NOT NULL,
  monthly_amount bigint,
  pay_split_percents text NOT NULL,
  category_id text NOT NULL,
  effective_from bigint NOT NULL,
  updated_at bigint NOT NULL DEFAULT floor(extract(epoch FROM now()))::bigint
);

CREATE TABLE public.salary_deductions (
  id text PRIMARY KEY,
  user_id uuid NOT NULL DEFAULT auth.uid(),
  schedule_id text NOT NULL,
  name text NOT NULL,
  kind text NOT NULL,
  value bigint NOT NULL,
  updated_at bigint NOT NULL DEFAULT floor(extract(epoch FROM now()))::bigint
);

CREATE TABLE public.events (
  id text PRIMARY KEY,
  user_id uuid NOT NULL DEFAULT auth.uid(),
  name text NOT NULL,
  icon text NOT NULL,
  start_date bigint NOT NULL,
  end_date bigint,
  is_active integer NOT NULL DEFAULT 0 CHECK (is_active IN (0, 1)),
  created_at bigint NOT NULL,
  updated_at bigint NOT NULL DEFAULT floor(extract(epoch FROM now()))::bigint
);

CREATE TABLE public.settings (
  id text PRIMARY KEY,
  user_id uuid NOT NULL DEFAULT auth.uid(),
  key text NOT NULL,
  value text NOT NULL,
  updated_at bigint NOT NULL DEFAULT floor(extract(epoch FROM now()))::bigint,
  CONSTRAINT settings_id_matches CHECK (id = key)
);

DO $security$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'transactions', 'categories', 'loans', 'loan_installments', 'goals',
    'goal_contributions', 'budgets', 'recurring_rules', 'income_schedules',
    'salary_deductions', 'events', 'settings'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    -- Retirar grants de Supabase que eluden RLS (por ejemplo TRUNCATE).
    EXECUTE format('REVOKE ALL ON public.%I FROM anon, authenticated', t);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated', t);
    EXECUTE format('CREATE POLICY select_own ON public.%I FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()))', t);
    EXECUTE format('CREATE POLICY insert_own ON public.%I FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT auth.uid()))', t);
    EXECUTE format('CREATE POLICY update_own ON public.%I FOR UPDATE TO authenticated USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()))', t);
    EXECUTE format('CREATE POLICY delete_own ON public.%I FOR DELETE TO authenticated USING (user_id = (SELECT auth.uid()))', t);
    EXECUTE format('CREATE INDEX %I ON public.%I (user_id)', t || '_user_id_idx', t);
    EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', t);
  END LOOP;
END;
$security$;

CREATE INDEX transactions_user_occurred_idx ON public.transactions (user_id, occurred_at);
CREATE INDEX transactions_category_idx ON public.transactions (user_id, category_id);
CREATE INDEX transactions_loan_idx ON public.transactions (user_id, loan_id);
CREATE INDEX transactions_event_idx ON public.transactions (user_id, event_id);
CREATE INDEX transactions_recurring_rule_idx ON public.transactions (user_id, recurring_rule_id);
CREATE INDEX loan_installments_loan_idx ON public.loan_installments (user_id, loan_id, number);
CREATE INDEX goal_contributions_goal_idx ON public.goal_contributions (user_id, goal_id);
CREATE INDEX budgets_category_idx ON public.budgets (user_id, category_id);
CREATE INDEX recurring_rules_category_idx ON public.recurring_rules (user_id, category_id);
CREATE INDEX income_schedules_category_idx ON public.income_schedules (user_id, category_id);
CREATE INDEX salary_deductions_schedule_idx ON public.salary_deductions (user_id, schedule_id);

CREATE PUBLICATION powersync FOR TABLE
  public.transactions, public.categories, public.loans, public.loan_installments,
  public.goals, public.goal_contributions, public.budgets, public.recurring_rules,
  public.income_schedules, public.salary_deductions, public.events, public.settings;

COMMIT;
