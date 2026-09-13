-- ─────────────────────────────────────────────────────────────────────────────
-- RLS Policies for active_upgrade_accepts — anon role
-- The admin app uses the Supabase anon key without an authenticated session,
-- so SELECT, INSERT, and UPDATE must also be granted to the anon role.
-- ─────────────────────────────────────────────────────────────────────────────

-- SELECT for anon (reception desk reads pending entries)
DROP POLICY IF EXISTS "active_upgrade_accepts_select_anon" ON public.active_upgrade_accepts;
CREATE POLICY "active_upgrade_accepts_select_anon"
  ON public.active_upgrade_accepts
  FOR SELECT
  TO anon
  USING (true);

-- INSERT for anon (guests may accept offers via anon session)
DROP POLICY IF EXISTS "active_upgrade_accepts_insert_anon" ON public.active_upgrade_accepts;
CREATE POLICY "active_upgrade_accepts_insert_anon"
  ON public.active_upgrade_accepts
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- UPDATE for anon (reception desk allots room → status = 'room_allotted')
DROP POLICY IF EXISTS "active_upgrade_accepts_update_anon" ON public.active_upgrade_accepts;
CREATE POLICY "active_upgrade_accepts_update_anon"
  ON public.active_upgrade_accepts
  FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

-- DELETE for anon (optional, for future cleanup operations)
DROP POLICY IF EXISTS "active_upgrade_accepts_delete_anon" ON public.active_upgrade_accepts;
CREATE POLICY "active_upgrade_accepts_delete_anon"
  ON public.active_upgrade_accepts
  FOR DELETE
  TO anon
  USING (true);
