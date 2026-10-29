CREATE TABLE public.spike_tx (
  id text PRIMARY KEY,
  user_id uuid NOT NULL DEFAULT auth.uid(),
  amount integer NOT NULL,
  note text,
  occurred_at bigint NOT NULL,
  updated_at bigint NOT NULL,
  deleted_at bigint
);
ALTER TABLE public.spike_tx ENABLE ROW LEVEL SECURITY;
CREATE POLICY spike_tx_owner ON public.spike_tx
  FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));
GRANT SELECT, INSERT, UPDATE, DELETE ON public.spike_tx TO authenticated;
ALTER TABLE public.spike_tx REPLICA IDENTITY FULL;
CREATE PUBLICATION powersync FOR TABLE public.spike_tx;
