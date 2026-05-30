-- ユニーク制約の追加（まだない場合のみ）
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'user_follows_unique'
  ) THEN
    ALTER TABLE user_follows
      ADD CONSTRAINT user_follows_unique UNIQUE (follower_id, following_id);
  END IF;
END $$;

-- 自分自身へのフォロー禁止（まだない場合のみ）
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'user_follows_no_self'
  ) THEN
    ALTER TABLE user_follows
      ADD CONSTRAINT user_follows_no_self CHECK (follower_id != following_id);
  END IF;
END $$;

-- RLS ポリシー（テーブルのRLSが無効の場合のみ有効化）
ALTER TABLE user_follows ENABLE ROW LEVEL SECURITY;

-- 既存のポリシーを削除してから再作成
DROP POLICY IF EXISTS follow_select_all ON user_follows;
DROP POLICY IF EXISTS follow_insert_own ON user_follows;
DROP POLICY IF EXISTS follow_delete_own ON user_follows;

CREATE POLICY follow_select_all ON user_follows FOR SELECT USING (true);
CREATE POLICY follow_insert_own ON user_follows FOR INSERT
  WITH CHECK (auth.uid() = follower_id);
CREATE POLICY follow_delete_own ON user_follows FOR DELETE
  USING (auth.uid() = follower_id);

-- get_follow_counts RPC
CREATE OR REPLACE FUNCTION public.get_follow_counts(p_user_id UUID)
RETURNS TABLE(followers_count INT, following_count INT)
LANGUAGE SQL STABLE AS $$
  SELECT
    (SELECT COUNT(*)::INT FROM user_follows WHERE following_id = p_user_id) AS followers_count,
    (SELECT COUNT(*)::INT FROM user_follows WHERE follower_id = p_user_id) AS following_count;
$$;
