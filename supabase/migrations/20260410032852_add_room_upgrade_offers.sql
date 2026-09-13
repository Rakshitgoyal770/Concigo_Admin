-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: room_upgrade_offers
-- Adds the room_upgrade_offers table for hotel staff to create upsell offers
-- for checked-in / upcoming stay guests.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. ENUM type for offer status
DROP TYPE IF EXISTS public.upgrade_offer_status CASCADE;
CREATE TYPE public.upgrade_offer_status AS ENUM (
  'offered',
  'accepted',
  'rejected',
  'expired'
);

-- 2. Core table
CREATE TABLE IF NOT EXISTS public.room_upgrade_offers (
  offer_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stay_id         UUID NOT NULL REFERENCES public.stay(stay_id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
  current_room_id UUID NOT NULL REFERENCES public.rooms(room_id),
  upgrade_room_id UUID NOT NULL REFERENCES public.rooms(room_id),
  original_price  NUMERIC NOT NULL DEFAULT 0,
  upgrade_price   NUMERIC NOT NULL DEFAULT 0,
  offered_price   NUMERIC NOT NULL DEFAULT 0,
  status          public.upgrade_offer_status NOT NULL DEFAULT 'offered'::public.upgrade_offer_status,
  created_at      TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  updated_at      TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_room_upgrade_offers_stay_id
  ON public.room_upgrade_offers(stay_id);

CREATE INDEX IF NOT EXISTS idx_room_upgrade_offers_status
  ON public.room_upgrade_offers(status);

CREATE INDEX IF NOT EXISTS idx_room_upgrade_offers_user_id
  ON public.room_upgrade_offers(user_id);

-- 4. Partial unique index: only ONE active 'offered' offer per stay at a time
CREATE UNIQUE INDEX IF NOT EXISTS idx_room_upgrade_offers_one_active_per_stay
  ON public.room_upgrade_offers(stay_id)
  WHERE (status = 'offered');

-- 5. RLS (open policy matching existing tables in this project)
ALTER TABLE public.room_upgrade_offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "open_access_room_upgrade_offers" ON public.room_upgrade_offers;
CREATE POLICY "open_access_room_upgrade_offers"
  ON public.room_upgrade_offers
  FOR ALL
  TO public
  USING (true)
  WITH CHECK (true);
