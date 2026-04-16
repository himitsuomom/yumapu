-- ============================================================
-- posts.comments_count カラム追加 + 自動更新トリガー
-- 2026-04-14
--
-- 問題: posts テーブルに comments_count カラムがなく
--       フィード画面のコメント数が常に 0 だった
-- 修正: カラム追加 + INSERT/DELETE トリガーで自動更新
-- ============================================================

-- 1. カラム追加
ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS comments_count INTEGER NOT NULL DEFAULT 0
    CHECK (comments_count >= 0);

-- 2. 既存レコードの初期化
UPDATE posts p
SET comments_count = (
  SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id
);

-- 3. 自動更新トリガー
CREATE OR REPLACE FUNCTION public.update_post_comments_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS on_comment_change ON comments;
CREATE TRIGGER on_comment_change
  AFTER INSERT OR DELETE ON comments
  FOR EACH ROW
  EXECUTE FUNCTION public.update_post_comments_count();
