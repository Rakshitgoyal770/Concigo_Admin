-- ─────────────────────────────────────────────────────────────────────────────
-- active_upgrade_accepts: stores guest acceptances of active-stay upgrade offers
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.active_upgrade_accepts (
  accept_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES public.users(user_id),
  stay_id           UUID NOT NULL REFERENCES public.stay(stay_id),
  offer_id          UUID NOT NULL,
  property_id       UUID NOT NULL REFERENCES public.hotel_property(property_id),
  amount_to_be_paid NUMERIC(10,2) NOT NULL DEFAULT 0,
  status            TEXT NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'room_allotted')),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- updated_at trigger (reuse existing set_updated_at function if available)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger
      WHERE tgname = 'trg_active_upgrade_accepts_updated_at'
    ) THEN
      EXECUTE $trigger$
        CREATE TRIGGER trg_active_upgrade_accepts_updated_at
        BEFORE UPDATE ON public.active_upgrade_accepts
        FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
      $trigger$;
    END IF;
  END IF;
END;
$$;

-- RLS
ALTER TABLE public.active_upgrade_accepts ENABLE ROW LEVEL SECURITY;

-- Allow authenticated staff to SELECT all rows for their property
DROP POLICY IF EXISTS "staff_select_active_upgrade_accepts" ON public.active_upgrade_accepts;
CREATE POLICY "staff_select_active_upgrade_accepts"
  ON public.active_upgrade_accepts
  FOR SELECT
  TO authenticated
  USING (true);

-- Allow authenticated staff to UPDATE (for allotment)
DROP POLICY IF EXISTS "staff_update_active_upgrade_accepts" ON public.active_upgrade_accepts;
CREATE POLICY "staff_update_active_upgrade_accepts"
  ON public.active_upgrade_accepts
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Allow guests to INSERT their own acceptances
DROP POLICY IF EXISTS "guest_insert_active_upgrade_accepts" ON public.active_upgrade_accepts;
CREATE POLICY "guest_insert_active_upgrade_accepts"
  ON public.active_upgrade_accepts
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Index for common queries
CREATE INDEX IF NOT EXISTS idx_active_upgrade_accepts_property_status
  ON public.active_upgrade_accepts (property_id, status);

CREATE INDEX IF NOT EXISTS idx_active_upgrade_accepts_stay_id
  ON public.active_upgrade_accepts (stay_id);
