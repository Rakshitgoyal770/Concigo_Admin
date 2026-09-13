-- ============================================================
-- Migration: Fix checkin_requests.status TEXT → ENUM conversion
-- ============================================================
-- ROOT CAUSE ANALYSIS (from live schema diagnostic):
--
--   The previous migration used:
--     DROP CONSTRAINT IF EXISTS checkin_requests_status_check
--   This silently did NOTHING because the actual constraint name in the
--   live database is NOT "checkin_requests_status_check" — it is a
--   system-generated name. The IF EXISTS clause suppressed the error,
--   so the migration appeared to proceed, but the constraint was never
--   dropped. The ALTER COLUMN then failed every time with:
--     ERROR: 42883: operator does not exist: checkin_request_status = text
--   because PostgreSQL re-validates the CHECK constraint against the new
--   enum type during ALTER COLUMN TYPE, and there is no = operator
--   between checkin_request_status and text.
--
-- CONFIRMED LIVE STATE (from list_tables diagnostic):
--   - checkin_requests.status: data_type = "text" (still TEXT, not enum)
--   - CHECK constraint: status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])
--   - Constraint name: UNKNOWN (system-generated, not "checkin_requests_status_check")
--
-- FIX STRATEGY:
--   1. Drop ALL check constraints on checkin_requests.status by querying
--      pg_constraint dynamically — this works regardless of the constraint name.
--   2. Drop all RLS policies (recreated after with enum-safe expressions).
--   3. Normalize data: map 'rejected' → 'denied', sanitize unknowns → 'pending'.
--   4. Create enum type (idempotent).
--   5. Convert column type using EXECUTE (dynamic SQL, resolves cast at runtime).
--   6. Re-apply default.
--   7. Recreate RLS policies with enum literals.
-- ============================================================

-- ── Step 1: Drop ALL check constraints on the status column (by dynamic lookup) ──
-- This is the critical fix: we do NOT assume the constraint name.
-- We find every CHECK constraint on checkin_requests that references the status
-- column and drop it, regardless of what it is named.
DO $$
DECLARE
  con RECORD;
BEGIN
  FOR con IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid
      AND a.attnum = ANY(c.conkey)
    WHERE c.conrelid = 'public.checkin_requests'::regclass
      AND c.contype = 'c'
      AND a.attname = 'status'
  LOOP
    RAISE NOTICE 'Dropping CHECK constraint: %', con.conname;
    EXECUTE format('ALTER TABLE public.checkin_requests DROP CONSTRAINT IF EXISTS %I', con.conname);
  END LOOP;
END $$;

-- ── Step 2: Drop all RLS policies on checkin_requests ───────────────
-- They will be recreated after the type conversion with enum-safe expressions.
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT polname
    FROM pg_policy
    WHERE polrelid = 'public.checkin_requests'::regclass
  LOOP
    RAISE NOTICE 'Dropping RLS policy: %', pol.polname;
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.checkin_requests', pol.polname);
  END LOOP;
END $$;

-- ── Step 3: Normalize existing data (column is still TEXT at this point) ──
-- Map 'rejected' → 'denied' (enum uses 'denied', not 'rejected')
UPDATE public.checkin_requests
  SET status = 'denied'
  WHERE status = 'rejected';

-- Sanitize any unknown values to 'pending'
UPDATE public.checkin_requests
  SET status = 'pending'
  WHERE status IS NOT NULL
    AND status NOT IN ('pending', 'approved', 'denied');

-- ── Step 4: Create the enum type (idempotent) ───────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'checkin_request_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.checkin_request_status AS ENUM ('pending', 'approved', 'denied');
    RAISE NOTICE 'Created enum type checkin_request_status';
  ELSE
    RAISE NOTICE 'Enum type checkin_request_status already exists, skipping creation';
  END IF;
END $$;

-- ── Step 5: Convert column type (only if still TEXT) ────────────────
-- Uses EXECUTE (dynamic SQL) so PostgreSQL resolves the cast at runtime,
-- after the enum type is registered in the current session.
-- Also drops the default first (required before ALTER COLUMN TYPE).
DO $$
DECLARE
  col_type TEXT;
BEGIN
  SELECT data_type INTO col_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'checkin_requests'
    AND column_name  = 'status';

  RAISE NOTICE 'Current status column type: %', col_type;

  IF col_type IN ('text', 'character varying') THEN
    -- Drop default before type change
    EXECUTE 'ALTER TABLE public.checkin_requests ALTER COLUMN status DROP DEFAULT';

    -- Convert column type using double-cast (varchar → text → enum)
    EXECUTE '
      ALTER TABLE public.checkin_requests
        ALTER COLUMN status TYPE public.checkin_request_status
          USING status::text::public.checkin_request_status
    ';

    -- Re-apply default as enum literal
    EXECUTE 'ALTER TABLE public.checkin_requests ALTER COLUMN status SET DEFAULT ''pending''::public.checkin_request_status';

    RAISE NOTICE 'Column status converted to checkin_request_status enum';
  ELSE
    RAISE NOTICE 'Column status is already type %, skipping conversion', col_type;
  END IF;
END $$;

-- ── Step 6: Recreate RLS policies using enum literals ────────────────
-- All string comparisons against status now use enum-typed literals.
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

-- ── Step 7: Verify final state ───────────────────────────────────────
DO $$
DECLARE
  col_type TEXT;
  col_udt  TEXT;
BEGIN
  SELECT data_type, udt_name INTO col_type, col_udt
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'checkin_requests'
    AND column_name  = 'status';

  IF col_udt = 'checkin_request_status' THEN
    RAISE NOTICE 'SUCCESS: checkin_requests.status is now type checkin_request_status (enum). data_type=%, udt_name=%', col_type, col_udt;
  ELSE
    RAISE WARNING 'UNEXPECTED: checkin_requests.status type is data_type=%, udt_name=%. Expected udt_name=checkin_request_status', col_type, col_udt;
  END IF;
END $$;
