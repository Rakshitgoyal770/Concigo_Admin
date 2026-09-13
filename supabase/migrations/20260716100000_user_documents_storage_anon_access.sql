-- Migration: Allow anon role to read/download from user-documents storage bucket
-- This enables the reception employee (using anon key) to view and download
-- co-guest ID documents stored in the user-documents private bucket.
-- The reception session uses the Supabase anon key, so storage policies
-- must explicitly grant SELECT (object read) and signed URL creation to anon.

-- Allow anon to SELECT (list/read) objects in user-documents bucket
DROP POLICY IF EXISTS "anon_read_user_documents" ON storage.objects;
CREATE POLICY "anon_read_user_documents"
ON storage.objects
FOR SELECT
TO anon
USING (bucket_id = 'user-documents');

-- Allow anon to INSERT (needed for createSignedUrl RPC path in some Supabase versions)
-- This is NOT needed for signed URL creation — only SELECT is needed.
-- Signed URL creation is a storage API call that requires SELECT on the object.
