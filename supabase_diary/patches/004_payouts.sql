-- ============================================================
-- PATCH 004: Payouts
-- Tracks bank transfer payouts to partners via Flutterwave.
-- ============================================================

CREATE TYPE payout_status AS ENUM ('pending', 'processing', 'completed', 'failed');

CREATE TABLE IF NOT EXISTS payouts (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id             UUID NOT NULL REFERENCES partners(id),
  amount_ngn             NUMERIC(12,2) NOT NULL,
  status                 payout_status NOT NULL DEFAULT 'pending',
  flutterwave_transfer_id TEXT,
  flutterwave_reference  TEXT,
  failure_reason         TEXT,
  initiated_at           TIMESTAMPTZ DEFAULT NOW(),
  completed_at           TIMESTAMPTZ,
  created_at             TIMESTAMPTZ DEFAULT NOW()
);

-- Back-reference: link earnings to payout once paid
ALTER TABLE partner_earnings
  ADD CONSTRAINT fk_payout
  FOREIGN KEY (payout_id) REFERENCES payouts(id) ON DELETE SET NULL;

-- When a payout completes, update partner paid_out total
CREATE OR REPLACE FUNCTION handle_payout_completed()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    UPDATE partners
    SET total_paid_out = total_paid_out + NEW.amount_ngn,
        updated_at = NOW()
    WHERE id = NEW.partner_id;

    -- Mark all earnings in this payout as settled
    UPDATE partner_earnings
    SET payout_id = NEW.id
    WHERE payout_id IS NULL
      AND partner_key = (SELECT key FROM partners WHERE id = NEW.partner_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_payout_completed ON payouts;
CREATE TRIGGER on_payout_completed
  AFTER UPDATE ON payouts
  FOR EACH ROW EXECUTE FUNCTION handle_payout_completed();

-- RLS
ALTER TABLE payouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access on payouts"
  ON payouts FOR ALL USING (auth.role() = 'service_role');
