// distribute-revenue/index.ts
// Monthly cron job: distributes 70% of each user's subscription to partners
// proportionally by weighted usage time.
//
// Triggered on the 1st of each month via Supabase pg_cron.
// Can also be called manually by the service role for testing.
//
// POST /functions/v1/distribute-revenue
// Headers: Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>
// Body: { month: "YYYY-MM" }  (optional — defaults to previous month)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const PARTNER_SHARE = 0.70;

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders() });
  }

  try {
    // ── Only service role may call this ──────────────────────────────────────
    const authHeader = req.headers.get('Authorization') ?? '';
    if (!authHeader.includes(SUPABASE_SERVICE_KEY)) {
      return error(401, 'Service role key required');
    }

    const body = req.method === 'POST' ? await req.json().catch(() => ({})) : {};
    const month = body.month ?? previousMonth();

    const db = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // ── Load subscriptions that renewed in the target month ──────────────────
    const { data: subscriptions, error: subErr } = await db
      .from('subscriptions')
      .select('user_id, amount_ngn')
      .gte('starts_at', `${month}-01`)
      .lt('starts_at', nextMonthStart(month));

    if (subErr) return error(500, subErr.message);
    if (!subscriptions || subscriptions.length === 0) {
      return json({ ok: true, processed: 0 });
    }

    let processed = 0;

    for (const sub of subscriptions) {
      const { user_id, amount_ngn } = sub;

      // ── Get all usage rows for this user in this month ──────────────────────
      const { data: usageRows } = await db
        .from('app_usage')
        .select('partner_key, weighted_seconds')
        .eq('user_id', user_id)
        .eq('month', month);

      if (!usageRows || usageRows.length === 0) continue;

      const totalWeighted = usageRows.reduce(
        (sum: number, r: { weighted_seconds: number }) => sum + r.weighted_seconds, 0
      );
      if (totalWeighted === 0) continue;

      const partnerPool = amount_ngn * PARTNER_SHARE;

      for (const row of usageRows) {
        const share = (row.weighted_seconds / totalWeighted) * partnerPool;
        if (share <= 0) continue;

        // ── Upsert partner_earnings ─────────────────────────────────────────
        await db.from('partner_earnings').upsert({
          partner_key: row.partner_key,
          user_id,
          month,
          amount_usd: share,
        }, { onConflict: 'partner_key,user_id,month' });

        // ── Increment partners.total_earned ─────────────────────────────────
        await db.rpc('increment_partner_earned', {
          p_partner_key: row.partner_key,
          p_amount: share,
        });
      }

      processed++;
    }

    return json({ ok: true, processed });
  } catch (e) {
    return error(500, String(e));
  }
});

function previousMonth(): string {
  const d = new Date();
  d.setMonth(d.getMonth() - 1);
  return d.toISOString().slice(0, 7);
}

function nextMonthStart(month: string): string {
  const [y, m] = month.split('-').map(Number);
  const next = new Date(y, m, 1); // month is 0-indexed so m (1-indexed) = next month
  return next.toISOString().slice(0, 10);
}

function json(body: object) {
  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders(), 'Content-Type': 'application/json' },
  });
}

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
