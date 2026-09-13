-- ─────────────────────────────────────────────────────────────────────────────
-- Add `limit` column to early_late_offers
-- Mandatory for early_in offers; nullable for late_out.
-- Also adds a DB trigger that auto-disables an early_in offer once the
-- number of accepted entries reaches the limit.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Add the column (nullable at DB level; app enforces mandatory for early_in)
ALTER TABLE public.early_late_offers
  ADD COLUMN IF NOT EXISTS "limit" bigint;

-- 2. Function: after each insert into early_late_offer_accepts, check if the
--    parent offer's accept count has reached its limit and disable it.
CREATE OR REPLACE FUNCTION public.fn_check_offer_limit()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_limit   bigint;
  v_type    text;
  v_count   bigint;
BEGIN
  -- Fetch the offer's limit and type
  SELECT "limit", type
    INTO v_limit, v_type
    FROM public.early_late_offers
   WHERE offer_id = NEW.offer_id;

  -- Only enforce for early_in offers that have a limit set
  IF v_type = 'early_in' AND v_limit IS NOT NULL THEN
    SELECT COUNT(*)
      INTO v_count
      FROM public.early_late_offer_accepts
     WHERE offer_id = NEW.offer_id;

    IF v_count >= v_limit THEN
      UPDATE public.early_late_offers
         SET status     = 'disabled',
             updated_at = now()
       WHERE offer_id = NEW.offer_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 3. Attach the trigger (drop first for idempotency)
DROP TRIGGER IF EXISTS trg_check_offer_limit ON public.early_late_offer_accepts;

CREATE TRIGGER trg_check_offer_limit
  AFTER INSERT ON public.early_late_offer_accepts
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_check_offer_limit();
