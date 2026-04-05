-- ============================================================
-- PATCH 001: Initial Schema
-- Run this first. Sets up profiles and partners tables.
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ────────────────────────────────────────────────────────────
-- PARTNERS
-- Developers who integrate chaild_auth into their apps.
-- Each partner gets a unique key passed to ChailAuth.initialize().
-- Revenue share is calculated per referral attribution.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS partners (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key                  TEXT UNIQUE NOT NULL,         -- e.g. 'partner_abc123'
  name                 TEXT NOT NULL,
  email                TEXT UNIQUE NOT NULL,
  app_name             TEXT,
  revenue_share_pct    NUMERIC(5,2) DEFAULT 20.00,   -- % of subscription revenue
  is_active            BOOLEAN DEFAULT TRUE,
  bank_account         JSONB,                         -- { bank_code, account_number, account_name }
  total_earned         NUMERIC(12,2) DEFAULT 0.00,
  total_paid_out       NUMERIC(12,2) DEFAULT 0.00,
  created_at           TIMESTAMPTZ DEFAULT NOW(),
  updated_at           TIMESTAMPTZ DEFAULT NOW()
);

-- Insert the internal Chaild partner (for first-party apps)
INSERT INTO partners (key, name, email, app_name, revenue_share_pct)
VALUES ('chaild_internal', 'Chaild Internal', 'internal@chaild.app', 'Chaild', 0.00)
ON CONFLICT (key) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- PROFILES
-- One row per Supabase auth user.
-- partner_key records WHICH developer's app they signed up through.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email        TEXT NOT NULL,
  name         TEXT,
  avatar_url   TEXT,
  partner_key  TEXT REFERENCES partners(key) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create profile on new user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE partners ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view and update own profile"
  ON profiles FOR ALL USING (auth.uid() = id);

CREATE POLICY "Partners are publicly readable by key"
  ON partners FOR SELECT USING (TRUE);
