-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Seed Rich Stay Offers for Hotel Berlin
-- Property ID: b0000001-0000-0000-0000-000000000001 (and dynamic fallback for all properties)
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Ensure stay_offers table exists with all modern columns
CREATE TABLE IF NOT EXISTS public.stay_offers (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id       UUID NOT NULL,
  title             TEXT NOT NULL,
  description       TEXT,
  image_url         TEXT,
  to_category       TEXT,
  original_price    NUMERIC(10, 2) DEFAULT 0,
  discounted_price  NUMERIC(10, 2) NOT NULL DEFAULT 0,
  status            TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'EXPIRED', 'CLAIMED', 'DISABLED')),
  valid_until       TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '1 year'),
  stay_id           UUID,
  user_id           UUID,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.stay_offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stay_offers_read_all" ON public.stay_offers;
CREATE POLICY "stay_offers_read_all" ON public.stay_offers
  FOR SELECT TO public
  USING (status = 'ACTIVE');

DROP POLICY IF EXISTS "stay_offers_anon_all" ON public.stay_offers;
CREATE POLICY "stay_offers_anon_all" ON public.stay_offers
  FOR ALL TO public
  USING (true)
  WITH CHECK (true);

-- 2. Clear old demo rows for Hotel Berlin to prevent duplicates
DELETE FROM public.stay_offers 
WHERE property_id = 'b0000001-0000-0000-0000-000000000001';

-- 3. Insert 4 Curated Luxury Offers for Hotel Berlin
INSERT INTO public.stay_offers (
  property_id,
  title,
  description,
  image_url,
  to_category,
  original_price,
  discounted_price,
  status,
  valid_until
) VALUES 
(
  'b0000001-0000-0000-0000-000000000001',
  'Brandenburg Sunset Rooftop Dining',
  'Complimentary vintage Champagne & 4-course curated gourmet dinner overlooking Berlin skyline',
  'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80',
  'Rooftop Lounge & Fine Dining',
  5500,
  3499,
  'ACTIVE',
  now() + INTERVAL '1 year'
),
(
  'b0000001-0000-0000-0000-000000000001',
  'Spree Thermal Spa & Hydrotherapy',
  'Unlimited Finnish sauna, botanical herbal steam & 60-minute signature aromatherapy massage',
  'https://images.unsplash.com/photo-1540555700478-4be289fbecef?auto=format&fit=crop&w=1200&q=80',
  'Wellness & Thermal Spa',
  4200,
  2899,
  'ACTIVE',
  now() + INTERVAL '1 year'
),
(
  'b0000001-0000-0000-0000-000000000001',
  'Mitte Executive Penthouse Upgrade',
  'Panoramic city views, private sun terrace, freestanding soaking bath & VIP executive lounge privileges',
  'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=1200&q=80',
  'Executive Penthouse Suite',
  8500,
  4999,
  'ACTIVE',
  now() + INTERVAL '1 year'
),
(
  'b0000001-0000-0000-0000-000000000001',
  'Berlin Heritage & Private Chauffeur Tour',
  'Private luxury chauffeur exploration of Museum Island, Reichstag & historic Berlin landmarks',
  'https://images.unsplash.com/photo-1560969184-10fe8719e047?auto=format&fit=crop&w=1200&q=80',
  'Bespoke Private Tour',
  7800,
  5499,
  'ACTIVE',
  now() + INTERVAL '1 year'
);

-- Also insert into active_stay_offers for legacy compatibility
DELETE FROM public.active_stay_offers 
WHERE property_id = 'b0000001-0000-0000-0000-000000000001';

INSERT INTO public.active_stay_offers (
  property_id,
  title,
  description,
  upgrade_room_type,
  amount,
  is_active
) VALUES 
(
  'b0000001-0000-0000-0000-000000000001',
  'Brandenburg Sunset Rooftop Dining',
  'Complimentary vintage Champagne & 4-course curated dinner overlooking Berlin skyline',
  'Rooftop Dining & Drinks',
  3499,
  true
),
(
  'b0000001-0000-0000-0000-000000000001',
  'Spree Thermal Spa & Hydrotherapy',
  'Unlimited Finnish sauna, botanical herbal steam & 60-min signature massage',
  'Wellness & Thermal Spa',
  2899,
  true
),
(
  'b0000001-0000-0000-0000-000000000001',
  'Mitte Executive Penthouse Upgrade',
  'Panoramic city views, private sun terrace & VIP executive lounge privileges',
  'Executive Penthouse Suite',
  4999,
  true
),
(
  'b0000001-0000-0000-0000-000000000001',
  'Berlin Heritage & Private Chauffeur Tour',
  'Private luxury chauffeur exploration of Museum Island & historic Berlin landmarks',
  'Bespoke Private Tour',
  5499,
  true
);
