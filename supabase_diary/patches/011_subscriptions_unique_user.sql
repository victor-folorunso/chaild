-- 011_subscriptions_unique_user.sql
-- Adds a plain (non-partial) unique index on subscriptions(user_id) so that
-- payment_service.dart's upsert onConflict: 'user_id' resolves correctly.
-- The existing partial index (WHERE status = 'active') is ignored by Postgres
-- for upsert conflict resolution, causing duplicate rows.

CREATE UNIQUE INDEX IF NOT EXISTS subscriptions_user_id_idx
  ON subscriptions (user_id);
