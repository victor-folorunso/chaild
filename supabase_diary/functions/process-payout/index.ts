// supabase/functions/process-payout/index.ts
// ─────────────────────────────────────────────────────────────────────────────
// Triggered manually or on a schedule (pg_cron).
// Finds partners with unpaid earnings and initiates payouts.
// Supports two payout methods: bank_transfer (Flutterwave) and crypto.
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FW_SECRET_KEY = Deno.env.get("FLUTTERWAVE_SECRET_KEY")!;
const CRYPTO_API_KEY = Deno.env.get("CRYPTO_PAYOUT_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MIN_PAYOUT_NGN = 25_000; // ≈ $15 USD — earnings are stored in NGN

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

serve(async (req) => {
  const secret = req.headers.get("x-chaild-secret");
  if (secret !== Deno.env.get("CRON_SECRET")) {
    return new Response("Unauthorized", { status: 401 });
  }

  // Find all active partners with outstanding unpaid balance above threshold
  const { data: partners, error } = await supabase
    .from("partners")
    .select("id, key, name, email, bank_account, crypto_wallet, payout_method, total_earned, total_paid_out")
    .filter("is_active", "eq", true);

  if (error) return new Response("DB error", { status: 500 });

  const results = [];

  for (const partner of (partners ?? [])) {
    const unpaid = (partner.total_earned ?? 0) - (partner.total_paid_out ?? 0);
    if (unpaid < MIN_PAYOUT_NGN) continue;

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

    if (partner.payout_method === "crypto") {
      await processCryptoPayout(partner, payout, unpaid, results);
    } else {
      await processBankTransfer(partner, payout, unpaid, results);
    }
  }

  return new Response(JSON.stringify({ processed: results }), {
    headers: { "Content-Type": "application/json" },
  });
});

// ── Bank transfer via Flutterwave ─────────────────────────────────────────────

async function processBankTransfer(partner: any, payout: any, unpaid: number, results: any[]) {
  if (!partner.bank_account) {
    await supabase.from("payouts")
      .update({ status: "failed", failure_reason: "No bank account on file" })
      .eq("id", payout.id);
    results.push({ partner: partner.name, status: "failed", reason: "no bank account" });
    return;
  }

  const bank = partner.bank_account as {
    bank_code: string; account_number: string; account_name: string;
  };

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
      callback_url: `${Deno.env.get("SUPABASE_URL")}/functions/v1/payout-webhook`,
      debit_currency: "NGN",
    }),
  });

  const fwData = await fwRes.json();

  if (fwData.status === "success") {
    await supabase.from("payouts").update({
      flutterwave_transfer_id: String(fwData.data.id),
      transfer_reference: fwData.data.reference,
    }).eq("id", payout.id);
    results.push({ partner: partner.name, amount: unpaid, status: "initiated", method: "bank_transfer" });
  } else {
    await supabase.from("payouts")
      .update({ status: "failed", failure_reason: fwData.message })
      .eq("id", payout.id);
    results.push({ partner: partner.name, amount: unpaid, status: "failed", reason: fwData.message });
  }
}

// ── Crypto payout ─────────────────────────────────────────────────────────────
// Uses a generic crypto transfer API (configurable via CRYPTO_PAYOUT_API_KEY).
// The implementation here targets Binance Pay / manual USDT transfer pattern.
// Replace the API call body with your chosen provider's schema.

async function processCryptoPayout(partner: any, payout: any, unpaid: number, results: any[]) {
  if (!partner.crypto_wallet?.address || !partner.crypto_wallet?.network) {
    await supabase.from("payouts")
      .update({ status: "failed", failure_reason: "No crypto wallet on file" })
      .eq("id", payout.id);
    results.push({ partner: partner.name, status: "failed", reason: "no crypto wallet" });
    return;
  }

  const { address, network } = partner.crypto_wallet as { address: string; network: string };
  const reference = `crypto_payout_${payout.id}`;

  try {
    // Generic crypto transfer — replace body with your provider's API schema
    const res = await fetch("https://api.crypto-provider.example.com/v1/transfer", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${CRYPTO_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        to_address: address,
        network,
        amount_ngn: unpaid,  // earnings are accumulated in NGN
        reference,
        note: `Chaild partner payout - ${partner.name}`,
      }),
    });

    const data = await res.json();

    if (res.ok && data.tx_hash) {
      await supabase.from("payouts").update({
        transfer_reference: data.tx_hash ?? reference,
        status: "processing",
      }).eq("id", payout.id);
      results.push({ partner: partner.name, amount: unpaid, status: "initiated", method: "crypto", network });
    } else {
      await supabase.from("payouts")
        .update({ status: "failed", failure_reason: data.message ?? "Crypto transfer failed" })
        .eq("id", payout.id);
      results.push({ partner: partner.name, status: "failed", reason: data.message });
    }
  } catch (e) {
    await supabase.from("payouts")
      .update({ status: "failed", failure_reason: String(e) })
      .eq("id", payout.id);
    results.push({ partner: partner.name, status: "failed", reason: String(e) });
  }
}
