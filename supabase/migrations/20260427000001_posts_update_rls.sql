-- 20260427000001_posts_update_rls.sql
--
-- posts テーブルに UPDATE ポリシーを追加する。
-- C-3対応: 投稿編集機能のためにオーナーのみが自分の投稿を更新できるようにする。
--
-- 既存ポリシー: posts_select_all / posts_insert_own / posts_delete_own
-- 今回追加:    posts_update_own

-- 自分の投稿のみ UPDATE を許可する
-- USING: 更新対象行の絞り込み（auth.uid() が投稿者のみ）
-- WITH CHECK: 更新後の値の検証（user_id を書き換えられないようにする）
CREATE POLICY "posts_update_own"
  ON posts
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
