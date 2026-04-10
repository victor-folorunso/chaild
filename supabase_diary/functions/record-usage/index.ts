// record-usage/index.ts
// Receives usage heartbeats from the Chaild SDK and upserts app_usage rows.
//
// POST /functions/v1/record-usage
// Headers: Authorization: Bearer <user JWT>
// Body: { partnerKey: string, secondsUsed: number }

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders() });
  }

  try {
    // ── Authenticate calling user ────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return error(401, 'Missing Authorization header');

    const userClient = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authErr } = await userClient.auth.getUser();
    if (authErr || !user) return error(401, 'Invalid or expired token');

    // ── Parse body ───────────────────────────────────────────────────────────
    const { partnerKey, secondsUsed } = await req.json();
    if (!partnerKey || typeof secondsUsed !== 'number' || secondsUsed <= 0) {
      return error(400, 'partnerKey and secondsUsed (>0) are required');
    }

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // ── Validate partnerKey exists ───────────────────────────────────────────
    const { data: partner } = await adminClient
      .from('partners')
      .select('key')
      .eq('key', partnerKey)
      .maybeSingle();
    if (!partner) return error(403, 'Unknown partner_key');

    // ── Determine referral weight for this user+partner ──────────────────────
    const { data: referral } = await adminClient
      .from('referrals')
      .select('partner_key')
      .eq('referred_user_id', user.id)
      .eq('partner_key', partnerKey)
      .maybeSingle();
    const weight = referral ? 2 : 1;
    const weightedSeconds = secondsUsed * weight;

    // ── Upsert into app_usage ────────────────────────────────────────────────
    const month = new Date().toISOString().slice(0, 7); // YYYY-MM

    const { error: upsertErr } = await adminClient.rpc('increment_app_usage', {
      p_user_id: user.id,
      p_partner_key: partnerKey,
      p_month: month,
      p_seconds: secondsUsed,
      p_weighted: weightedSeconds,
    });

    if (upsertErr) return error(500, upsertErr.message);

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
