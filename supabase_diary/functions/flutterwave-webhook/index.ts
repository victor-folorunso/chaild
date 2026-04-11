// supabase/functions/flutterwave-webhook/index.ts
// ─────────────────────────────────────────────────────────────────────────────
// Receives Flutterwave payment webhooks.
// On successful payment:
//   1. Verifies webhook signature
//   2. Looks up user by flutterwave_ref stored during checkout initiation
//   3. Grants RevenueCat entitlement via REST API
//   4. Updates Supabase subscription table
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FLUTTERWAVE_SECRET_HASH = Deno.env.get("FLUTTERWAVE_SECRET_HASH")!;
const REVENUECAT_API_KEY = Deno.env.get("REVENUECAT_API_KEY")!;       // RC secret key
const REVENUECAT_ENTITLEMENT = Deno.env.get("REVENUECAT_ENTITLEMENT") ?? "pro";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Plan durations in days
const PLAN_DURATION: Record<string, number> = {
  monthly: 30,
  yearly: 365,
};

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const body = await req.text();

  // ── 1. Verify Flutterwave signature ──────────────────────────────────────
  const signature = req.headers.get("verif-hash");
  if (!signature || signature !== FLUTTERWAVE_SECRET_HASH) {
    console.error("Invalid webhook signature");
    return new Response("Unauthorized", { status: 401 });
  }

  const event = JSON.parse(body);

  // Only handle successful charges
  if (event.event !== "charge.completed" || event.data?.status !== "successful") {
    return new Response("Ignored", { status: 200 });
  }

  const tx = event.data;
  const flutterwaveRef = tx.tx_ref as string;       // set during checkout init
  const flutterwaveTxId = String(tx.id);
  const amountNgn = tx.amount as number;
  const plan = tx.meta?.plan as string ?? "monthly"; // passed in tx_ref metadata

  console.log(`Processing payment: ${flutterwaveRef}, amount: ${amountNgn}`);

  // ── 2. Find user by flutterwave reference ──────────────────────────────────
  // tx_ref format: chaild_{userId}_{timestamp}
  const userId = flutterwaveRef.split("_")[1];
  if (!userId) {
    console.error("Could not extract user ID from tx_ref:", flutterwaveRef);
    return new Response("Bad reference", { status: 400 });
  }

  // ── 3. Grant RevenueCat entitlement ───────────────────────────────────────
  const durationDays = PLAN_DURATION[plan] ?? 30;
  const expiresAt = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000);

  const rcResponse = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${userId}/entitlements/${REVENUECAT_ENTITLEMENT}/promotional`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${REVENUECAT_API_KEY}`,
        "Content-Type": "application/json",
        "X-Platform": "android", // RC needs a platform
      },
      body: JSON.stringify({
        duration: plan === "yearly" ? "annual" : "monthly",
        end_time_ms: expiresAt.getTime(),
      }),
    }
  );

  if (!rcResponse.ok) {
    const err = await rcResponse.text();
    console.error("RevenueCat error:", err);
    return new Response("RevenueCat grant failed", { status: 500 });
  }

  console.log(`RevenueCat entitlement granted for user ${userId}`);

  // ── 4. Upsert Supabase subscription ───────────────────────────────────────
  const startsAt = new Date().toISOString();

  const { error: subError } = await supabase
    .from("subscriptions")
    .upsert(
      {
        user_id: userId,
        status: "active",
        plan,
        amount_ngn: amountNgn,
        revenuecat_customer_id: userId,
        revenuecat_entitlement: REVENUECAT_ENTITLEMENT,
        flutterwave_ref: flutterwaveRef,
        flutterwave_tx_id: flutterwaveTxId,
        starts_at: startsAt,
        expires_at: expiresAt.toISOString(),
        updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id" }
    );

  if (subError) {
    console.error("Supabase upsert error:", subError);
    return new Response("DB update failed", { status: 500 });
  }

  console.log(`Subscription activated for user ${userId} until ${expiresAt}`);
  return new Response("OK", { status: 200 });
});
