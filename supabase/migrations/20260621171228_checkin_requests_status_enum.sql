-- ============================================================
-- Migration: Convert checkin_requests.status from TEXT to ENUM
-- ============================================================
-- DIAGNOSIS:
--   Blocking object A: CHECK constraint "checkin_requests_status_check"
--     Expression: status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])
--     This causes "operator does not exist: checkin_request_status = text" because
--     PostgreSQL re-validates the CHECK constraint against the new enum type during
--     ALTER COLUMN TYPE.
--
--   Blocking object B: Any RLS policies on checkin_requests that compare status
--     to text literals (e.g. status = 'pending') will also fail after type conversion.
--
-- FIX ORDER:
--   1. Drop CHECK constraint
--   2. Drop all RLS policies on checkin_requests (recreated after with enum casting)
--   3. Normalize data: 'rejected' -> 'denied', sanitize unknowns
--   4. Create enum type (idempotent)
--   5. Drop column default (required before ALTER COLUMN TYPE)
--   6. ALTER COLUMN TYPE using EXECUTE (dynamic SQL) to resolve cast at runtime
--   7. Re-apply default
--   8. Recreate RLS policies using enum literals (not text comparisons)
-- ============================================================

-- ── Step 1: Drop the CHECK constraint (the primary blocking object) ──
ALTER TABLE public.checkin_requests
  DROP CONSTRAINT IF EXISTS checkin_requests_status_check;

-- ── Step 2: Drop all RLS policies on checkin_requests ───────────────
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT polname
    FROM pg_policy
    WHERE polrelid = 'public.checkin_requests'::regclass
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.checkin_requests', pol.polname);
  END LOOP;
END $$;

-- ── Step 3: Normalize existing data (column is still TEXT here) ─────
UPDATE public.checkin_requests
  SET status = 'denied'
  WHERE status = 'rejected';

UPDATE public.checkin_requests
  SET status = 'pending'
  WHERE status IS NOT NULL
    AND status NOT IN ('pending', 'approved', 'denied');

-- ── Step 4: Create the enum type (idempotent) ───────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'checkin_request_status') THEN
    CREATE TYPE public.checkin_request_status AS ENUM ('pending', 'approved', 'denied');
  END IF;
END $$;

-- ── Step 5: Drop column default before type change ──────────────────
ALTER TABLE public.checkin_requests
  ALTER COLUMN status DROP DEFAULT;

-- ── Step 6: Convert column type using dynamic SQL (EXECUTE) ─────────
-- EXECUTE forces PostgreSQL to resolve the cast at runtime (after the enum
-- type is registered), avoiding the parse-time "operator does not exist:
-- checkin_request_status = text" error that occurs with static PL/pgSQL.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'checkin_requests'
      AND column_name  = 'status'
      AND data_type IN ('text', 'character varying')
  ) THEN
    EXECUTE '
      ALTER TABLE public.checkin_requests
        ALTER COLUMN status TYPE public.checkin_request_status
          USING status::public.checkin_request_status
    ';
  END IF;
END $$;

-- ── Step 7: Re-apply default ─────────────────────────────────────────
ALTER TABLE public.checkin_requests
  ALTER COLUMN status SET DEFAULT 'pending'::public.checkin_request_status;

-- ── Step 8: Recreate RLS policies using enum literals ────────────────
ALTER TABLE public.checkin_requests ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to insert their own checkin requests
DROP POLICY IF EXISTS "checkin_requests_insert_own" ON public.checkin_requests;
CREATE POLICY "checkin_requests_insert_own"
  ON public.checkin_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (main_user_id = auth.uid());

-- Allow authenticated users to view their own checkin requests
DROP POLICY IF EXISTS "checkin_requests_select_own" ON public.checkin_requests;
CREATE POLICY "checkin_requests_select_own"
  ON public.checkin_requests
  FOR SELECT
  TO authenticated
  USING (main_user_id = auth.uid());

-- Allow authenticated users to update their own checkin requests
DROP POLICY IF EXISTS "checkin_requests_update_own" ON public.checkin_requests;
CREATE POLICY "checkin_requests_update_own"
  ON public.checkin_requests
  FOR UPDATE
  TO authenticated
  USING (main_user_id = auth.uid())
  WITH CHECK (main_user_id = auth.uid());

-- Allow service_role full access (used by admin/reception backend operations)
DROP POLICY IF EXISTS "checkin_requests_service_role_all" ON public.checkin_requests;
CREATE POLICY "checkin_requests_service_role_all"
  ON public.checkin_requests
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ── Step 9: Verify (informational — does not block migration) ────────
DO $$
DECLARE
  col_type TEXT;
BEGIN
  SELECT udt_name INTO col_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'checkin_requests'
    AND column_name  = 'status';

  IF col_type = 'checkin_request_status' THEN
    RAISE NOTICE 'SUCCESS: checkin_requests.status is now type checkin_request_status (enum)';
  ELSE
    RAISE NOTICE 'WARNING: checkin_requests.status type is %, expected checkin_request_status', col_type;
  END IF;
END $$;
