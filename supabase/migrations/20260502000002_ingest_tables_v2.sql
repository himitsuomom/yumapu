-- ============================================================
-- W1-1: 情報収集ツール包括スキーマ (v2)
-- ============================================================
-- 既存の source_posts / facility_mentions を拡張版に置き換える。
-- ingest_sources / ingest_runs / 監視・法務テーブル群を新設。

-- ============================================================
-- 既存テーブル・ビューの削除（CASCADE で依存も解消）
-- ============================================================
DROP VIEW  IF EXISTS facility_mention_counts;
DROP TABLE IF EXISTS facility_mentions CASCADE;
DROP TABLE IF EXISTS source_posts CASCADE;

-- ============================================================
-- ENUM 型
-- ============================================================
DO $$ BEGIN
  CREATE TYPE platform_kind AS ENUM (
    'youtube','misskey','mastodon','note','hatena','wp','rss_commercial','manual'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE post_status AS ENUM (
    'active','spam','duplicate','deleted_origin','hidden_admin','pending_review'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- ingest_sources（取得元の死活管理）
-- ============================================================
CREATE TABLE IF NOT EXISTS ingest_sources (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform              platform_kind NOT NULL,
  handle                TEXT NOT NULL,
  feed_url              TEXT NOT NULL,
  display_name          TEXT NOT NULL,
  is_enabled            BOOLEAN DEFAULT TRUE,
  last_success_at       TIMESTAMPTZ,
  last_error_at         TIMESTAMPTZ,
  last_error_msg        TEXT,
  consecutive_errors    INT DEFAULT 0,
  etag                  TEXT,
  last_modified         TEXT,
  min_interval_seconds  INT DEFAULT 1800,
  next_eligible_at      TIMESTAMPTZ DEFAULT NOW(),
  notes                 TEXT,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (platform, handle)
);

CREATE INDEX IF NOT EXISTS idx_ingest_sources_eligible
  ON ingest_sources (is_enabled, next_eligible_at)
  WHERE is_enabled = TRUE;

-- ============================================================
-- source_posts（投稿の生取り込み）
-- ============================================================
CREATE TABLE IF NOT EXISTS source_posts (
  id                  TEXT PRIMARY KEY,          -- "{platform}:{external_id}"
  source_id           UUID REFERENCES ingest_sources(id) ON DELETE SET NULL,
  content_hash        TEXT NOT NULL,             -- SHA256(normalized_text)
  url                 TEXT NOT NULL,
  title               TEXT,
  content_text        TEXT,
  content_html        TEXT,
  thumbnail_url       TEXT,
  published_at        TIMESTAMPTZ NOT NULL,
  fetched_at          TIMESTAMPTZ DEFAULT NOW(),
  status              post_status DEFAULT 'active',
  status_reason       TEXT,
  origin_deleted_at   TIMESTAMPTZ,
  hidden_at           TIMESTAMPTZ,
  raw                 JSONB,
  raw_schema_version  INT DEFAULT 1,
  -- 将来日時防御（1時間まで許容）
  CONSTRAINT chk_published_not_future
    CHECK (published_at <= NOW() + INTERVAL '1 hour')
);

CREATE INDEX IF NOT EXISTS idx_source_posts_pub       ON source_posts (published_at DESC);
CREATE INDEX IF NOT EXISTS idx_source_posts_status    ON source_posts (status) WHERE status != 'active';
CREATE INDEX IF NOT EXISTS idx_source_posts_source    ON source_posts (source_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_source_posts_hash ON source_posts (content_hash);

-- ============================================================
-- facility_mentions（施設言及・マッチング結果）
-- ============================================================
CREATE TABLE IF NOT EXISTS facility_mentions (
  id              BIGSERIAL PRIMARY KEY,
  facility_id     UUID REFERENCES facilities(id) ON DELETE CASCADE,
  post_id         TEXT REFERENCES source_posts(id) ON DELETE CASCADE,
  match_method    TEXT NOT NULL CHECK (match_method IN
                    ('regex_brackets','dict_aho','geocoded','manual','user_feedback')),
  match_score     REAL NOT NULL CHECK (match_score BETWEEN 0 AND 1),
  match_evidence  TEXT,
  excerpt         TEXT,
  excerpt_chars   INT GENERATED ALWAYS AS (char_length(excerpt)) STORED,
  is_correct      BOOLEAN,   -- NULL=未評価、TRUE=正解、FALSE=誤検知
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT facility_mentions_unique UNIQUE (facility_id, post_id),
  CONSTRAINT chk_excerpt_len CHECK (excerpt_chars <= 200)
);

CREATE INDEX IF NOT EXISTS idx_facility_mentions_facility
  ON facility_mentions (facility_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_facility_mentions_score
  ON facility_mentions (match_score DESC) WHERE is_correct IS NULL;

-- ============================================================
-- ingest_runs（取り込みログ）
-- ============================================================
CREATE TABLE IF NOT EXISTS ingest_runs (
  id                    BIGSERIAL PRIMARY KEY,
  source_id             UUID REFERENCES ingest_sources(id) ON DELETE CASCADE,
  started_at            TIMESTAMPTZ DEFAULT NOW(),
  finished_at           TIMESTAMPTZ,
  status                TEXT CHECK (status IN
                          ('running','success','failed',
                           'skipped_rate_limit','skipped_not_modified')),
  http_status           INT,
  posts_fetched         INT DEFAULT 0,
  posts_new             INT DEFAULT 0,
  posts_updated         INT DEFAULT 0,
  posts_skipped_dup     INT DEFAULT 0,
  mentions_created      INT DEFAULT 0,
  error_class           TEXT,
  error_message         TEXT,
  duration_ms           INT
);

CREATE INDEX IF NOT EXISTS idx_ingest_runs_source
  ON ingest_runs (source_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_ingest_runs_failed
  ON ingest_runs (started_at DESC)
  WHERE status IN ('failed','running');

-- ============================================================
-- ingest_dead_letters（処理失敗箱）
-- ============================================================
CREATE TABLE IF NOT EXISTS ingest_dead_letters (
  id            BIGSERIAL PRIMARY KEY,
  run_id        BIGINT REFERENCES ingest_runs(id) ON DELETE SET NULL,
  raw_payload   JSONB,
  error_message TEXT,
  retry_count   INT DEFAULT 0,
  resolved_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- places_cache（Google Places 30日ルール強制）
-- ============================================================
CREATE TABLE IF NOT EXISTS places_cache (
  place_id        TEXT PRIMARY KEY,
  lat             DOUBLE PRECISION,
  lng             DOUBLE PRECISION,
  expires_at      TIMESTAMPTZ NOT NULL,
  display_payload JSONB,
  fetched_at      TIMESTAMPTZ DEFAULT NOW(),
  -- 30日以上のキャッシュ禁止
  CONSTRAINT chk_cache_max_30d
    CHECK (expires_at <= fetched_at + INTERVAL '30 days')
);

CREATE INDEX IF NOT EXISTS idx_places_cache_expires ON places_cache (expires_at);

-- ============================================================
-- api_usage_log（コスト監視）
-- ============================================================
CREATE TABLE IF NOT EXISTS api_usage_log (
  id          BIGSERIAL PRIMARY KEY,
  api_name    TEXT NOT NULL,
  endpoint    TEXT,
  sku         TEXT,
  field_mask  TEXT,
  cost_usd    NUMERIC(10, 6),
  called_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_api_usage_log ON api_usage_log (api_name, called_at DESC);

-- ============================================================
-- removal_requests（削除依頼管理）
-- ============================================================
CREATE TABLE IF NOT EXISTS removal_requests (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_type   TEXT NOT NULL CHECK (request_type IN
                   ('post_takedown','facility_takedown','user_data_deletion')),
  target_id      TEXT,
  requester_email TEXT,
  reason         TEXT,
  status         TEXT DEFAULT 'pending' CHECK (status IN
                   ('pending','approved','rejected','completed')),
  received_at    TIMESTAMPTZ DEFAULT NOW(),
  resolved_at    TIMESTAMPTZ,
  resolved_by    UUID
);

-- ============================================================
-- RLS
-- ============================================================
ALTER TABLE ingest_sources       ENABLE ROW LEVEL SECURITY;
ALTER TABLE source_posts         ENABLE ROW LEVEL SECURITY;
ALTER TABLE facility_mentions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingest_runs          ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingest_dead_letters  ENABLE ROW LEVEL SECURITY;
ALTER TABLE places_cache         ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_usage_log        ENABLE ROW LEVEL SECURITY;
ALTER TABLE removal_requests     ENABLE ROW LEVEL SECURITY;

-- ingest_sources: 認証ユーザー読み取り
CREATE POLICY "ingest_sources_read"
  ON ingest_sources FOR SELECT TO authenticated USING (TRUE);

-- source_posts: active のみ public 読み取り
CREATE POLICY "source_posts_read"
  ON source_posts FOR SELECT USING (status = 'active');

-- facility_mentions: public 読み取り
CREATE POLICY "facility_mentions_read"
  ON facility_mentions FOR SELECT USING (TRUE);

-- facility_mentions: 認証ユーザーは is_correct のみ更新可
CREATE POLICY "facility_mentions_feedback"
  ON facility_mentions FOR UPDATE TO authenticated
  USING (TRUE)
  WITH CHECK (TRUE);

-- removal_requests: 認証ユーザーは INSERT のみ
CREATE POLICY "removal_requests_insert"
  ON removal_requests FOR INSERT TO authenticated WITH CHECK (TRUE);

-- ============================================================
-- 施設言及数ビュー（再作成）
-- ============================================================
CREATE OR REPLACE VIEW facility_mention_counts AS
SELECT
  facility_id,
  COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days')  AS mentions_7d,
  COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '30 days') AS mentions_30d,
  COUNT(*) AS mentions_total
FROM facility_mentions
GROUP BY facility_id;

-- ============================================================
-- Google Places キャッシュ期限切れ処理
-- ============================================================
CREATE OR REPLACE FUNCTION cleanup_expired_places_cache()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE places_cache
  SET lat = NULL, lng = NULL, display_payload = NULL
  WHERE expires_at < NOW();
$$;

-- ============================================================
-- facilities への発見ステータス列追加
-- ============================================================
ALTER TABLE facilities
  ADD COLUMN IF NOT EXISTS discovery_status TEXT DEFAULT 'verified'
    CHECK (discovery_status IN ('candidate','verified','rejected')),
  ADD COLUMN IF NOT EXISTS discovered_from_post_ids TEXT[],
  ADD COLUMN IF NOT EXISTS candidate_score REAL;
