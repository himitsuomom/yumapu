-- #7: post_likes ユニーク制約（重複いいねを防ぐ）
-- 既に制約が存在する場合はスキップする
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'post_likes_unique'
  ) THEN
    ALTER TABLE post_likes
      ADD CONSTRAINT post_likes_unique UNIQUE (post_id, user_id);
  END IF;
END $$;

-- comments テーブルの user_name / user_avatar カラムを確保
-- comment_provider.dart が非正規化カラムとして使用するため
ALTER TABLE comments ADD COLUMN IF NOT EXISTS user_name TEXT;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS user_avatar TEXT;
