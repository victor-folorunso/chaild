-- 012_fix_partner_apps_unique.sql
-- Fixes the UNIQUE constraint on partner_apps so a partner can register
-- multiple bundle IDs (one per app). The original schema had UNIQUE on
-- partner_key alone, which blocks a partner from having more than one app.
-- Correct uniqueness is (partner_key, bundle_id).

-- Drop the implicit unique constraint created by the `unique` keyword on
-- the partner_key column definition in patch 007.
ALTER TABLE partner_apps
  DROP CONSTRAINT IF EXISTS partner_apps_partner_key_key;

-- Add the correct composite unique constraint.
ALTER TABLE partner_apps
  ADD CONSTRAINT partner_apps_partner_key_bundle_id_key
    UNIQUE (partner_key, bundle_id);
