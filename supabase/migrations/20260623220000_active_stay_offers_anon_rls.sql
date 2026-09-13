-- ─────────────────────────────────────────────────────────────────────────────
-- RLS Policies for active_stay_offers — anon role
-- The admin app uses the anon key without an authenticated session,
-- so INSERT/UPDATE/DELETE must also be granted to the anon role.
-- ─────────────────────────────────────────────────────────────────────────────

-- SELECT for anon
DROP POLICY IF EXISTS "active_stay_offers_select_anon" ON public.active_stay_offers;
CREATE POLICY "active_stay_offers_select_anon"
  ON public.active_stay_offers
  FOR SELECT
  TO anon
  USING (true);

-- INSERT for anon
DROP POLICY IF EXISTS "active_stay_offers_insert_anon" ON public.active_stay_offers;
CREATE POLICY "active_stay_offers_insert_anon"
  ON public.active_stay_offers
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- UPDATE for anon
DROP POLICY IF EXISTS "active_stay_offers_update_anon" ON public.active_stay_offers;
CREATE POLICY "active_stay_offers_update_anon"
  ON public.active_stay_offers
  FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

-- DELETE for anon
DROP POLICY IF EXISTS "active_stay_offers_delete_anon" ON public.active_stay_offers;
CREATE POLICY "active_stay_offers_delete_anon"
  ON public.active_stay_offers
  FOR DELETE
  TO anon
  USING (true);
