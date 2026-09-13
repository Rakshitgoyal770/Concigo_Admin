-- ============================================================
-- Migration: Fix checkin_requests RLS to allow anon role access
-- ============================================================
-- ROOT CAUSE:
--   The admin app uses the Supabase anon key WITHOUT calling any
--   auth.signIn() method. This means all queries run as the 'anon'
--   role, NOT the 'authenticated' role.
--
--   The previous staff policies were scoped to 'TO authenticated':
--     staff_select_checkin_requests — TO authenticated, USING (true)
--     staff_update_checkin_requests — TO authenticated, USING (true)
--
--   Since the admin app runs as 'anon', these policies never matched,
--   and all checkin_requests rows were blocked by RLS.
--
--   The stay table has RLS DISABLED, so the first query step
--   (fetching stay_ids for the property) works fine. But the second
--   step (fetching checkin_requests by stay_id) fails silently —
--   returning 0 rows instead of an error — because RLS blocks the
--   anon session from reading any checkin_requests rows.
--
-- FIX:
--   Drop the existing staff policies and recreate them to include
--   BOTH 'anon' AND 'authenticated' roles, matching the exact pattern
--   used by laundry_requests and spa_orders (which also grant access
--   to both anon and authenticated).
--
-- PATTERN REFERENCE:
--   laundry_requests_open_access — ALL, TO anon, authenticated, USING (true)
--   spa_orders_open_access       — ALL, TO anon, authenticated, USING (true)
-- ============================================================

-- ── Drop existing staff policies (scoped to authenticated only) ──────
DROP POLICY IF EXISTS "staff_select_checkin_requests" ON public.checkin_requests;
DROP POLICY IF EXISTS "staff_update_checkin_requests" ON public.checkin_requests;

-- ── Recreate SELECT policy for BOTH anon and authenticated ───────────
-- This allows the admin app (anon key, no auth session) to read all rows.
-- Also allows authenticated sessions (future use / guest app staff).
CREATE POLICY "staff_select_checkin_requests"
  ON public.checkin_requests
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- ── Recreate UPDATE policy for BOTH anon and authenticated ───────────
-- Required for approve/deny actions from the reception desk screen.
CREATE POLICY "staff_update_checkin_requests"
  ON public.checkin_requests
  FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- ── Also fix INSERT policy to allow anon (for guest app using anon key) ──
-- The existing insert policy is TO authenticated only; guest app also uses anon key.
DROP POLICY IF EXISTS "checkin_requests_insert_own" ON public.checkin_requests;
CREATE POLICY "checkin_requests_insert_own"
  ON public.checkin_requests
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- ── Verify policies ──────────────────────────────────────────────────
DO $$
DECLARE
  pol_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO pol_count
  FROM pg_policy
  WHERE polrelid = 'public.checkin_requests'::regclass;
  RAISE NOTICE 'checkin_requests now has % RLS policies', pol_count;
END $$;
