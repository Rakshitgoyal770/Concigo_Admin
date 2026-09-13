-- Migration: Add OTP verifications table for Twilio OTP flow
-- This table stores temporary OTP codes for phone verification

CREATE TABLE IF NOT EXISTS public.otp_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT NOT NULL,
  otp TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_otp_verifications_phone ON public.otp_verifications(phone);

ALTER TABLE public.otp_verifications ENABLE ROW LEVEL SECURITY;

-- Allow service role (edge functions) full access
DROP POLICY IF EXISTS "service_role_manage_otp" ON public.otp_verifications;
CREATE POLICY "service_role_manage_otp"
ON public.otp_verifications
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Allow anon to insert/select (edge functions use anon key from client)
DROP POLICY IF EXISTS "anon_manage_otp" ON public.otp_verifications;
CREATE POLICY "anon_manage_otp"
ON public.otp_verifications
FOR ALL
TO anon
USING (true)
WITH CHECK (true);
