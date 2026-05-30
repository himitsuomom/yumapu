-- NOTE: This migration documents the required changes to get_facilities_in_bounds RPC
-- The RPC should return ALL facility fields including phone, website, hours, price, etc.
-- Current issue: RPC only returns basic fields (id, name, lat, lng, facility_type)
--
-- If you have access to the Supabase dashboard, update the RPC to include:
-- phone TEXT, website TEXT, hours TEXT, price INT,
-- business_hours JSONB, price_info JSONB,
-- name_kana VARCHAR, prefecture_id UUID,
-- google_place_id TEXT, data_source VARCHAR
--
-- Primary fix: cache merge logic in facility_service.dart and
-- supabase_facility_repository.dart prevents incomplete RPC rows
-- from overwriting fully-fetched facility detail data in the local cache.

-- Migration placeholder
SELECT 1;
