-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Room Upgrade New Schema
-- 1. Drop old room_upgrade_offers table (old schema incompatible) and recreate
-- 2. Create room_upgrade_orders table
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. Drop old enum and table (old schema is incompatible) ──────────────────
DROP TABLE IF EXISTS public.room_upgrade_offers CASCADE;
DROP TYPE IF EXISTS public.upgrade_offer_status CASCADE;

-- ── 2. Create new room_upgrade_offers table ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.room_upgrade_offers (
  offer_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id       UUID NOT NULL REFERENCES public.hotel_property(property_id) ON DELETE CASCADE,
  room_type         TEXT NOT NULL,
  original_price    NUMERIC(10,2) NOT NULL,
  discounted_price  NUMERIC(10,2) NOT NULL,
  valid_from        TIMESTAMPTZ NOT NULL,
  valid_until       TIMESTAMPTZ NOT NULL,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_room_upgrade_offers_property_id
  ON public.room_upgrade_offers(property_id);

CREATE INDEX IF NOT EXISTS idx_room_upgrade_offers_is_active
  ON public.room_upgrade_offers(is_active);

-- RLS
ALTER TABLE public.room_upgrade_offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "open_access_room_upgrade_offers" ON public.room_upgrade_offers;
CREATE POLICY "open_access_room_upgrade_offers"
  ON public.room_upgrade_offers
  FOR ALL
  TO public
  USING (true)
  WITH CHECK (true);

-- updated_at trigger
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_room_upgrade_offers_updated_at ON public.room_upgrade_offers;
CREATE TRIGGER trg_room_upgrade_offers_updated_at
  BEFORE UPDATE ON public.room_upgrade_offers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 3. Create room_upgrade_orders table ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.room_upgrade_orders (
  order_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
  stay_id             UUID NOT NULL REFERENCES public.stay(stay_id) ON DELETE CASCADE,
  upg_offer_id        UUID NOT NULL REFERENCES public.room_upgrade_offers(offer_id) ON DELETE CASCADE,
  property_id         UUID NOT NULL REFERENCES public.hotel_property(property_id) ON DELETE CASCADE,
  amount_paid         NUMERIC(10,2) NOT NULL,
  currency            TEXT NOT NULL DEFAULT 'INR',
  payment_status      TEXT NOT NULL DEFAULT 'pending',
  razorpay_order_id   TEXT,
  razorpay_payment_id TEXT,
  new_room_id         UUID REFERENCES public.rooms(room_id),
  allotted_by         UUID REFERENCES public.property_employees(emp_id),
  allotted_at         TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at          TIMESTAMPTZ,
  CONSTRAINT chk_payment_status CHECK (payment_status IN ('pending','paid','failed'))
);

CREATE INDEX IF NOT EXISTS idx_room_upgrade_orders_property_id
  ON public.room_upgrade_orders(property_id);

CREATE INDEX IF NOT EXISTS idx_room_upgrade_orders_payment_status
  ON public.room_upgrade_orders(payment_status);

CREATE INDEX IF NOT EXISTS idx_room_upgrade_orders_stay_id
  ON public.room_upgrade_orders(stay_id);

-- RLS
ALTER TABLE public.room_upgrade_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff_all_upgrade_orders" ON public.room_upgrade_orders;
CREATE POLICY "staff_all_upgrade_orders"
  ON public.room_upgrade_orders
  FOR ALL
  TO public
  USING (true)
  WITH CHECK (true);

-- updated_at trigger
DROP TRIGGER IF EXISTS trg_room_upgrade_orders_updated_at ON public.room_upgrade_orders;
CREATE TRIGGER trg_room_upgrade_orders_updated_at
  BEFORE UPDATE ON public.room_upgrade_orders
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
