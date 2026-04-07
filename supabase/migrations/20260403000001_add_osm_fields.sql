-- ============================================================
-- 施設データ拡充のための追加マイグレーション
-- ・OSM ID カラム追加（重複防止用）
-- ・lat/lng 直接カラム追加（Flutterアプリが直接読み書きするため）
-- ・type, price 等の簡易カラム追加（Flutter モデルとの互換性）
-- ・lat/lng から PostGIS location を自動生成するトリガー
-- ============================================================

-- 1. lat/lng 直接カラム（Flutterアプリが .gte('latitude',...) でフィルタするため必要）
ALTER TABLE facilities
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- 2. OSM ID（重複防止用。OSM由来のレコードのみセットする）
ALTER TABLE facilities
  ADD COLUMN IF NOT EXISTS osm_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_facilities_osm_id
  ON facilities (osm_id) WHERE osm_id IS NOT NULL;

-- 3. Flutter モデルが直接読み込む簡易カラム群
--    （初期スキーマで facility_type_id FK を使う設計だったが、
--      Flutter モデルは type VARCHAR を直接読んでいるため追加）
ALTER TABLE facilities
  ADD COLUMN IF NOT EXISTS type         VARCHAR(50)        DEFAULT 'public_bath',
  ADD COLUMN IF NOT EXISTS price        INTEGER            DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating       DOUBLE PRECISION   DEFAULT 0,
  ADD COLUMN IF NOT EXISTS review_count INTEGER            DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_open      BOOLEAN            DEFAULT true,
  ADD COLUMN IF NOT EXISTS hours        TEXT               DEFAULT '',
  ADD COLUMN IF NOT EXISTS holiday      TEXT               DEFAULT '',
  ADD COLUMN IF NOT EXISTS amenities    JSONB              DEFAULT '{}';

-- 4. location カラムの NOT NULL 制約を解除
--    （lat/lng から後続トリガーで自動生成するため、INSERT時に渡さなくてよくする）
ALTER TABLE facilities
  ALTER COLUMN location DROP NOT NULL;

-- 5. lat/lng → PostGIS location を自動同期するトリガー
CREATE OR REPLACE FUNCTION sync_facility_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.location = ST_SetSRID(
      ST_MakePoint(NEW.longitude, NEW.latitude),
      4326
    )::geography;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_facility_location ON facilities;
CREATE TRIGGER trg_sync_facility_location
  BEFORE INSERT OR UPDATE ON facilities
  FOR EACH ROW EXECUTE FUNCTION sync_facility_location();

-- 6. lat/lng に空間インデックス（ビューポートクエリの高速化）
CREATE INDEX IF NOT EXISTS idx_facilities_lat ON facilities (latitude);
CREATE INDEX IF NOT EXISTS idx_facilities_lng ON facilities (longitude);

-- 確認用クエリ（実行後にコメントアウト可能）
-- SELECT column_name, data_type FROM information_schema.columns
-- WHERE table_name = 'facilities' ORDER BY ordinal_position;
