-- Fix: laundry_requests and spa_orders have RLS enabled but no policies,
-- causing the admin app (anon key, no auth session) to see 0 rows silently.
-- Mirror the open-access pattern used by all other tables in this project.

-- ── laundry_requests ──────────────────────────────────────────────────────
DROP POLICY IF EXISTS "laundry_requests_open_access" ON public.laundry_requests;
CREATE POLICY "laundry_requests_open_access"
  ON public.laundry_requests
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- ── spa_orders ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "spa_orders_open_access" ON public.spa_orders;
CREATE POLICY "spa_orders_open_access"
  ON public.spa_orders
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
