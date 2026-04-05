// supabase/functions/process-payout/index.ts
// ─────────────────────────────────────────────────────────────────────────────
// Triggered manually or on a schedule (pg_cron).
// Finds partners with unpaid earnings and initiates Flutterwave bank transfers.
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FW_SECRET_KEY = Deno.env.get("FLUTTERWAVE_SECRET_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MIN_PAYOUT_NGN = 5000; // minimum payout threshold

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

serve(async (req) => {
  // Simple secret check for manual triggers
  const secret = req.headers.get("x-chaild-secret");
  if (secret !== Deno.env.get("CRON_SECRET")) {
    return new Response("Unauthorized", { status: 401 });
  }

  // Find partners with outstanding unpaid earnings above threshold
  const { data: partners, error } = await supabase
    .from("partners")
    .select("id, key, name, email, bank_account, total_earned, total_paid_out")
    .filter("is_active", "eq", true)
    .not("bank_account", "is", null);

  if (error) return new Response("DB error", { status: 500 });

  const results = [];

  for (const partner of (partners ?? [])) {
    const unpaid = partner.total_earned - partner.total_paid_out;
    if (unpaid < MIN_PAYOUT_NGN) continue;

    const bank = partner.bank_account as {
      bank_code: string;
      account_number: string;
      account_name: string;
    };

    // Create payout record
    const { data: payout, error: payoutError } = await supabase
      .from("payouts")
      .insert({
        partner_id: partner.id,
        amount_ngn: unpaid,
        status: "processing",
      })
      .select()
      .single();

    if (payoutError || !payout) continue;

    // Initiate Flutterwave transfer
    const fwRes = await fetch("https://api.flutterwave.com/v3/transfers", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${FW_SECRET_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        account_bank: bank.bank_code,
        account_number: bank.account_number,
        amount: unpaid,
        narration: `Chaild partner payout - ${partner.name}`,
        currency: "NGN",
        reference: `payout_${payout.id}`,
        callback_url: `${SUPABASE_URL}/functions/v1/payout-webhook`,
        debit_currency: "NGN",
      }),
    });

    const fwData = await fwRes.json();

    if (fwData.status === "success") {
      await supabase
        .from("payouts")
        .update({
          flutterwave_transfer_id: String(fwData.data.id),
          flutterwave_reference: fwData.data.reference,
        })
        .eq("id", payout.id);

      results.push({ partner: partner.name, amount: unpaid, status: "initiated" });
    } else {
      await supabase
        .from("payouts")
        .update({ status: "failed", failure_reason: fwData.message })
        .eq("id", payout.id);

      results.push({ partner: partner.name, amount: unpaid, status: "failed", reason: fwData.message });
    }
  }

  return new Response(JSON.stringify({ processed: results }), {
    headers: { "Content-Type": "application/json" },
  });
});
