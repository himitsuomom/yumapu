-- Migration: favorites テーブルと review_likes テーブルの作成
--
-- 問題: これらのテーブルは Flutter アプリから参照されているが
--       初期スキーマに含まれていなかった。
-- ============================================================

-- ============================================================
-- 1. favorites テーブル
-- ============================================================
CREATE TABLE IF NOT EXISTS favorites (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  facility_id UUID        NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, facility_id)
);

CREATE INDEX IF NOT EXISTS idx_favorites_user
  ON favorites (user_id);

CREATE INDEX IF NOT EXISTS idx_favorites_facility
  ON favorites (facility_id);

-- RLS 有効化
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- 自分のお気に入りのみ参照可
CREATE POLICY "Users can view own favorites"
  ON favorites FOR SELECT
  USING (auth.uid() = user_id);

-- 自分のお気に入りのみ追加可
CREATE POLICY "Users can add favorites"
  ON favorites FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 自分のお気に入りのみ削除可
CREATE POLICY "Users can remove favorites"
  ON favorites FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- 2. review_likes テーブル
-- ============================================================
CREATE TABLE IF NOT EXISTS review_likes (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id  UUID        NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (review_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_review_likes_review
  ON review_likes (review_id);

CREATE INDEX IF NOT EXISTS idx_review_likes_user
  ON review_likes (user_id);

-- RLS 有効化
ALTER TABLE review_likes ENABLE ROW LEVEL SECURITY;

-- 全員が閲覧可（いいね数表示のため）
CREATE POLICY "Review likes are viewable by everyone"
  ON review_likes FOR SELECT
  USING (true);

-- ログインユーザーのみいいね可
CREATE POLICY "Users can like reviews"
  ON review_likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 自分のいいねのみ取り消し可
CREATE POLICY "Users can unlike reviews"
  ON review_likes FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- 3. review_likes 追加時に reviews.likes_count を自動更新するトリガー
-- ============================================================
CREATE OR REPLACE FUNCTION update_review_likes_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE reviews
    SET likes_count = likes_count + 1
    WHERE id = NEW.review_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE reviews
    SET likes_count = GREATEST(likes_count - 1, 0)
    WHERE id = OLD.review_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_review_likes_count ON review_likes;
CREATE TRIGGER trg_update_review_likes_count
  AFTER INSERT OR DELETE ON review_likes
  FOR EACH ROW
  EXECUTE FUNCTION update_review_likes_count();

-- ============================================================
-- 4. reviews テーブルに likes_count カラムがなければ追加
-- ============================================================
ALTER TABLE reviews
  ADD COLUMN IF NOT EXISTS likes_count INT DEFAULT 0;

COMMENT ON TABLE favorites    IS 'ユーザーのお気に入り施設';
COMMENT ON TABLE review_likes IS 'レビューへのいいね';
