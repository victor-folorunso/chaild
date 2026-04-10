-- 007_bundle_id_enforcement.sql
-- Adds bundle_id column to partner_apps and enforces that user attribution
-- only occurs for the declared bundle ID of each partner app.
-- Run in Supabase SQL Editor after 006_id_verification.sql.

-- ── partner_apps table (create if not exists) ────────────────────────────────
create table if not exists partner_apps (
  id            uuid primary key default gen_random_uuid(),
  partner_key   text not null unique,
  bundle_id     text not null,
  app_name      text,
  created_at    timestamptz not null default now()
);

alter table partner_apps enable row level security;

-- Only the service role may read/write partner_apps
create policy "service role only" on partner_apps
  using (auth.role() = 'service_role');

-- ── Index for fast lookup by partner_key ─────────────────────────────────────
create index if not exists partner_apps_partner_key_idx on partner_apps (partner_key);
