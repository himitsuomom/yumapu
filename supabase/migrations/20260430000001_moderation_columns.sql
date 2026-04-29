-- Wave 2: reviews + photos にモデレーション用カラムを追加
-- 既存レコードは passed で補完（移行後に非表示にならないよう）

-- reviews
ALTER TABLE reviews
  ADD COLUMN IF NOT EXISTS moderation_status TEXT NOT NULL DEFAULT 'passed'
    CHECK (moderation_status IN ('pending', 'passed', 'blocked')),
  ADD COLUMN IF NOT EXISTS moderation_checked_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS moderation_reason TEXT;

-- 既存レコードを passed に設定（DEFAULT で付与済みだが明示）
UPDATE reviews SET moderation_status = 'passed' WHERE moderation_status = 'pending';

-- photos
ALTER TABLE photos
  ADD COLUMN IF NOT EXISTS moderation_status TEXT NOT NULL DEFAULT 'passed'
    CHECK (moderation_status IN ('pending', 'passed', 'blocked')),
  ADD COLUMN IF NOT EXISTS moderation_checked_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS moderation_reason TEXT;

UPDATE photos SET moderation_status = 'passed' WHERE moderation_status = 'pending';

-- reviews RLS: blocked を一般ユーザーに非表示
-- 既存 SELECT ポリシーを削除して再定義
DROP POLICY IF EXISTS "reviews_select_all" ON reviews;
DROP POLICY IF EXISTS "reviews_select" ON reviews;

CREATE POLICY "reviews_select_visible" ON reviews
  FOR SELECT USING (
    moderation_status = 'passed'
    OR user_id = auth.uid()
  );

-- photos RLS: blocked を非表示
DROP POLICY IF EXISTS "photos_select_all" ON photos;
DROP POLICY IF EXISTS "photos_select" ON photos;

CREATE POLICY "photos_select_visible" ON photos
  FOR SELECT USING (
    moderation_status = 'passed'
    OR user_id = auth.uid()
  );
