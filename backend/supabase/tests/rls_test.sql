BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT no_plan();

-- Contrato de columnas obtenido de app_database.g.dart (tipos de almacenamiento).

SELECT has_table('public', 'transactions', 'transactions: existe');
SELECT ok(COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.transactions')), false), 'transactions: RLS activa');
SELECT columns_are('public', 'transactions', ARRAY['id', 'type', 'amount', 'currency', 'category_id', 'merchant', 'note', 'occurred_at', 'created_at', 'updated_at', 'source', 'recurring_rule_id', 'suggestion_id', 'loan_id', 'is_extra', 'event_id', 'deleted_at', 'user_id'], 'transactions: columnas exactas');
SELECT col_type_is('public', 'transactions', 'id', 'text', 'transactions.id: text');
SELECT col_type_is('public', 'transactions', 'type', 'text', 'transactions.type: text');
SELECT col_type_is('public', 'transactions', 'amount', 'bigint', 'transactions.amount: bigint');
SELECT col_type_is('public', 'transactions', 'currency', 'text', 'transactions.currency: text');
SELECT col_type_is('public', 'transactions', 'category_id', 'text', 'transactions.category_id: text');
SELECT col_type_is('public', 'transactions', 'merchant', 'text', 'transactions.merchant: text');
SELECT col_type_is('public', 'transactions', 'note', 'text', 'transactions.note: text');
SELECT col_type_is('public', 'transactions', 'occurred_at', 'bigint', 'transactions.occurred_at: bigint');
SELECT col_type_is('public', 'transactions', 'created_at', 'bigint', 'transactions.created_at: bigint');
SELECT col_type_is('public', 'transactions', 'updated_at', 'bigint', 'transactions.updated_at: bigint');
SELECT col_type_is('public', 'transactions', 'source', 'text', 'transactions.source: text');
SELECT col_type_is('public', 'transactions', 'recurring_rule_id', 'text', 'transactions.recurring_rule_id: text');
SELECT col_type_is('public', 'transactions', 'suggestion_id', 'text', 'transactions.suggestion_id: text');
SELECT col_type_is('public', 'transactions', 'loan_id', 'text', 'transactions.loan_id: text');
SELECT col_type_is('public', 'transactions', 'is_extra', 'integer', 'transactions.is_extra: integer');
SELECT col_type_is('public', 'transactions', 'event_id', 'text', 'transactions.event_id: text');
SELECT col_type_is('public', 'transactions', 'deleted_at', 'bigint', 'transactions.deleted_at: bigint');
SELECT col_type_is('public', 'transactions', 'user_id', 'uuid', 'transactions.user_id: uuid');
SELECT col_is_pk('public', 'transactions', ARRAY['user_id', 'id']::name[], 'transactions: PK por usuario e id');
SELECT col_not_null('public', 'transactions', 'user_id', 'transactions: user_id obligatorio');

SELECT has_table('public', 'categories', 'categories: existe');
SELECT ok(COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.categories')), false), 'categories: RLS activa');
SELECT columns_are('public', 'categories', ARRAY['id', 'name', 'icon', 'color_dark', 'color_light', 'kind', 'sort_order', 'archived', 'updated_at', 'user_id'], 'categories: columnas exactas');
SELECT col_type_is('public', 'categories', 'id', 'text', 'categories.id: text');
SELECT col_type_is('public', 'categories', 'name', 'text', 'categories.name: text');
SELECT col_type_is('public', 'categories', 'icon', 'text', 'categories.icon: text');
SELECT col_type_is('public', 'categories', 'color_dark', 'bigint', 'categories.color_dark: bigint');
SELECT col_type_is('public', 'categories', 'color_light', 'bigint', 'categories.color_light: bigint');
SELECT col_type_is('public', 'categories', 'kind', 'text', 'categories.kind: text');
SELECT col_type_is('public', 'categories', 'sort_order', 'bigint', 'categories.sort_order: bigint');
SELECT col_type_is('public', 'categories', 'archived', 'integer', 'categories.archived: integer');
SELECT col_type_is('public', 'categories', 'updated_at', 'bigint', 'categories.updated_at: bigint');
SELECT col_type_is('public', 'categories', 'user_id', 'uuid', 'categories.user_id: uuid');
SELECT col_is_pk('public', 'categories', ARRAY['user_id', 'id']::name[], 'categories: PK por usuario e id');
SELECT col_not_null('public', 'categories', 'user_id', 'categories: user_id obligatorio');

SELECT has_table('public', 'loans', 'loans: existe');
SELECT ok(COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.loans')), false), 'loans: RLS activa');
SELECT columns_are('public', 'loans', ARRAY['id', 'direction', 'kind', 'name', 'counterparty', 'total_amount', 'installment_amount', 'installments_total', 'due_day', 'start_date', 'closed_at', 'reminder_days', 'paid_before_count', 'created_at', 'updated_at', 'user_id'], 'loans: columnas exactas');
SELECT col_type_is('public', 'loans', 'id', 'text', 'loans.id: text');
SELECT col_type_is('public', 'loans', 'direction', 'text', 'loans.direction: text');
SELECT col_type_is('public', 'loans', 'kind', 'text', 'loans.kind: text');
SELECT col_type_is('public', 'loans', 'name', 'text', 'loans.name: text');
SELECT col_type_is('public', 'loans', 'counterparty', 'text', 'loans.counterparty: text');
SELECT col_type_is('public', 'loans', 'total_amount', 'bigint', 'loans.total_amount: bigint');
SELECT col_type_is('public', 'loans', 'installment_amount', 'bigint', 'loans.installment_amount: bigint');
SELECT col_type_is('public', 'loans', 'installments_total', 'bigint', 'loans.installments_total: bigint');
SELECT col_type_is('public', 'loans', 'due_day', 'bigint', 'loans.due_day: bigint');
SELECT col_type_is('public', 'loans', 'start_date', 'bigint', 'loans.start_date: bigint');
SELECT col_type_is('public', 'loans', 'closed_at', 'bigint', 'loans.closed_at: bigint');
SELECT col_type_is('public', 'loans', 'reminder_days', 'bigint', 'loans.reminder_days: bigint');
SELECT col_type_is('public', 'loans', 'paid_before_count', 'bigint', 'loans.paid_before_count: bigint');
SELECT col_type_is('public', 'loans', 'created_at', 'bigint', 'loans.created_at: bigint');
SELECT col_type_is('public', 'loans', 'updated_at', 'bigint', 'loans.updated_at: bigint');
SELECT col_type_is('public', 'loans', 'user_id', 'uuid', 'loans.user_id: uuid');
SELECT col_is_pk('public', 'loans', ARRAY['user_id', 'id']::name[], 'loans: PK por usuario e id');
SELECT col_not_null('public', 'loans', 'user_id', 'loans: user_id obligatorio');

SELECT has_table('public', 'loan_installments', 'loan_installments: existe');
SELECT ok(COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.loan_installments')), false), 'loan_installments: RLS activa');
SELECT columns_are('public', 'loan_installments', ARRAY['id', 'loan_id', 'number', 'due_date', 'amount', 'updated_at', 'user_id'], 'loan_installments: columnas exactas');
SELECT col_type_is('public', 'loan_installments', 'id', 'text', 'loan_installments.id: text');
SELECT col_type_is('public', 'loan_installments', 'loan_id', 'text', 'loan_installments.loan_id: text');
SELECT col_type_is('public', 'loan_installments', 'number', 'bigint', 'loan_installments.number: bigint');
SELECT col_type_is('public', 'loan_installments', 'due_date', 'bigint', 'loan_installments.due_date: bigint');
SELECT col_type_is('public', 'loan_installments', 'amount', 'bigint', 'loan_installments.amount: bigint');
SELECT col_type_is('public', 'loan_installments', 'updated_at', 'bigint', 'loan_installments.updated_at: bigint');
SELECT col_type_is('public', 'loan_installments', 'user_id', 'uuid', 'loan_installments.user_id: uuid');
SELECT col_is_pk('public', 'loan_installments', ARRAY['user_id', 'id']::name[], 'loan_installments: PK por usuario e id');
SELECT col_not_null('public', 'loan_installments', 'user_id', 'loan_installments: user_id obligatorio');

SELECT has_table('public', 'goals', 'goals: existe');
SELECT ok(COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.goals')), false), 'goals: RLS activa');
SELECT columns_are('public', 'goals', ARRAY['id', 'name', 'icon', 'target_amount', 'target_date', 'created_at', 'archived', 'updated_at', 'user_id'], 'goals: columnas exactas');
SELECT col_type_is('public', 'goals', 'id', 'text', 'goals.id: text');
SELECT col_type_is('public', 'goals', 'name', 'text', 'goals.name: text');
SELECT col_type_is('public', 'goals', 'icon', 'text', 'goals.icon: text');
SELECT col_type_is('public', 'goals', 'target_amount', 'bigint', 'goals.target_amount: bigint');
SELECT col_type_is('public', 'goals', 'target_date', 'bigint', 'goals.target_date: bigint');
SELECT col_type_is('public', 'goals', 'created_at', 'bigint', 'goals.created_at: bigint');
SELECT col_type_is('public', 'goals', 'archived', 'integer', 'goals.archived: integer');
SELECT col_type_is('public', 'goals', 'updated_at', 'bigint', 'goals.updated_at: bigint');
SELECT col_type_is('public', 'goals', 'user_id', 'uuid', 'goals.user_id: uuid');
SELECT col_is_pk('public', 'goals', ARRAY['user_id', 'id']::name[], 'goals: PK por usuario e id');
SELECT col_not_null('public', 'goals', 'user_id', 'goals: user_id obligatorio');

SELECT has_table('public', 'goal_contributions', 'goal_contributions: existe');
SELECT ok(COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.goal_contributions')), false), 'goal_contributions: RLS activa');
SELECT columns_are('public', 'goal_contributions', ARRAY['id', 'goal_id', 'amount', 'date', 'note', 'created_at', 'updated_at', 'user_id'], 'goal_contributions: columnas exactas');
SELECT col_type_is('public', 'goal_contributions', 'id', 'text', 'goal_contributions.id: text');
SELECT col_type_is('public', 'goal_contributions', 'goal_id', 'text', 'goal_contributions.goal_id: text');
SELECT col_type_is('public', 'goal_contributions', 'amount', 'bigint', 'goal_contributions.amount: bigint');
SELECT col_type_is('public', 'goal_contributions', 'date', 'bigint', 'goal_contributions.date: bigint');
SELECT col_type_is('public', 'goal_contributions', 'note', 'text', 'goal_contributions.note: text');
SELECT col_type_is('public', 'goal_contributions', 'created_at', 'bigint', 'goal_contributions.created_at: bigint');
SELECT col_type_is('public', 'goal_contributions', 'updated_at', 'bigint', 'goal_contributions.updated_at: bigint');
SELECT col_type_is('public', 'goal_contributions', 'user_id', 'uuid', 'goal_contributions.user_id: uuid');
SELECT col_is_pk('public', 'goal_contributions', ARRAY['user_id', 'id']::name[], 'goal_contributions: PK por usuario e id');
SELECT col_not_null('public', 'goal_contributions', 'user_id', 'goal_contributions: user_id obligatorio');

SELECT has_table('public', 'budgets', 'budgets: existe');
SELECT ok(COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.budgets')), false), 'budgets: RLS activa');
SELECT columns_are('public', 'budgets', ARRAY['id', 'category_id', 'monthly_limit', 'alert80_sent_for', 'alert100_sent_for', 'updated_at', 'user_id'], 'budgets: columnas exactas');
SELECT col_type_is('public', 'budgets', 'id', 'text', 'budgets.id: text');
SELECT col_type_is('public', 'budgets', 'category_id', 'text', 'budgets.category_id: text');
SELECT col_type_is('public', 'budgets', 'monthly_limit', 'bigint', 'budgets.monthly_limit: bigint');
SELECT col_type_is('public', 'budgets', 'alert80_sent_for', 'text', 'budgets.alert80_sent_for: text');
SELECT col_type_is('public', 'budgets', 'alert100_sent_for', 'text', 'budgets.alert100_sent_for: text');
SELECT col_type_is('public', 'budgets', 'updated_at', 'bigint', 'budgets.updated_at: bigint');
SELECT col_type_is('public', 'budgets', 'user_id', 'uuid', 'budgets.user_id: uuid');
SELECT col_is_pk('public', 'budgets', ARRAY['user_id', 'id']::name[], 'budgets: PK por usuario e id');
SELECT col_not_null('public', 'budgets', 'user_id', 'budgets: user_id obligatorio');

SELECT has_table('public', 'recurring_rules', 'recurring_rules: existe');
SELECT ok(COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.recurring_rules')), false), 'recurring_rules: RLS activa');
SELECT columns_are('public', 'recurring_rules', ARRAY['id', 'name', 'type', 'amount', 'category_id', 'frequency', 'day_of_month', 'day_of_week', 'month_of_year', 'next_due_date', 'active', 'updated_at', 'user_id'], 'recurring_rules: columnas exactas');
SELECT col_type_is('public', 'recurring_rules', 'id', 'text', 'recurring_rules.id: text');
SELECT col_type_is('public', 'recurring_rules', 'name', 'text', 'recurring_rules.name: text');
SELECT col_type_is('public', 'recurring_rules', 'type', 'text', 'recurring_rules.type: text');
SELECT col_type_is('public', 'recurring_rules', 'amount', 'bigint', 'recurring_rules.amount: bigint');
SELECT col_type_is('public', 'recurring_rules', 'category_id', 'text', 'recurring_rules.category_id: text');
SELECT col_type_is('public', 'recurring_rules', 'frequency', 'text', 'recurring_rules.frequency: text');
SELECT col_type_is('public', 'recurring_rules', 'day_of_month', 'bigint', 'recurring_rules.day_of_month: bigint');
SELECT col_type_is('public', 'recurring_rules', 'day_of_week', 'bigint', 'recurring_rules.day_of_week: bigint');
SELECT col_type_is('public', 'recurring_rules', 'month_of_year', 'bigint', 'recurring_rules.month_of_year: bigint');
SELECT col_type_is('public', 'recurring_rules', 'next_due_date', 'bigint', 'recurring_rules.next_due_date: bigint');
SELECT col_type_is('public', 'recurring_rules', 'active', 'integer', 'recurring_rules.active: integer');
SELECT col_type_is('public', 'recurring_rules', 'updated_at', 'bigint', 'recurring_rules.updated_at: bigint');
SELECT col_type_is('public', 'recurring_rules', 'user_id', 'uuid', 'recurring_rules.user_id: uuid');
SELECT col_is_pk('public', 'recurring_rules', ARRAY['user_id', 'id']::name[], 'recurring_rules: PK por usuario e id');
SELECT col_not_null('public', 'recurring_rules', 'user_id', 'recurring_rules: user_id obligatorio');

SELECT has_table('public', 'income_schedules', 'income_schedules: existe');
SELECT ok(COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.income_schedules')), false), 'income_schedules: RLS activa');
SELECT columns_are('public', 'income_schedules', ARRAY['id', 'mode', 'pay_days', 'pay_day_rules', 'monthly_amount', 'pay_split_percents', 'category_id', 'effective_from', 'updated_at', 'user_id'], 'income_schedules: columnas exactas');
SELECT col_type_is('public', 'income_schedules', 'id', 'text', 'income_schedules.id: text');
SELECT col_type_is('public', 'income_schedules', 'mode', 'text', 'income_schedules.mode: text');
SELECT col_type_is('public', 'income_schedules', 'pay_days', 'text', 'income_schedules.pay_days: text');
SELECT col_type_is('public', 'income_schedules', 'pay_day_rules', 'text', 'income_schedules.pay_day_rules: text');
SELECT col_type_is('public', 'income_schedules', 'monthly_amount', 'bigint', 'income_schedules.monthly_amount: bigint');
SELECT col_type_is('public', 'income_schedules', 'pay_split_percents', 'text', 'income_schedules.pay_split_percents: text');
SELECT col_type_is('public', 'income_schedules', 'category_id', 'text', 'income_schedules.category_id: text');
SELECT col_type_is('public', 'income_schedules', 'effective_from', 'bigint', 'income_schedules.effective_from: bigint');
SELECT col_type_is('public', 'income_schedules', 'updated_at', 'bigint', 'income_schedules.updated_at: bigint');
SELECT col_type_is('public', 'income_schedules', 'user_id', 'uuid', 'income_schedules.user_id: uuid');
SELECT col_is_pk('public', 'income_schedules', ARRAY['user_id', 'id']::name[], 'income_schedules: PK por usuario e id');
SELECT col_not_null('public', 'income_schedules', 'user_id', 'income_schedules: user_id obligatorio');

SELECT has_table('public', 'salary_deductions', 'salary_deductions: existe');
SELECT ok(COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.salary_deductions')), false), 'salary_deductions: RLS activa');
SELECT columns_are('public', 'salary_deductions', ARRAY['id', 'schedule_id', 'name', 'kind', 'value', 'updated_at', 'user_id'], 'salary_deductions: columnas exactas');
SELECT col_type_is('public', 'salary_deductions', 'id', 'text', 'salary_deductions.id: text');
SELECT col_type_is('public', 'salary_deductions', 'schedule_id', 'text', 'salary_deductions.schedule_id: text');
SELECT col_type_is('public', 'salary_deductions', 'name', 'text', 'salary_deductions.name: text');
SELECT col_type_is('public', 'salary_deductions', 'kind', 'text', 'salary_deductions.kind: text');
SELECT col_type_is('public', 'salary_deductions', 'value', 'bigint', 'salary_deductions.value: bigint');
SELECT col_type_is('public', 'salary_deductions', 'updated_at', 'bigint', 'salary_deductions.updated_at: bigint');
SELECT col_type_is('public', 'salary_deductions', 'user_id', 'uuid', 'salary_deductions.user_id: uuid');
SELECT col_is_pk('public', 'salary_deductions', ARRAY['user_id', 'id']::name[], 'salary_deductions: PK por usuario e id');
SELECT col_not_null('public', 'salary_deductions', 'user_id', 'salary_deductions: user_id obligatorio');

SELECT has_table('public', 'events', 'events: existe');
SELECT ok(COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.events')), false), 'events: RLS activa');
SELECT columns_are('public', 'events', ARRAY['id', 'name', 'icon', 'start_date', 'end_date', 'is_active', 'created_at', 'updated_at', 'user_id'], 'events: columnas exactas');
SELECT col_type_is('public', 'events', 'id', 'text', 'events.id: text');
SELECT col_type_is('public', 'events', 'name', 'text', 'events.name: text');
SELECT col_type_is('public', 'events', 'icon', 'text', 'events.icon: text');
SELECT col_type_is('public', 'events', 'start_date', 'bigint', 'events.start_date: bigint');
SELECT col_type_is('public', 'events', 'end_date', 'bigint', 'events.end_date: bigint');
SELECT col_type_is('public', 'events', 'is_active', 'integer', 'events.is_active: integer');
SELECT col_type_is('public', 'events', 'created_at', 'bigint', 'events.created_at: bigint');
SELECT col_type_is('public', 'events', 'updated_at', 'bigint', 'events.updated_at: bigint');
SELECT col_type_is('public', 'events', 'user_id', 'uuid', 'events.user_id: uuid');
SELECT col_is_pk('public', 'events', ARRAY['user_id', 'id']::name[], 'events: PK por usuario e id');
SELECT col_not_null('public', 'events', 'user_id', 'events: user_id obligatorio');

SELECT has_table('public', 'settings', 'settings: existe');
SELECT ok(COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.settings')), false), 'settings: RLS activa');
SELECT columns_are('public', 'settings', ARRAY['id', 'key', 'value', 'updated_at', 'user_id'], 'settings: columnas exactas');
SELECT col_type_is('public', 'settings', 'id', 'text', 'settings.id: text');
SELECT col_type_is('public', 'settings', 'key', 'text', 'settings.key: text');
SELECT col_type_is('public', 'settings', 'value', 'text', 'settings.value: text');
SELECT col_type_is('public', 'settings', 'updated_at', 'bigint', 'settings.updated_at: bigint');
SELECT col_type_is('public', 'settings', 'user_id', 'uuid', 'settings.user_id: uuid');
SELECT col_is_pk('public', 'settings', ARRAY['user_id', 'id']::name[], 'settings: PK por usuario e id');
SELECT col_not_null('public', 'settings', 'user_id', 'settings: user_id obligatorio');

SELECT is((SELECT count(*) FROM pg_constraint WHERE connamespace = 'public'::regnamespace AND contype = 'f'), 0::bigint, 'sin foreign keys que impidan subir filas fuera de orden');
SELECT is(
  (SELECT array_agg(tablename::text ORDER BY tablename) FROM pg_publication_tables WHERE pubname = 'powersync'),
  ARRAY['budgets', 'categories', 'events', 'goal_contributions', 'goals', 'income_schedules', 'loan_installments', 'loans', 'recurring_rules', 'salary_deductions', 'settings', 'transactions']::text[],
  'publicación powersync: exactamente las 12 tablas sincronizadas'
);

-- SECURITY INVOKER: las operaciones se ejecutan como authenticated, nunca como dueño.
-- UUIDs inventados; no hacen falta contraseñas ni usuarios persistentes de Auth.
CREATE FUNCTION pg_temp.check_owner(t text, fixture jsonb) RETURNS SETOF text
LANGUAGE plpgsql AS $test$
DECLARE
  a constant text := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  b constant text := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  cols text;
  vals text;
  row_id text := fixture->>'id';
  insert_sql text;
  n bigint;
BEGIN
  IF to_regclass(format('public.%I', t)) IS NULL THEN
    RETURN NEXT fail(t || ': no se puede probar propiedad sin la tabla');
    RETURN;
  END IF;
  SELECT string_agg(format('%I', key), ', ' ORDER BY key),
         string_agg(quote_nullable(value #>> '{}'), ', ' ORDER BY key)
    INTO cols, vals FROM jsonb_each(fixture);
  insert_sql := format('INSERT INTO public.%I (%s) VALUES (%s)', t, cols, vals);

  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM set_config('request.jwt.claim.sub', a, true);
  RETURN NEXT lives_ok(insert_sql, t || ': A inserta sin user_id y sin filas relacionadas');
  RETURN QUERY EXECUTE format('SELECT is((SELECT user_id::text FROM public.%I WHERE id = %L), %L, %L)', t, row_id, a, t || ': user_id por defecto es auth.uid()');
  RETURN QUERY EXECUTE format('SELECT is((SELECT count(*) FROM public.%I WHERE id = %L), 1::bigint, %L)', t, row_id, t || ': A lee su fila');
  RETURN NEXT lives_ok(format('UPDATE public.%I SET updated_at = 1793260801 WHERE id = %L', t, row_id), t || ': A modifica su fila');
  RETURN QUERY EXECUTE format('SELECT is((SELECT updated_at FROM public.%I WHERE id = %L), 1793260801::bigint, %L)', t, row_id, t || ': update propio aplicado');
  RETURN NEXT throws_ok(format('UPDATE public.%I SET user_id = %L WHERE id = %L', t, b, row_id), '42501', NULL, t || ': A no puede transferir propiedad a B');

  PERFORM set_config('request.jwt.claim.sub', b, true);
  RETURN QUERY EXECUTE format('SELECT is((SELECT count(*) FROM public.%I WHERE id = %L), 0::bigint, %L)', t, row_id, t || ': B no lee la fila de A');
  EXECUTE format('UPDATE public.%I SET updated_at = 1 WHERE id = %L', t, row_id);
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN NEXT is(n, 0::bigint, t || ': B no modifica la fila de A');
  EXECUTE format('DELETE FROM public.%I WHERE id = %L', t, row_id);
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN NEXT is(n, 0::bigint, t || ': B no borra la fila de A');
  RETURN NEXT throws_ok(
    format('INSERT INTO public.%I (%s, user_id) VALUES (%s, %L)', t, cols, vals, a),
    '42501', NULL, t || ': B no inserta con user_id de A'
  );

  PERFORM set_config('request.jwt.claim.sub', a, true);
  RETURN QUERY EXECUTE format('SELECT is((SELECT updated_at FROM public.%I WHERE id = %L), 1793260801::bigint, %L)', t, row_id, t || ': fila de A permanece intacta');
  EXECUTE format('DELETE FROM public.%I WHERE id = %L', t, row_id);
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN NEXT is(n, 1::bigint, t || ': A borra su fila');
  EXECUTE 'RESET ROLE';
END;
$test$;

SELECT * FROM pg_temp.check_owner('transactions', '{"type": "expense", "amount": 184000, "category_id": "missing-category", "occurred_at": 1793260800, "created_at": 1793260800, "updated_at": 1793260800, "source": "manual", "id": "test-transactions"}'::jsonb);
SELECT * FROM pg_temp.check_owner('categories', '{"name": "Prueba", "icon": "test", "color_dark": 4294967295, "color_light": 4294967295, "kind": "expense", "sort_order": 0, "id": "test-categories"}'::jsonb);
SELECT * FROM pg_temp.check_owner('loans', '{"direction": "owe", "kind": "loan", "name": "Prueba", "total_amount": 184000, "start_date": 1793260800, "created_at": 1793260800, "updated_at": 1793260800, "id": "test-loans"}'::jsonb);
SELECT * FROM pg_temp.check_owner('loan_installments', '{"id": "missing-loan:1", "loan_id": "missing-loan", "number": 1, "due_date": 1793260800, "amount": 184000}'::jsonb);
SELECT * FROM pg_temp.check_owner('goals', '{"name": "Prueba", "icon": "test", "target_amount": 184000, "created_at": 1793260800, "id": "test-goals"}'::jsonb);
SELECT * FROM pg_temp.check_owner('goal_contributions', '{"goal_id": "missing-goal", "amount": 184000, "date": 1793260800, "created_at": 1793260800, "id": "test-goal_contributions"}'::jsonb);
SELECT * FROM pg_temp.check_owner('budgets', '{"category_id": "missing-category", "monthly_limit": 184000, "id": "test-budgets"}'::jsonb);
SELECT * FROM pg_temp.check_owner('recurring_rules', '{"name": "Prueba", "type": "expense", "amount": 184000, "category_id": "missing-category", "frequency": "monthly", "next_due_date": 1793260800, "id": "test-recurring_rules"}'::jsonb);
SELECT * FROM pg_temp.check_owner('income_schedules', '{"mode": "monthly", "pay_days": "[1]", "pay_day_rules": "[]", "pay_split_percents": "[100]", "category_id": "missing-category", "effective_from": 1793260800, "id": "test-income_schedules"}'::jsonb);
SELECT * FROM pg_temp.check_owner('salary_deductions', '{"schedule_id": "missing-schedule", "name": "Prueba", "kind": "fixed", "value": 184000, "id": "test-salary_deductions"}'::jsonb);
SELECT * FROM pg_temp.check_owner('events', '{"name": "Prueba", "icon": "test", "start_date": 1793260800, "created_at": 1793260800, "id": "test-events"}'::jsonb);
SELECT * FROM pg_temp.check_owner('settings', '{"id": "test-key", "key": "test-key", "value": "test-value"}'::jsonb);

-- Categorías de fábrica y claves settings se repiten entre instalaciones.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', true);
INSERT INTO public.categories (id, name, icon, color_dark, color_light, kind, sort_order)
VALUES ('018f0000-0000-7000-8000-000000000001', 'Categoría A', 'test', 1, 2, 'expense', 0);
INSERT INTO public.settings (id, key, value) VALUES ('currency', 'currency', 'PYG');

SELECT set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', true);
SELECT lives_ok(
  $$INSERT INTO public.categories (id, name, icon, color_dark, color_light, kind, sort_order)
    VALUES ('018f0000-0000-7000-8000-000000000001', 'Categoría B', 'test', 3, 4, 'expense', 0)$$,
  'B inserta una categoría con el mismo id de fábrica que A'
);
SELECT lives_ok(
  $$INSERT INTO public.settings (id, key, value) VALUES ('currency', 'currency', 'USD')$$,
  'B inserta settings con la misma clave/id que A'
);
SELECT is((SELECT count(*) FROM public.categories WHERE id = '018f0000-0000-7000-8000-000000000001'), 1::bigint, 'B solo ve su categoría');
SELECT is((SELECT name FROM public.categories WHERE id = '018f0000-0000-7000-8000-000000000001'), 'Categoría B', 'B recibe sus propios valores de categoría');
SELECT is((SELECT count(*) FROM public.settings WHERE id = 'currency'), 1::bigint, 'B solo ve su setting');
SELECT is((SELECT value FROM public.settings WHERE id = 'currency'), 'USD', 'B recibe su propio valor de setting');

SELECT set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', true);
SELECT is((SELECT count(*) FROM public.categories WHERE id = '018f0000-0000-7000-8000-000000000001'), 1::bigint, 'A sigue viendo solo su categoría');
SELECT is((SELECT name FROM public.categories WHERE id = '018f0000-0000-7000-8000-000000000001'), 'Categoría A', 'categoría de A conserva sus valores');
SELECT is((SELECT count(*) FROM public.settings WHERE id = 'currency'), 1::bigint, 'A sigue viendo solo su setting');
SELECT is((SELECT value FROM public.settings WHERE id = 'currency'), 'PYG', 'setting de A conserva su valor');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
