const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': '*',
};

// Shared OTP store — NOTE: In production use a database/Redis for persistence across instances
// For Supabase edge functions, use a Supabase table for OTP storage
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { phone, otp } = await req.json();

    if (!phone || !otp) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: phone, otp' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Fetch OTP record from Supabase otp_verifications table
    const fetchRes = await fetch(
      `${SUPABASE_URL}/rest/v1/otp_verifications?phone=eq.${encodeURIComponent(phone)}&order=created_at.desc&limit=1`,
      {
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY!,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
        },
      }
    );

    const records = await fetchRes.json();

    if (!records || records.length === 0) {
      return new Response(
        JSON.stringify({ success: false, error: 'No OTP found for this number. Please request a new OTP.' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const record = records[0];
    const now = new Date().toISOString();

    if (record.expires_at < now) {
      return new Response(
        JSON.stringify({ success: false, error: 'OTP has expired. Please request a new one.' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (record.otp !== otp) {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid OTP. Please check and try again.' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Delete used OTP
    await fetch(
      `${SUPABASE_URL}/rest/v1/otp_verifications?phone=eq.${encodeURIComponent(phone)}`,
      {
        method: 'DELETE',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY!,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
      }
    );

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
