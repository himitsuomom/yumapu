-- ============================================================
-- W2-法的安全性: source_posts の公開リスク低減
-- ============================================================

ALTER TABLE source_posts
  ADD COLUMN IF NOT EXISTS author_url TEXT,
  ADD COLUMN IF NOT EXISTS content_summary TEXT;

ALTER TABLE source_posts
  DROP CONSTRAINT IF EXISTS chk_content_summary_len;
ALTER TABLE source_posts
  ADD CONSTRAINT chk_content_summary_len
    CHECK (content_summary IS NULL OR char_length(content_summary) <= 280);

CREATE INDEX IF NOT EXISTS idx_source_posts_author_url
  ON source_posts (author_url) WHERE author_url IS NOT NULL;

-- 既存 RLS ポリシーを差し替え
DROP POLICY IF EXISTS "source_posts_read" ON source_posts;

CREATE POLICY "source_posts_read_authenticated"
  ON source_posts FOR SELECT TO authenticated
  USING (status = 'active');

-- 公開用 VIEW: 原文を含まない
DROP VIEW IF EXISTS public_source_posts;
CREATE VIEW public_source_posts
WITH (security_invoker = true) AS
SELECT
  id,
  source_id,
  url,
  title,
  content_summary,
  author_url,
  thumbnail_url,
  published_at,
  fetched_at,
  status
FROM source_posts
WHERE status = 'active';

GRANT SELECT ON public_source_posts TO anon, authenticated;

COMMENT ON VIEW public_source_posts IS
  '公開用ビュー。content_text/content_html を含まず、著作権リスクを排除。';
COMMENT ON COLUMN source_posts.content_text IS
  '原文（公開禁止）。マッチング処理にのみ使用。RLSでpublicから隠蔽。';
COMMENT ON COLUMN source_posts.content_summary IS
  '公開用要約（280字以内）。引用要件の主従関係を保つ。';
COMMENT ON COLUMN source_posts.author_url IS
  'ActivityPub attributedTo / RSS author URL。出所明示用。';
