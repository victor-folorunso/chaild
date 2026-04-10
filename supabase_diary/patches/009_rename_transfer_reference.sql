-- 009_rename_transfer_reference.sql
-- Renames flutterwave_reference to transfer_reference on payouts.
-- Adds payout_method enum and crypto_wallet JSONB to partners.
-- Run after 008_app_usage.sql.

-- ── payouts table ─────────────────────────────────────────────────────────────
alter table payouts
  rename column flutterwave_reference to transfer_reference;

-- ── partners table ────────────────────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_type where typname = 'payout_method'
  ) then
    create type payout_method as enum ('bank_transfer', 'crypto');
  end if;
end$$;

alter table partners
  add column if not exists payout_method payout_method not null default 'bank_transfer',
  add column if not exists crypto_wallet  jsonb;

comment on column partners.crypto_wallet is
  'JSON: { "address": "0x...", "network": "USDT-TRC20" }';
