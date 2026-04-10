-- 008_app_usage.sql
-- Creates app_usage table for time-weighted revenue split calculations.
-- Run after 007_bundle_id_enforcement.sql.

create table if not exists app_usage (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  partner_key      text not null,
  month            text not null,  -- format: YYYY-MM
  seconds_used     bigint not null default 0,
  weighted_seconds bigint not null default 0,
  updated_at       timestamptz not null default now()
);

-- Unique index used by upsert in record-usage edge function
create unique index if not exists app_usage_user_partner_month_idx
  on app_usage (user_id, partner_key, month);

-- Fast lookup by partner for distribute-revenue
create index if not exists app_usage_partner_month_idx
  on app_usage (partner_key, month);

alter table app_usage enable row level security;

-- Users can read their own usage; service role writes
create policy "users read own usage" on app_usage
  for select using (auth.uid() = user_id);

create policy "service role full access" on app_usage
  using (auth.role() = 'service_role');

-- partner_earnings: one row per partner per user per month
create table if not exists partner_earnings (
  id              uuid primary key default gen_random_uuid(),
  partner_key     text not null,
  user_id         uuid not null references auth.users(id) on delete cascade,
  month           text not null,
  amount_usd      numeric(10, 4) not null default 0,
  created_at      timestamptz not null default now()
);

create unique index if not exists partner_earnings_partner_user_month_idx
  on partner_earnings (partner_key, user_id, month);

alter table partner_earnings enable row level security;

create policy "service role full access earnings" on partner_earnings
  using (auth.role() = 'service_role');

-- increment_app_usage RPC: atomically increments seconds on upsert
-- Called by the record-usage edge function.
create or replace function increment_app_usage(
  p_user_id     uuid,
  p_partner_key text,
  p_month       text,
  p_seconds     bigint,
  p_weighted    bigint
) returns void
language plpgsql
security definer
as $$
begin
  insert into app_usage (user_id, partner_key, month, seconds_used, weighted_seconds, updated_at)
  values (p_user_id, p_partner_key, p_month, p_seconds, p_weighted, now())
  on conflict (user_id, partner_key, month)
  do update set
    seconds_used     = app_usage.seconds_used + excluded.seconds_used,
    weighted_seconds = app_usage.weighted_seconds + excluded.weighted_seconds,
    updated_at       = now();
end;
$$;

-- increment_partner_earned RPC: atomically adds to partners.total_earned
create or replace function increment_partner_earned(
  p_partner_key text,
  p_amount      numeric
) returns void
language plpgsql
security definer
as $$
begin
  update partners
  set total_earned = coalesce(total_earned, 0) + p_amount
  where key = p_partner_key;
end;
$$;
