-- ============================================================
-- Migration: Fix stay, stay_rooms & stay_guests RLS for Anon / Staff Access
-- ============================================================
-- ROOT CAUSE:
--   The admin desk app connects to Supabase using the Anon API key
--   without creating an Auth session (auth.uid() is null).
--   The previous stay policies were scoped strictly to 'TO authenticated'.
--   When the reception desk creates an upcoming booking or walk-in,
--   PostgreSQL rejects the INSERT with:
--   "new row violates row-level security policy for table 'stay'".
--
-- FIX:
--   Grant SELECT, INSERT, UPDATE, DELETE permissions on `stay`, `stay_rooms`,
--   and `stay_guests` for BOTH 'anon' and 'authenticated' roles, matching
--   the pattern used across the other reception tables in this database.
-- ============================================================

-- ── 1. Fix `public.stay` Policies ────────────────────────────
DROP POLICY IF EXISTS "stay_open_access"          ON public.stay;
DROP POLICY IF EXISTS "stay_select_anon"          ON public.stay;
DROP POLICY IF EXISTS "stay_insert_anon"          ON public.stay;
DROP POLICY IF EXISTS "stay_update_anon"          ON public.stay;
DROP POLICY IF EXISTS "stay_delete_anon"          ON public.stay;
DROP POLICY IF EXISTS "stay_user_select"          ON public.stay;
DROP POLICY IF EXISTS "stay_user_insert"          ON public.stay;
DROP POLICY IF EXISTS "stay_user_update"          ON public.stay;
DROP POLICY IF EXISTS "stay_user_delete"          ON public.stay;
DROP POLICY IF EXISTS "stay_employee_select"      ON public.stay;
DROP POLICY IF EXISTS "stay_employee_insert"      ON public.stay;
DROP POLICY IF EXISTS "stay_employee_update"      ON public.stay;
DROP POLICY IF EXISTS "stay_employee_delete"      ON public.stay;

CREATE POLICY "stay_open_access"
  ON public.stay
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- ── 2. Fix `public.stay_rooms` Policies ──────────────────────
ALTER TABLE public.stay_rooms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stay_rooms_open_access" ON public.stay_rooms;
CREATE POLICY "stay_rooms_open_access"
  ON public.stay_rooms
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- ── 3. Fix `public.stay_guests` Policies ─────────────────────
ALTER TABLE public.stay_guests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stay_guests_open_access" ON public.stay_guests;
CREATE POLICY "stay_guests_open_access"
  ON public.stay_guests
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- ── 4. Verify ────────────────────────────────────────────────
DO $$
BEGIN
  RAISE NOTICE 'RLS open access policies successfully applied to stay, stay_rooms, and stay_guests for anon and authenticated roles.';
END $$;
