-- Budget app schema + RLS. Paste the whole file into the Supabase SQL editor and Run.
-- Append-only and idempotent: safe to re-run. New changes go in a new numbered block before "-- DONE."

-- 1. Tables: one row per (user, month) and one settings row per user.
CREATE TABLE IF NOT EXISTS public.budget_months (
  user_id    uuid        NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  ym         text        NOT NULL CHECK (ym ~ '^[0-9]{4}-[0-9]{2}$'),
  data       jsonb       NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, ym)
);

CREATE TABLE IF NOT EXISTS public.budget_config (
  user_id    uuid        PRIMARY KEY DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  data       jsonb       NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 2. Row Level Security: each signed-in user sees and changes only their own rows.
ALTER TABLE public.budget_months ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budget_config ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.budget_months, public.budget_config FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.budget_months, public.budget_config TO authenticated;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['budget_months', 'budget_config'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_insert', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_update', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_delete', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()))', t || '_select', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT auth.uid()))', t || '_insert', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()))', t || '_update', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING (user_id = (SELECT auth.uid()))', t || '_delete', t);
  END LOOP;
END $$;

-- 3. Keep-alive: a harmless function the weekly GitHub Action calls so the free project doesn't pause.
CREATE OR REPLACE FUNCTION public.keepalive() RETURNS integer
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$ SELECT 1 $$;
GRANT EXECUTE ON FUNCTION public.keepalive() TO anon, authenticated;

-- DONE.

-- Diagnostic (run after the script). Expected: tables_exist = 2, rls_on = 2, policies = 8, keepalive = true
-- SELECT
--   (SELECT count(*) FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('budget_months','budget_config')) AS tables_exist,
--   (SELECT count(*) FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('budget_months','budget_config') AND rowsecurity) AS rls_on,
--   (SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename IN ('budget_months','budget_config')) AS policies,
--   EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'keepalive') AS keepalive;
