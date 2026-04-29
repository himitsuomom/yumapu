-- ============================================================
-- osm_id に正規の UNIQUE 制約を追加
-- ============================================================
-- 背景:
--   20260403000001_add_osm_fields.sql で osm_id に「部分インデックス」
--   (WHERE osm_id IS NOT NULL) を作成したが、Supabase REST API の
--   UPSERT（?on_conflict=osm_id）は部分インデックスを認識できない。
--   → "there is no unique or exclusion constraint matching the ON CONFLICT
--      specification" エラーが発生し、全件スキップされる。
--
-- 修正:
--   1. 部分インデックスを削除
--   2. 通常の UNIQUE 制約を追加
--      （NULL 値には適用されないため既存データへの影響なし）
-- ============================================================

-- 旧部分インデックスを削除（存在する場合のみ）
DROP INDEX IF EXISTS idx_facilities_osm_id;

-- osm_id カラムを追加（まだ存在しない場合のみ）
ALTER TABLE facilities
  ADD COLUMN IF NOT EXISTS osm_id TEXT;

-- 正規の UNIQUE 制約を追加
-- PostgreSQL では UNIQUE 制約は NULL を除外するため、
-- NULL が複数あっても違反にならない（既存テストデータへの影響なし）
ALTER TABLE facilities
  DROP CONSTRAINT IF EXISTS facilities_osm_id_key;

ALTER TABLE facilities
  ADD CONSTRAINT facilities_osm_id_key UNIQUE (osm_id);

-- lat/lng カラムも念のため追加（まだ存在しない場合のみ）
ALTER TABLE facilities
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
