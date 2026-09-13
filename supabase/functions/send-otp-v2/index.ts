const TWILIO_ACCOUNT_SID = Deno.env.get('TWILIO_ACCOUNT_SID');
const TWILIO_AUTH_TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN');
const TWILIO_PHONE_NUMBER = Deno.env.get('TWILIO_PHONE_NUMBER');
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': '*',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Validate required environment variables
    if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_PHONE_NUMBER) {
      console.error('Missing Twilio credentials. Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER as Supabase secrets.');
      return new Response(
        JSON.stringify({ error: 'SMS service not configured. Please contact support.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      console.error('Missing Supabase credentials.');
      return new Response(
        JSON.stringify({ error: 'Database service not configured. Please contact support.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { phone } = await req.json();

    if (!phone) {
      return new Response(
        JSON.stringify({ error: 'Missing required field: phone' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Validate phone format — must start with + and contain digits
    if (!/^\+\d{7,15}$/.test(phone)) {
      return new Response(
        JSON.stringify({ error: 'Invalid phone number format. Must be in E.164 format (e.g. +919876543210).' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Generate 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // 10 minutes

    // Delete any existing OTP for this phone
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

    // Store new OTP in Supabase
    const insertRes = await fetch(`${SUPABASE_URL}/rest/v1/otp_verifications`, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY!,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json',
        Prefer: 'return=minimal',
      },
      body: JSON.stringify({ phone, otp, expires_at: expiresAt }),
    });

    if (!insertRes.ok) {
      const err = await insertRes.text();
      console.error('Failed to store OTP:', err);
      return new Response(
        JSON.stringify({ error: 'Failed to store OTP. Please try again.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Send via Twilio
    const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`;
    const credentials = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);

    const formData = new URLSearchParams({
      To: phone,
      From: TWILIO_PHONE_NUMBER!,
      Body: `Your Concigo Desk OTP is: ${otp}. Valid for 10 minutes. Do not share this with anyone.`,
    });

    const response = await fetch(twilioUrl, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${credentials}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: formData,
    });

    const data = await response.json();

    if (!response.ok) {
      console.error('Twilio error:', JSON.stringify(data));
      // Twilio error codes: https://www.twilio.com/docs/api/errors
      let userMessage = 'Failed to send OTP via SMS.';
      if (data.code === 21211) userMessage = 'Invalid phone number. Please check and try again.';
      else if (data.code === 21608) userMessage = 'This phone number is not verified in Twilio trial account.';
      else if (data.code === 20003) userMessage = 'SMS service authentication failed. Please contact support.';
      else if (data.message) userMessage = `SMS error: ${data.message}`;

      return new Response(
        JSON.stringify({ error: userMessage, details: data.message, code: data.code }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('OTP sent to', phone, '- SID:', data.sid);
    return new Response(
      JSON.stringify({ success: true, messageSid: data.sid }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error. Please try again.' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
