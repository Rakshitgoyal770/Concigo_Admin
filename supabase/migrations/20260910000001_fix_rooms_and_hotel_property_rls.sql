-- ============================================================
-- Migration: Fix rooms & hotel_property RLS for Anon / Reception Access
-- ============================================================
-- ROOT CAUSE:
--   The admin desk app connects to Supabase using the Anon API key
--   without creating a Supabase Auth session (auth.uid() is null).
--   When Row Level Security (RLS) is enabled on `public.rooms` and
--   `public.hotel_property` without a permissive policy for `anon`,
--   PostgreSQL silently returns an empty array `[]` on SELECT and
--   rejects writes with:
--   "new row violates row-level security policy for table 'rooms'".
--
-- FIX:
--   Grant SELECT, INSERT, UPDATE, DELETE permissions on `rooms` and
--   `hotel_property` for BOTH 'anon' and 'authenticated' roles, matching
--   the pattern used across the other reception tables in this database
--   (stay, stay_rooms, stay_guests, checkin_requests).
-- ============================================================

-- ── 1. Fix `public.rooms` Policies ────────────────────────────
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "rooms_open_access"          ON public.rooms;
DROP POLICY IF EXISTS "rooms_select_anon"          ON public.rooms;
DROP POLICY IF EXISTS "rooms_insert_anon"          ON public.rooms;
DROP POLICY IF EXISTS "rooms_update_anon"          ON public.rooms;
DROP POLICY IF EXISTS "rooms_delete_anon"          ON public.rooms;

CREATE POLICY "rooms_open_access"
  ON public.rooms
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- ── 2. Fix `public.hotel_property` Policies ───────────────────
ALTER TABLE public.hotel_property ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "hotel_property_open_access" ON public.hotel_property;
DROP POLICY IF EXISTS "hotel_property_select_anon" ON public.hotel_property;
DROP POLICY IF EXISTS "hotel_property_insert_anon" ON public.hotel_property;
DROP POLICY IF EXISTS "hotel_property_update_anon" ON public.hotel_property;
DROP POLICY IF EXISTS "hotel_property_delete_anon" ON public.hotel_property;

CREATE POLICY "hotel_property_open_access"
  ON public.hotel_property
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- ── 3. Verify ────────────────────────────────────────────────
DO $$
BEGIN
  RAISE NOTICE 'RLS open access policies successfully applied to rooms and hotel_property for anon and authenticated roles.';
END $$;
