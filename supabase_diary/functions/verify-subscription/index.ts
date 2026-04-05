// supabase/functions/verify-subscription/index.ts
// ─────────────────────────────────────────────────────────────────────────────
// Called by the Flutter app to verify subscription status.
// Checks both Supabase DB and RevenueCat for consistency.
// Returns: { isActive, plan, expiresAt, source }
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const REVENUECAT_API_KEY = Deno.env.get("REVENUECAT_API_KEY")!;
const REVENUECAT_ENTITLEMENT = Deno.env.get("REVENUECAT_ENTITLEMENT") ?? "pro";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

serve(async (req) => {
  if (req.method !== "GET") {
    return json({ error: "Method not allowed" }, 405);
  }

  // Auth header from Flutter SDK (Supabase JWT)
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Unauthorized" }, 401);

  const token = authHeader.replace("Bearer ", "");
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  if (authError || !user) return json({ error: "Invalid token" }, 401);

  const userId = user.id;

  // ── Check Supabase subscription table ────────────────────────────────────
  const { data: sub } = await supabase
    .from("subscriptions")
    .select("*")
    .eq("user_id", userId)
    .eq("status", "active")
    .maybeSingle();

  const dbActive = sub && new Date(sub.expires_at) > new Date();

  // ── Cross-check with RevenueCat ───────────────────────────────────────────
  const rcRes = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${userId}`,
    {
      headers: {
        "Authorization": `Bearer ${REVENUECAT_API_KEY}`,
        "X-Platform": "android",
      },
    }
  );

  let rcActive = false;
  let rcExpiresAt: string | null = null;

  if (rcRes.ok) {
    const rcData = await rcRes.json();
    const entitlement = rcData?.subscriber?.entitlements?.[REVENUECAT_ENTITLEMENT];
    if (entitlement?.expires_date) {
      rcActive = new Date(entitlement.expires_date) > new Date();
      rcExpiresAt = entitlement.expires_date;
    }
  }

  const isActive = dbActive || rcActive;

  return json({
    isActive,
    plan: sub?.plan ?? null,
    expiresAt: sub?.expires_at ?? rcExpiresAt,
    source: dbActive ? "supabase" : rcActive ? "revenuecat" : "none",
  });
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
