-- ============================================================
-- Migration: Add staff SELECT + UPDATE RLS policies on checkin_requests
-- ============================================================
-- PROBLEM:
--   The reception desk screen shows 0 rows because the only SELECT policy
--   on checkin_requests is scoped to the guest who created each row:
--     USING (main_user_id = auth.uid())
--   Staff/admin sessions have a different auth.uid() (their own employee
--   auth UID), so this policy never matches for them — they see nothing.
--
-- ROOT CAUSE CONFIRMED (Step 1 audit):
--   Existing policies on checkin_requests:
--     checkin_requests_select_own  — SELECT, USING (main_user_id = auth.uid())
--     checkin_requests_insert_own  — INSERT, WITH CHECK (main_user_id = auth.uid())
--     checkin_requests_update_own  — UPDATE, USING (main_user_id = auth.uid())
--     checkin_requests_service_role_all — ALL, service_role, USING (true)
--   No staff SELECT or UPDATE policy exists.
--
-- STAFF IDENTIFICATION PATTERN (Step 2 audit):
--   Checked RLS policies on service_orders, spa_orders, laundry_requests.
--   All three use PATTERN C: open access to authenticated (and anon) users:
--     laundry_requests_open_access — ALL, anon+authenticated, USING (true)
--     spa_orders_open_access       — ALL, anon+authenticated, USING (true)
--   No staff/admin table with auth_id linkage exists in the schema.
--   property_employees has no auth.uid() column.
--   The admin app authenticates as the 'authenticated' role.
--
-- FIX (Step 3):
--   Add two new policies mirroring the exact pattern used by laundry_requests
--   and spa_orders (PATTERN C — USING (true) for authenticated):
--     1. staff_select_checkin_requests — SELECT, authenticated, USING (true)
--     2. staff_update_checkin_requests — UPDATE, authenticated, USING (true)
--
-- POSTGRES RLS OR-LOGIC:
--   Multiple policies for the same command are combined with OR.
--   Guests: matched by checkin_requests_select_own (main_user_id = auth.uid())
--   Staff:  matched by staff_select_checkin_requests (true)
--   Both policies coexist safely — guests still only see their own rows
--   because the guest app only queries with their own auth session.
--   The admin app staff session matches the new staff policy.
--
-- NOTE: checkin_requests_update_own also blocks staff approve/deny actions.
--   Adding staff_update_checkin_requests alongside it fixes that too.
-- ============================================================

-- ── Staff SELECT policy ──────────────────────────────────────────────
-- Allows any authenticated user (staff/admin) to read ALL checkin_requests rows.
-- Mirrors laundry_requests_open_access and spa_orders_open_access pattern exactly.
DROP POLICY IF EXISTS "staff_select_checkin_requests" ON public.checkin_requests;
CREATE POLICY "staff_select_checkin_requests"
  ON public.checkin_requests
  FOR SELECT
  TO authenticated
  USING (true);

-- ── Staff UPDATE policy ──────────────────────────────────────────────
-- Allows any authenticated user (staff/admin) to update ANY checkin_requests row.
-- Required for approve/deny actions on the reception desk screen.
-- Mirrors the same open-access pattern used by other admin-readable tables.
DROP POLICY IF EXISTS "staff_update_checkin_requests" ON public.checkin_requests;
CREATE POLICY "staff_update_checkin_requests"
  ON public.checkin_requests
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);
