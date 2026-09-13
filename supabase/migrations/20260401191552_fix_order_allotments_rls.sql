-- Fix order_allotments RLS: add permissive policies so the app can read/write allotments
-- The app uses anon key (no auth.uid), so we use permissive policies for all operations

-- Drop existing policies if they exist (makes migration idempotent)
DROP POLICY IF EXISTS "allow_read_order_allotments" ON public.order_allotments;
DROP POLICY IF EXISTS "allow_insert_order_allotments" ON public.order_allotments;
DROP POLICY IF EXISTS "allow_update_order_allotments" ON public.order_allotments;

-- Allow all reads on order_allotments
CREATE POLICY "allow_read_order_allotments"
ON public.order_allotments
FOR SELECT
USING (true);

-- Allow all inserts on order_allotments
CREATE POLICY "allow_insert_order_allotments"
ON public.order_allotments
FOR INSERT
WITH CHECK (true);

-- Allow all updates on order_allotments
CREATE POLICY "allow_update_order_allotments"
ON public.order_allotments
FOR UPDATE
USING (true)
WITH CHECK (true);
