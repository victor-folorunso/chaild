-- 006_id_verification.sql
-- Adds id_verified to profiles and requires_id_verification to partners.

-- Add id_verified flag to profiles (default false)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS id_verified boolean NOT NULL DEFAULT false;

-- Add requires_id_verification to partners so each app can declare its own requirement
ALTER TABLE partners
  ADD COLUMN IF NOT EXISTS requires_id_verification boolean NOT NULL DEFAULT false;

-- RLS: allow users to read their own id_verified status (already covered by existing profiles policy)
-- Partners table: allow the partner to read/update their own requires_id_verification
-- (covered by existing partners RLS if present; no new policy needed here)
