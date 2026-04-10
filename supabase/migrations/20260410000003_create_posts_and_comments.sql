-- =============================================================
-- posts, post_likes, comments テーブルの作成
-- アプリの投稿・コメント・いいね機能に必要なテーブル
-- =============================================================

-- ── posts テーブル ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS posts (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  facility_id    UUID REFERENCES facilities(id) ON DELETE SET NULL,
  -- facility_name はJOINせずに高速表示するための非正規化カラム
  facility_name  TEXT NOT NULL DEFAULT '',
  content        TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 1000),
  image_url      TEXT,
  likes_count    INTEGER NOT NULL DEFAULT 0 CHECK (likes_count >= 0),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- インデックス（新しい順での取得・施設ごとの投稿一覧に使用）
CREATE INDEX IF NOT EXISTS posts_created_at_idx ON posts (created_at DESC);
CREATE INDEX IF NOT EXISTS posts_facility_id_idx ON posts (facility_id);
CREATE INDEX IF NOT EXISTS posts_user_id_idx ON posts (user_id);

-- Row Level Security（RLS）: セキュリティポリシーで誰が読み書きできるか制御
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- 全員が投稿を読める（公開フィード）
CREATE POLICY "posts_select_all"
  ON posts FOR SELECT
  USING (true);

-- 自分の投稿のみ作成できる
CREATE POLICY "posts_insert_own"
  ON posts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 自分の投稿のみ削除できる
CREATE POLICY "posts_delete_own"
  ON posts FOR DELETE
  USING (auth.uid() = user_id);

-- ── post_likes テーブル ───────────────────────────────────────
-- 誰がどの投稿にいいねしたかを管理
CREATE TABLE IF NOT EXISTS post_likes (
  post_id    UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)  -- 同じユーザーが同じ投稿に二重いいね不可
);

CREATE INDEX IF NOT EXISTS post_likes_user_id_idx ON post_likes (user_id);

ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "post_likes_select_all"
  ON post_likes FOR SELECT
  USING (true);

CREATE POLICY "post_likes_insert_own"
  ON post_likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "post_likes_delete_own"
  ON post_likes FOR DELETE
  USING (auth.uid() = user_id);

-- ── likes_count の自動更新トリガー ───────────────────────────
-- post_likes に INSERT/DELETE されたとき、posts.likes_count を自動更新する
CREATE OR REPLACE FUNCTION update_post_likes_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS on_post_like_change ON post_likes;
CREATE TRIGGER on_post_like_change
  AFTER INSERT OR DELETE ON post_likes
  FOR EACH ROW EXECUTE FUNCTION update_post_likes_count();

-- ── comments テーブル ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS comments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- 表示名はJOINを避けるための非正規化カラム（ユーザー削除時は削除済みと表示）
  user_name   TEXT NOT NULL DEFAULT '削除済みユーザー',
  user_avatar TEXT NOT NULL DEFAULT '',
  text        TEXT NOT NULL CHECK (char_length(text) BETWEEN 1 AND 500),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS comments_post_id_idx ON comments (post_id, created_at);

ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "comments_select_all"
  ON comments FOR SELECT
  USING (true);

CREATE POLICY "comments_insert_own"
  ON comments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "comments_delete_own"
  ON comments FOR DELETE
  USING (auth.uid() = user_id);
