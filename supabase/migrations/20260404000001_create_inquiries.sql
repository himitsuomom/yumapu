-- 20260404000001_create_inquiries.sql
--
-- 問い合わせテーブル
-- 施設詳細画面からの「営業時間変更報告」「未登録施設追加申請」を保存する

-- テーブル作成
CREATE TABLE IF NOT EXISTS inquiries (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  type         TEXT        NOT NULL CHECK (type IN ('hours_change', 'add_facility')),
  facility_name TEXT       NOT NULL,
  message      TEXT        NOT NULL,
  contact      TEXT,
  user_id      UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- RLS 有効化
ALTER TABLE inquiries ENABLE ROW LEVEL SECURITY;

-- ポリシー: 誰でも送信できる（匿名ユーザー含む）
CREATE POLICY "anyone_can_insert_inquiry"
  ON inquiries
  FOR INSERT
  WITH CHECK (true);

-- ポリシー: 一般ユーザーは自分の問い合わせのみ閲覧可
CREATE POLICY "user_can_read_own_inquiry"
  ON inquiries
  FOR SELECT
  USING (user_id = auth.uid());

-- コメント
COMMENT ON TABLE inquiries IS '施設への問い合わせ（営業時間変更報告・未登録施設追加申請）';
COMMENT ON COLUMN inquiries.type IS 'hours_change | add_facility';
COMMENT ON COLUMN inquiries.contact IS '任意の連絡先メールアドレス';
