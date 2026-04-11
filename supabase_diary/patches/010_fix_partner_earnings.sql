-- 010_fix_partner_earnings.sql
-- Adds missing columns to partner_earnings that patch 008 failed to create
-- (because the table already existed from patch 003).
-- Also adds the unique index on (partner_key, user_id, month) that
-- distribute-revenue relies on for upsert conflict resolution.

ALTER TABLE partner_earnings
  ADD COLUMN IF NOT EXISTS month       TEXT,
  ADD COLUMN IF NOT EXISTS amount_usd  NUMERIC(12, 4);

CREATE UNIQUE INDEX IF NOT EXISTS partner_earnings_pk_user_month
  ON partner_earnings (partner_key, user_id, month);
