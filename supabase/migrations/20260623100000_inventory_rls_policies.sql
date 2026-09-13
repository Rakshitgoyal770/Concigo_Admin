-- ─────────────────────────────────────────────────────────────────────────────
-- Inventory RLS Policies for Kitchen, Laundry, and Spa Items
-- kitchen and laundry tables have RLS disabled (open access) — enable RLS
-- and add permissive policies so authenticated staff can manage items.
-- spa_items already has RLS enabled with existing policies.
-- ─────────────────────────────────────────────────────────────────────────────

-- Enable RLS on kitchen and laundry (they are currently disabled)
ALTER TABLE public.kitchen ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.laundry ENABLE ROW LEVEL SECURITY;

-- ── KITCHEN ──────────────────────────────────────────────────────────────────

-- Allow authenticated users to SELECT kitchen items
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'kitchen' AND policyname = 'kitchen_select_authenticated'
  ) THEN
    CREATE POLICY "kitchen_select_authenticated"
      ON public.kitchen FOR SELECT TO authenticated
      USING (true);
  END IF;
END $$;

-- Allow authenticated users to INSERT kitchen items
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'kitchen' AND policyname = 'kitchen_insert_authenticated'
  ) THEN
    CREATE POLICY "kitchen_insert_authenticated"
      ON public.kitchen FOR INSERT TO authenticated
      WITH CHECK (true);
  END IF;
END $$;

-- Allow authenticated users to UPDATE kitchen items
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'kitchen' AND policyname = 'kitchen_update_authenticated'
  ) THEN
    CREATE POLICY "kitchen_update_authenticated"
      ON public.kitchen FOR UPDATE TO authenticated
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;

-- ── LAUNDRY ──────────────────────────────────────────────────────────────────

-- Allow authenticated users to SELECT laundry items
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'laundry' AND policyname = 'laundry_select_authenticated'
  ) THEN
    CREATE POLICY "laundry_select_authenticated"
      ON public.laundry FOR SELECT TO authenticated
      USING (true);
  END IF;
END $$;

-- Allow authenticated users to INSERT laundry items
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'laundry' AND policyname = 'laundry_insert_authenticated'
  ) THEN
    CREATE POLICY "laundry_insert_authenticated"
      ON public.laundry FOR INSERT TO authenticated
      WITH CHECK (true);
  END IF;
END $$;

-- Allow authenticated users to UPDATE laundry items
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'laundry' AND policyname = 'laundry_update_authenticated'
  ) THEN
    CREATE POLICY "laundry_update_authenticated"
      ON public.laundry FOR UPDATE TO authenticated
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;

-- ── SPA ITEMS — add INSERT/UPDATE policies if missing ────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'spa_items' AND policyname = 'spa_items_insert_authenticated'
  ) THEN
    CREATE POLICY "spa_items_insert_authenticated"
      ON public.spa_items FOR INSERT TO authenticated
      WITH CHECK (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'spa_items' AND policyname = 'spa_items_update_authenticated'
  ) THEN
    CREATE POLICY "spa_items_update_authenticated"
      ON public.spa_items FOR UPDATE TO authenticated
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;

-- Also ensure anon can SELECT spa_items (for guest app)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'spa_items' AND policyname = 'spa_items_select_anon'
  ) THEN
    CREATE POLICY "spa_items_select_anon"
      ON public.spa_items FOR SELECT TO anon
      USING (true);
  END IF;
END $$;
