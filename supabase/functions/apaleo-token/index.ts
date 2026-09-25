import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const TOKEN_URL = 'https://identity.apaleo.com/connect/token';
const CLIENT_ID = 'ZIKG-AC-CONCIGOAPP';
const CLIENT_SECRET = 'n4cUcFMBSBLpmDge3YzeDW4FqGzBBo';
const REDIRECT_URI = 'https://oauth.pstmn.io/v1/vscode-callback';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { action, code, refresh_token } = await req.json();

    let bodyParams: Record<string, string>;

    if (action === 'exchange') {
      if (!code) {
        return new Response(
          JSON.stringify({ error: 'Missing authorization code' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      bodyParams = {
        grant_type: 'authorization_code',
        client_id: CLIENT_ID,
        client_secret: CLIENT_SECRET,
        redirect_uri: REDIRECT_URI,
        code: code,
      };
    } else if (action === 'refresh') {
      if (!refresh_token) {
        return new Response(
          JSON.stringify({ error: 'Missing refresh token' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      bodyParams = {
        grant_type: 'refresh_token',
        client_id: CLIENT_ID,
        client_secret: CLIENT_SECRET,
        refresh_token: refresh_token,
      };
    } else {
      return new Response(
        JSON.stringify({ error: 'Invalid action. Expected "exchange" or "refresh"' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const formBody = Object.entries(bodyParams)
      .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
      .join('&');

    const apaleoResp = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: formBody,
    });

    const data = await apaleoResp.json();

    return new Response(JSON.stringify(data), {
      status: apaleoResp.status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || 'Internal proxy error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
