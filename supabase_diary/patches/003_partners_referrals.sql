-- ============================================================
-- PATCH 003: Referrals & Partner Attribution
-- Tracks which partner referred which user,
-- and calculates revenue earned per partner.
-- ============================================================

CREATE TYPE referral_status AS ENUM ('signed_up', 'converted', 'churned');

CREATE TABLE IF NOT EXISTS referrals (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_key      TEXT NOT NULL REFERENCES partners(key),
  referred_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status           referral_status NOT NULL DEFAULT 'signed_up',
  converted_at     TIMESTAMPTZ,    -- when they first paid
  churned_at       TIMESTAMPTZ,    -- when they cancelled
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS one_referral_per_user
  ON referrals(referred_user_id);

-- ────────────────────────────────────────────────────────────
-- PARTNER EARNINGS
-- Each payment event logs how much the partner earned.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS partner_earnings (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_key      TEXT NOT NULL REFERENCES partners(key),
  user_id          UUID NOT NULL REFERENCES profiles(id),
  subscription_id  UUID NOT NULL REFERENCES subscriptions(id),
  gross_amount_ngn NUMERIC(12,2) NOT NULL,
  share_pct        NUMERIC(5,2) NOT NULL,
  earned_ngn       NUMERIC(12,2) NOT NULL,
  payout_id        UUID,           -- set when paid out (FK added in patch 004)
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- When a payment is made, auto-create partner earning record
CREATE OR REPLACE FUNCTION record_partner_earning()
RETURNS TRIGGER AS $$
DECLARE
  v_partner_key TEXT;
  v_share_pct   NUMERIC;
  v_earned      NUMERIC;
BEGIN
  -- Only fire when subscription becomes active
  IF NEW.status = 'active' AND OLD.status != 'active' THEN
    -- Get partner key from user's profile
    SELECT partner_key INTO v_partner_key
    FROM profiles WHERE id = NEW.user_id;

    IF v_partner_key IS NOT NULL AND v_partner_key != 'chaild_internal' THEN
      -- Get partner's revenue share
      SELECT revenue_share_pct INTO v_share_pct
      FROM partners WHERE key = v_partner_key;

      v_earned := (NEW.amount_ngn * v_share_pct / 100);

      INSERT INTO partner_earnings
        (partner_key, user_id, subscription_id, gross_amount_ngn, share_pct, earned_ngn)
      VALUES
        (v_partner_key, NEW.user_id, NEW.id, NEW.amount_ngn, v_share_pct, v_earned);

      -- Update partner total
      UPDATE partners
      SET total_earned = total_earned + v_earned,
          updated_at = NOW()
      WHERE key = v_partner_key;

      -- Update referral status
      UPDATE referrals
      SET status = 'converted', converted_at = NOW()
      WHERE referred_user_id = NEW.user_id AND status = 'signed_up';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_subscription_activated ON subscriptions;
CREATE TRIGGER on_subscription_activated
  AFTER UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION record_partner_earning();

-- RLS
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_earnings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access on referrals"
  ON referrals FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on earnings"
  ON partner_earnings FOR ALL USING (auth.role() = 'service_role');
