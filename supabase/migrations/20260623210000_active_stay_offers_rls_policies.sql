-- ─────────────────────────────────────────────────────────────────────────────
-- RLS Policies for active_stay_offers
-- The table already has RLS enabled but was missing all policies,
-- causing "new row violates row-level security policy" on INSERT.
-- ─────────────────────────────────────────────────────────────────────────────

-- Allow authenticated staff to SELECT all offers
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'active_stay_offers'
      AND policyname = 'active_stay_offers_select_authenticated'
  ) THEN
    CREATE POLICY "active_stay_offers_select_authenticated"
      ON public.active_stay_offers
      FOR SELECT
      TO authenticated
      USING (true);
  END IF;
END $$;

-- Allow authenticated staff to INSERT new offers
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'active_stay_offers'
      AND policyname = 'active_stay_offers_insert_authenticated'
  ) THEN
    CREATE POLICY "active_stay_offers_insert_authenticated"
      ON public.active_stay_offers
      FOR INSERT
      TO authenticated
      WITH CHECK (true);
  END IF;
END $$;

-- Allow authenticated staff to UPDATE offers (e.g. toggle is_active, edit details)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'active_stay_offers'
      AND policyname = 'active_stay_offers_update_authenticated'
  ) THEN
    CREATE POLICY "active_stay_offers_update_authenticated"
      ON public.active_stay_offers
      FOR UPDATE
      TO authenticated
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;

-- Allow authenticated staff to DELETE offers
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'active_stay_offers'
      AND policyname = 'active_stay_offers_delete_authenticated'
  ) THEN
    CREATE POLICY "active_stay_offers_delete_authenticated"
      ON public.active_stay_offers
      FOR DELETE
      TO authenticated
      USING (true);
  END IF;
END $$;
