-- ─────────────────────────────────────────────────────────────────────────────
-- Early Check-In / Late Check-Out Offer Tables
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. early_late_offers
CREATE TABLE IF NOT EXISTS public.early_late_offers (
  offer_id        uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id     uuid        NOT NULL REFERENCES public.hotel_property(property_id),
  offer_name      text        NOT NULL,
  stay_id         uuid        REFERENCES public.stay(stay_id),
  min_time        timestamptz,
  max_time        timestamptz,
  type            text        NOT NULL CHECK (type IN ('early_in', 'late_out')),
  price_per_hour  numeric     NOT NULL,
  status          text        NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'disabled')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_early_late_offers_property_id
  ON public.early_late_offers (property_id);

CREATE INDEX IF NOT EXISTS idx_early_late_offers_type_status
  ON public.early_late_offers (property_id, type, status);

-- 2. early_late_offer_accepts
CREATE TABLE IF NOT EXISTS public.early_late_offer_accepts (
  accept_id       uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id        uuid        NOT NULL REFERENCES public.early_late_offers(offer_id),
  user_id         uuid        NOT NULL REFERENCES public.users(user_id),
  stay_id         uuid        NOT NULL REFERENCES public.stay(stay_id),
  type            text        NOT NULL CHECK (type IN ('early_in', 'late_out')),
  time_selected   timestamptz NOT NULL,
  amount_paid     numeric     NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_early_late_offer_accepts_offer_id
  ON public.early_late_offer_accepts (offer_id);

CREATE INDEX IF NOT EXISTS idx_early_late_offer_accepts_stay_id
  ON public.early_late_offer_accepts (stay_id);

-- 3. early_late_offer_payments
CREATE TABLE IF NOT EXISTS public.early_late_offer_payments (
  payment_id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  accept_id           uuid        NOT NULL REFERENCES public.early_late_offer_accepts(accept_id),
  user_id             uuid        NOT NULL REFERENCES public.users(user_id),
  stay_id             uuid        NOT NULL REFERENCES public.stay(stay_id),
  offer_id            uuid        NOT NULL REFERENCES public.early_late_offers(offer_id),
  razorpay_order_id   text,
  razorpay_payment_id text,
  amount              numeric     NOT NULL,
  gst_amount          numeric     NOT NULL,
  total_amount        numeric     NOT NULL,
  status              text        NOT NULL CHECK (status IN ('success', 'failed')),
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_early_late_offer_payments_accept_id
  ON public.early_late_offer_payments (accept_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- RLS
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.early_late_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.early_late_offer_accepts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.early_late_offer_payments ENABLE ROW LEVEL SECURITY;

-- early_late_offers policies
DROP POLICY IF EXISTS "elo_anon_select" ON public.early_late_offers;
CREATE POLICY "elo_anon_select" ON public.early_late_offers
  FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "elo_anon_insert" ON public.early_late_offers;
CREATE POLICY "elo_anon_insert" ON public.early_late_offers
  FOR INSERT TO anon WITH CHECK (true);

DROP POLICY IF EXISTS "elo_anon_update" ON public.early_late_offers;
CREATE POLICY "elo_anon_update" ON public.early_late_offers
  FOR UPDATE TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "elo_anon_delete" ON public.early_late_offers;
CREATE POLICY "elo_anon_delete" ON public.early_late_offers
  FOR DELETE TO anon USING (true);

DROP POLICY IF EXISTS "elo_auth_all" ON public.early_late_offers;
CREATE POLICY "elo_auth_all" ON public.early_late_offers
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- early_late_offer_accepts policies
DROP POLICY IF EXISTS "eloa_anon_select" ON public.early_late_offer_accepts;
CREATE POLICY "eloa_anon_select" ON public.early_late_offer_accepts
  FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "eloa_anon_insert" ON public.early_late_offer_accepts;
CREATE POLICY "eloa_anon_insert" ON public.early_late_offer_accepts
  FOR INSERT TO anon WITH CHECK (true);

DROP POLICY IF EXISTS "eloa_anon_update" ON public.early_late_offer_accepts;
CREATE POLICY "eloa_anon_update" ON public.early_late_offer_accepts
  FOR UPDATE TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "eloa_auth_all" ON public.early_late_offer_accepts;
CREATE POLICY "eloa_auth_all" ON public.early_late_offer_accepts
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- early_late_offer_payments policies
DROP POLICY IF EXISTS "elop_anon_select" ON public.early_late_offer_payments;
CREATE POLICY "elop_anon_select" ON public.early_late_offer_payments
  FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "elop_anon_insert" ON public.early_late_offer_payments;
CREATE POLICY "elop_anon_insert" ON public.early_late_offer_payments
  FOR INSERT TO anon WITH CHECK (true);

DROP POLICY IF EXISTS "elop_anon_update" ON public.early_late_offer_payments;
CREATE POLICY "elop_anon_update" ON public.early_late_offer_payments
  FOR UPDATE TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "elop_auth_all" ON public.early_late_offer_payments;
CREATE POLICY "elop_auth_all" ON public.early_late_offer_payments
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
