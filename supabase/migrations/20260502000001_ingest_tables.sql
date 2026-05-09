-- ============================================================
-- 情報収集テーブル: source_posts / facility_mentions
-- ============================================================
-- Misskey・Mastodon・YouTube・ブログRSS 等から収集した投稿を保存し、
-- 施設との紐付けを管理する。

-- 収集した生投稿（プラットフォーム横断）
CREATE TABLE IF NOT EXISTS source_posts (
  id            TEXT PRIMARY KEY,          -- "{platform}:{external_id}"
  platform      TEXT NOT NULL,             -- 'misskey'|'mastodon'|'youtube'|'rss'
  source_handle TEXT NOT NULL,             -- ハンドル / チャンネル名 / ブログ名
  url           TEXT NOT NULL,
  title         TEXT,
  content_text  TEXT,                      -- HTMLタグ除去済み本文
  content_html  TEXT,                      -- 埋め込み用HTML
  thumbnail_url TEXT,
  published_at  TIMESTAMPTZ NOT NULL,
  fetched_at    TIMESTAMPTZ DEFAULT NOW(),
  raw           JSONB
);

CREATE INDEX IF NOT EXISTS idx_source_posts_platform_pub
  ON source_posts (platform, published_at DESC);

CREATE INDEX IF NOT EXISTS idx_source_posts_pub
  ON source_posts (published_at DESC);

-- 施設への言及（施設IDと投稿の紐付け）
CREATE TABLE IF NOT EXISTS facility_mentions (
  id           BIGSERIAL PRIMARY KEY,
  facility_id  UUID REFERENCES facilities(id) ON DELETE CASCADE,
  post_id      TEXT REFERENCES source_posts(id) ON DELETE CASCADE,
  match_method TEXT,          -- 'regex_brackets'|'dict'|'keyword'|'manual'
  match_score  REAL DEFAULT 1.0,
  excerpt      TEXT,          -- 抜粋120字
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT facility_mentions_unique UNIQUE (facility_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_facility_mentions_facility
  ON facility_mentions (facility_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_facility_mentions_post
  ON facility_mentions (post_id);

-- RLS: 読み取りは全員許可、書き込みは service_role のみ（デフォルト deny）
ALTER TABLE source_posts      ENABLE ROW LEVEL SECURITY;
ALTER TABLE facility_mentions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "source_posts_read"
  ON source_posts FOR SELECT USING (TRUE);

CREATE POLICY "facility_mentions_read"
  ON facility_mentions FOR SELECT USING (TRUE);

-- 施設ごとの言及数ビュー（マップの「盛り上がり度」スコアに使用）
CREATE OR REPLACE VIEW facility_mention_counts AS
SELECT
  facility_id,
  COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days')  AS mentions_7d,
  COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '30 days') AS mentions_30d,
  COUNT(*) AS mentions_total
FROM facility_mentions
GROUP BY facility_id;
