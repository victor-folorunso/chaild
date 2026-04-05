-- ============================================================
-- PATCH 002: Subscriptions
-- Tracks every user's subscription lifecycle.
-- RevenueCat is the source of truth; this is our mirror.
-- ============================================================

CREATE TYPE subscription_status AS ENUM ('none', 'active', 'expired', 'cancelled', 'grace_period');
CREATE TYPE subscription_plan AS ENUM ('monthly', 'yearly');

CREATE TABLE IF NOT EXISTS subscriptions (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status                  subscription_status NOT NULL DEFAULT 'none',
  plan                    subscription_plan,
  amount_ngn              NUMERIC(12,2),               -- what user paid in NGN
  revenuecat_customer_id  TEXT,                        -- RevenueCat subscriber ID
  revenuecat_entitlement  TEXT DEFAULT 'pro',          -- entitlement identifier in RC
  flutterwave_ref         TEXT,                        -- Flutterwave transaction reference
  flutterwave_tx_id       TEXT,                        -- Flutterwave transaction ID
  starts_at               TIMESTAMPTZ,
  expires_at              TIMESTAMPTZ,
  cancelled_at            TIMESTAMPTZ,
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  updated_at              TIMESTAMPTZ DEFAULT NOW()
);

-- Only one active subscription per user at a time
CREATE UNIQUE INDEX IF NOT EXISTS one_active_sub_per_user
  ON subscriptions(user_id)
  WHERE status = 'active';

-- Helper: check if user has active subscription
CREATE OR REPLACE FUNCTION is_subscribed(p_user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM subscriptions
    WHERE user_id = p_user_id
      AND status = 'active'
      AND (expires_at IS NULL OR expires_at > NOW())
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- RLS
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own subscription"
  ON subscriptions FOR SELECT USING (auth.uid() = user_id);

-- Service role can do everything (used by edge functions)
CREATE POLICY "Service role full access"
  ON subscriptions FOR ALL USING (auth.role() = 'service_role');
