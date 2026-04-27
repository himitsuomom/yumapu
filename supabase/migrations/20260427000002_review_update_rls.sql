-- reviews テーブルに UPDATE RLS ポリシーを追加する。
--
-- セッション31でレビュー削除（DELETE）UIを追加したが、
-- レビュー編集（UPDATE）のポリシーが未設定だった。
-- 投稿者本人（auth.uid() = user_id）のみ自分のレビューを更新できる。

-- ポリシーが重複する場合は事前に削除する（冪等性確保）
DROP POLICY IF EXISTS "Users can update own reviews" ON reviews;

CREATE POLICY "Users can update own reviews"
  ON reviews
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
