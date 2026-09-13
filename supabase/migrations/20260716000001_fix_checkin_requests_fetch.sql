-- ============================================================
-- Migration: Fix checkin_requests fetch for reception (anon role)
-- ============================================================
-- ROOT CAUSE:
--   The reception app uses the Supabase anon key WITHOUT calling
--   auth.signIn(). All queries run as the 'anon' role.
--
--   The fetchCheckinRequests method does two queries:
--     1. SELECT stay_id FROM stay WHERE hotel_id = propertyId
--     2. SELECT ... FROM checkin_requests JOIN users WHERE stay_id IN (...)
--
--   PROBLEM A: stay table has RLS enabled. There is no anon SELECT policy
--   on the stay table, so query 1 returns 0 rows → stayIds is empty →
--   fetchCheckinRequests returns [] immediately without ever querying
--   checkin_requests.
--
--   PROBLEM B: Even if stay query worked, the checkin_requests query joins
--   the users table (users!checkin_requests_main_user_id_fkey). The users
--   table has RLS enabled with no anon SELECT policy, so PostgREST returns
--   an error for the join, causing the entire query to fail.
--
-- FIX:
--   1. Add anon SELECT policy on stay table (mirrors pattern used by
--      other tables in this app: laundry_requests, spa_orders, etc.)
--   2. Add anon SELECT policy on users table (read-only, for joins)
--   Both policies use USING (true) — open read access for anon role,
--   matching the established pattern in this codebase.
-- ============================================================

-- ── Fix A: Allow anon to SELECT from stay table ──────────────────────
DROP POLICY IF EXISTS "stay_select_anon" ON public.stay;
CREATE POLICY "stay_select_anon"
  ON public.stay
  FOR SELECT
  TO anon
  USING (true);

-- ── Fix B: Allow anon to SELECT from users table (for joins) ─────────
DROP POLICY IF EXISTS "users_select_anon" ON public.users;
CREATE POLICY "users_select_anon"
  ON public.users
  FOR SELECT
  TO anon
  USING (true);

-- ── Verify ───────────────────────────────────────────────────────────
DO $$
BEGIN
  RAISE NOTICE 'stay_select_anon policy created: anon can now SELECT from stay table';
  RAISE NOTICE 'users_select_anon policy created: anon can now SELECT from users table';
  RAISE NOTICE 'checkin_requests has rls_enabled=false: all rows accessible without policies';
END $$;
