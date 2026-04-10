// attribute-user/index.ts
// Validates the partner_key + bundle_id pair, then stamps the partner key
// on the user's profile. Replaces the client-side _setPartnerKey call.
//
// POST /functions/v1/attribute-user
// Headers: Authorization: Bearer <user JWT>
// Body: { partnerKey: string, bundleId: string }

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders() });
  }

  try {
    // ── Authenticate the calling user ───────────────────────────────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return error(401, 'Missing Authorization header');

    const userClient = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authErr } = await userClient.auth.getUser();
    if (authErr || !user) return error(401, 'Invalid or expired token');

    // ── Parse body ──────────────────────────────────────────────────────────
    const { partnerKey, bundleId } = await req.json();
    if (!partnerKey || !bundleId) return error(400, 'partnerKey and bundleId are required');

    // ── Validate partner_key + bundle_id pair ────────────────────────────────
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    const { data: app, error: appErr } = await adminClient
      .from('partner_apps')
      .select('partner_key, bundle_id')
      .eq('partner_key', partnerKey)
      .eq('bundle_id', bundleId)
      .maybeSingle();

    if (appErr) return error(500, appErr.message);
    if (!app) return error(403, 'Invalid partner_key / bundle_id combination');

    // ── Stamp partner key only if not already set ────────────────────────────
    const { data: profile } = await adminClient
      .from('profiles')
      .select('partner_key')
      .eq('id', user.id)
      .maybeSingle();

    if (profile && profile.partner_key == null) {
      await adminClient
        .from('profiles')
        .update({ partner_key: partnerKey })
        .eq('id', user.id);

      await adminClient
        .from('referrals')
        .insert({ partner_key: partnerKey, referred_user_id: user.id })
        .onConflict('referred_user_id')
        .ignoreDuplicates();
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders(), 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return error(500, String(e));
  }
});

function error(status: number, message: string) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders(), 'Content-Type': 'application/json' },
  });
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };
}
