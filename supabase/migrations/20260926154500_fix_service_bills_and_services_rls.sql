-- ============================================================
-- Migration: Enable read access on services and service_bills for anon & authenticated
-- ============================================================

-- 1. Services table policies
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "services_read_access" ON public.services;
CREATE POLICY "services_read_access"
  ON public.services
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- 2. Service bills table policies
ALTER TABLE public.service_bills ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_bills_read_access" ON public.service_bills;
CREATE POLICY "service_bills_read_access"
  ON public.service_bills
  FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "service_bills_update_access" ON public.service_bills;
CREATE POLICY "service_bills_update_access"
  ON public.service_bills
  FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
