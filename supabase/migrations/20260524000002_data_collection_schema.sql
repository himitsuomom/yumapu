-- ============================================================
-- Phase 2: データ収集エージェントシステム — DB スキーマ
-- 2026-05-24
--
-- 追加内容:
-- 1. facilities テーブルへの新カラム追加
-- 2. raw_facility_data   — ステージングテーブル
-- 3. crawl_schedule      — クロール管理
-- 4. facility_photos     — 施設写真
-- 5. source_trust_scores — ソース信頼スコア
-- 6. agent_queue         — Commanderキュー
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. facilities テーブル拡張
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.facilities
  ADD COLUMN IF NOT EXISTS spring_type       TEXT,
  ADD COLUMN IF NOT EXISTS ph_value          DECIMAL(3,1),
  ADD COLUMN IF NOT EXISTS source_temp       INTEGER,
  ADD COLUMN IF NOT EXISTS is_natural        BOOLEAN,
  ADD COLUMN IF NOT EXISTS sauna_details     JSONB,
  ADD COLUMN IF NOT EXISTS ryokan_details    JSONB,
  ADD COLUMN IF NOT EXISTS trending_score    INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_data_refresh TIMESTAMPTZ;

-- ────────────────────────────────────────────────────────────
-- 2. raw_facility_data — ステージング（収集データの一時置き場）
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.raw_facility_data (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id   UUID REFERENCES public.facilities(id) ON DELETE CASCADE,
  source        TEXT NOT NULL
    CHECK (source IN (
      'official_site','jalan','nifty','pdf_analysis',
      'photo_url','user_report','osm'
    )),
  raw_json      JSONB NOT NULL,
  content_hash  TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','merged','rejected','flagged')),
  conflict_info JSONB,
  collected_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_raw_facility_data_pending
  ON public.raw_facility_data(facility_id, source, collected_at DESC);
CREATE INDEX IF NOT EXISTS idx_raw_facility_data_status
  ON public.raw_facility_data(status)
  WHERE status = 'pending';

ALTER TABLE public.raw_facility_data ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role only" ON public.raw_facility_data
  USING (auth.role() = 'service_role');

-- ────────────────────────────────────────────────────────────
-- 3. crawl_schedule — クロールスケジュール管理
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crawl_schedule (
  facility_id           UUID PRIMARY KEY REFERENCES public.facilities(id) ON DELETE CASCADE,
  official_site_url     TEXT,
  jalan_url             TEXT,
  nifty_url             TEXT,
  last_crawled_at       TIMESTAMPTZ,
  content_hash          TEXT,
  crawl_ttl_hours       INTEGER DEFAULT 168,
  priority              INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
  status                TEXT DEFAULT 'pending'
    CHECK (status IN ('pending','in_progress','done','error','skipped')),
  data_complete         BOOLEAN DEFAULT FALSE,
  last_error            TEXT,
  error_count           INTEGER DEFAULT 0,
  verified_at           TIMESTAMPTZ,
  human_review_needed   BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_crawl_schedule_pending
  ON public.crawl_schedule(priority, last_crawled_at)
  WHERE data_complete = FALSE;

ALTER TABLE public.crawl_schedule ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role only" ON public.crawl_schedule
  USING (auth.role() = 'service_role');

-- ────────────────────────────────────────────────────────────
-- 4. facility_photos — 施設写真
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.facility_photos (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id   UUID REFERENCES public.facilities(id) ON DELETE CASCADE,
  photo_url     TEXT NOT NULL,
  local_path    TEXT,
  source        TEXT CHECK (source IN (
    'official_site','wikimedia','unsplash','facility_provided','yumap_user'
  )),
  photo_type    TEXT CHECK (photo_type IN (
    'exterior','interior','bath','outdoor_bath','sauna','food','other'
  )),
  license       TEXT DEFAULT 'unknown' CHECK (license IN (
    'unknown','cc_by','cc_by_sa','cc0','facility_owned','yumap_ugc'
  )),
  attribution   TEXT,
  is_primary    BOOLEAN DEFAULT FALSE,
  width         INTEGER,
  height        INTEGER,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_facility_photos_facility
  ON public.facility_photos(facility_id, is_primary DESC);

ALTER TABLE public.facility_photos ENABLE ROW LEVEL SECURITY;
-- 認証ユーザーは閲覧可能、書き込みはservice_roleのみ
CREATE POLICY "Anyone can read photos" ON public.facility_photos
  FOR SELECT USING (TRUE);
CREATE POLICY "Service role can write photos" ON public.facility_photos
  FOR ALL USING (auth.role() = 'service_role');

-- ────────────────────────────────────────────────────────────
-- 5. source_trust_scores — ソース別信頼スコア定義
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.source_trust_scores (
  source_name         TEXT PRIMARY KEY,
  trust_by_attribute  JSONB NOT NULL DEFAULT '{}'
);

INSERT INTO public.source_trust_scores (source_name, trust_by_attribute) VALUES
  ('official_site', '{"price":0.95,"hours":0.90,"phone":0.99,"holiday":0.88,"amenities":0.75,"spring_type":0.60}'),
  ('jalan',         '{"price":0.80,"hours":0.82,"phone":0.70,"holiday":0.75,"amenities":0.70}'),
  ('nifty',         '{"price":0.72,"hours":0.75,"phone":0.65,"holiday":0.70,"amenities":0.68}'),
  ('pdf_analysis',  '{"price":0.20,"hours":0.15,"amenities":0.90,"spring_type":0.99,"ph_value":0.99,"source_temp":0.99}'),
  ('osm',           '{"price":0.50,"hours":0.70,"phone":0.60,"holiday":0.40,"amenities":0.65}'),
  ('user_report',   '{"price":0.70,"hours":0.75,"phone":0.65,"holiday":0.70}')
ON CONFLICT (source_name) DO NOTHING;

ALTER TABLE public.source_trust_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read trust scores" ON public.source_trust_scores
  FOR SELECT USING (TRUE);
CREATE POLICY "Service role can write trust scores" ON public.source_trust_scores
  FOR ALL USING (auth.role() = 'service_role');

-- ────────────────────────────────────────────────────────────
-- 6. agent_queue — Commander が読むタスクキュー
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.agent_queue (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_type     TEXT NOT NULL
    CHECK (task_type IN ('batch_crawl','pdf_analyze','daily_refresh','photo_collect')),
  payload       JSONB,
  priority      INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
  status        TEXT DEFAULT 'pending'
    CHECK (status IN ('pending','processing','done','error')),
  result        JSONB,
  error_message TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  processed_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_agent_queue_pending
  ON public.agent_queue(priority, created_at)
  WHERE status = 'pending';

ALTER TABLE public.agent_queue ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role only" ON public.agent_queue
  USING (auth.role() = 'service_role');

-- ────────────────────────────────────────────────────────────
-- pg_cron: 30分毎に batch_crawl タスクをキューに積む
-- (aggressive モード — 既存タスクがない場合のみ)
-- ────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'queue-crawl-batch-aggressive',
      '*/30 * * * *',
      $$
        INSERT INTO public.agent_queue (task_type, priority)
        SELECT 'batch_crawl', 1
        WHERE NOT EXISTS (
          SELECT 1 FROM public.agent_queue
          WHERE task_type = 'batch_crawl'
            AND status IN ('pending','processing')
        );
      $$
    );
    RAISE NOTICE 'pg_cron スケジュール登録完了';
  ELSE
    RAISE NOTICE 'pg_cron 未インストール — スケジュールはスキップ';
  END IF;
END$$;

-- ────────────────────────────────────────────────────────────
-- crawl_schedule 初期投入（全施設を pending で登録）
-- ────────────────────────────────────────────────────────────
INSERT INTO public.crawl_schedule (facility_id, priority)
SELECT id, 5 FROM public.facilities
ON CONFLICT (facility_id) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- 検証用クエリ（コメントアウト — 手動確認時に使用）
-- ────────────────────────────────────────────────────────────
-- SELECT COUNT(*) FROM crawl_schedule WHERE data_complete = FALSE;
-- SELECT source_name, trust_by_attribute FROM source_trust_scores;
-- SELECT COUNT(*) FROM agent_queue WHERE status = 'pending';
