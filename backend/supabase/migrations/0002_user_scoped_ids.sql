-- Los ids de categorías de fábrica y las claves de settings se repiten
-- entre usuarios. En Postgres la identidad incluye el dueño; el cliente
-- PowerSync sigue recibiendo id dentro de su bucket aislado por usuario.
BEGIN;
DO $migration$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'transactions', 'categories', 'loans', 'loan_installments', 'goals',
    'goal_contributions', 'budgets', 'recurring_rules', 'income_schedules',
    'salary_deductions', 'events', 'settings'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT %I', t, t || '_pkey');
    EXECUTE format('ALTER TABLE public.%I ADD PRIMARY KEY (user_id, id)', t);
  END LOOP;
END;
$migration$;
COMMIT;
