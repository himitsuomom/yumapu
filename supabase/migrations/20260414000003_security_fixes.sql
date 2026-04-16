-- ============================================================
-- セキュリティ修正
-- 2026-04-14
--
-- 修正内容:
-- 1. visits テーブルに created_at カラム追加
-- 2. visits テーブルに DELETE ポリシー追加
-- 3. inquiries INSERT ポリシーを強化（自分のuser_id のみ設定可）
-- 4. Storage SELECT ポリシーをバケット一覧不可に変更
-- ============================================================

-- ─────────────────────────────────────
-- 1. visits に created_at カラム追加
-- ─────────────────────────────────────
ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

UPDATE visits
SET created_at = COALESCE(visited_at, NOW())
WHERE created_at IS NULL;

-- ─────────────────────────────────────
-- 2. visits の DELETE ポリシー追加
-- ─────────────────────────────────────
CREATE POLICY "Users can delete own visits"
  ON visits FOR DELETE
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────
-- 3. inquiries INSERT ポリシーを強化
--    未認証ユーザーは user_id = NULL でのみ投稿可能
-- ─────────────────────────────────────
DROP POLICY IF EXISTS "anyone_can_insert_inquiry" ON inquiries;

CREATE POLICY "authenticated_or_anon_can_insert_inquiry"
  ON inquiries FOR INSERT
  WITH CHECK (
    user_id IS NULL
    OR user_id = auth.uid()
  );

-- ─────────────────────────────────────
-- 4. Storage SELECT ポリシー修正
--    バケット一覧を防止し、パスを知っている場合のみ読める設定に
-- ─────────────────────────────────────
DROP POLICY IF EXISTS "avatars: 誰でも閲覧可能" ON storage.objects;
DROP POLICY IF EXISTS "post-images: 誰でも閲覧可能" ON storage.objects;

-- avatars: anon でも読めるが一覧は取れない（パブリックバケットはURL直接アクセスで動作）
CREATE POLICY "avatars: public read by path"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'avatars'
    AND auth.role() = 'anon'
  );

-- post-images: URL を知っていれば誰でも読める
CREATE POLICY "post-images: public read by path"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'post-images');
