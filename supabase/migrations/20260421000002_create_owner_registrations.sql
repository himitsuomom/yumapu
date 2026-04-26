-- ============================================================
-- オーナー登録申請テーブル（owner_registrations）
-- 2026-04-21
--
-- 施設のオーナー・管理者が「自分がこの施設の管理者です」と
-- 申請するためのテーブル。
-- 運営者が審査して approved にすると、将来的に施設情報の
-- 編集権限を付与できるようになる（権限付与は今後の実装）。
-- ============================================================

CREATE TABLE IF NOT EXISTS owner_registrations (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id   UUID        NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,

  -- 申請者の Supabase ユーザー ID（ログイン必須）
  user_id       UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- オーナー情報（施設の代表者・担当者）
  owner_name    TEXT        NOT NULL,
  owner_email   TEXT        NOT NULL,
  owner_phone   TEXT,

  -- 申請理由・証明方法（「看板に連絡先が載っています」など）
  message       TEXT,

  -- 審査ステータス
  -- 'pending'  : 審査待ち
  -- 'approved' : 承認済み
  -- 'rejected' : 却下
  status        TEXT        NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'approved', 'rejected')
  ),

  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- インデックス: 施設IDで絞り込む操作
CREATE INDEX IF NOT EXISTS owner_registrations_facility_id_idx
  ON owner_registrations (facility_id);

-- インデックス: ユーザーIDで自分の申請を確認する操作
CREATE INDEX IF NOT EXISTS owner_registrations_user_id_idx
  ON owner_registrations (user_id);

-- ─────────────────────────────────────
-- Row Level Security（RLS）設定
-- ─────────────────────────────────────
ALTER TABLE owner_registrations ENABLE ROW LEVEL SECURITY;

-- ログイン済みユーザーのみ、自分のIDで申請できる
CREATE POLICY "authenticated_can_insert_owner_registration"
  ON owner_registrations FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND user_id = auth.uid()
  );

-- ログイン済みユーザーは自分の申請レコードのみ閲覧可能
CREATE POLICY "users_can_view_own_owner_registrations"
  ON owner_registrations FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND user_id = auth.uid()
  );

-- 同一施設に対して同一ユーザーが重複申請できないよう UNIQUE 制約を追加
-- （pending・approved が重複しないよう）
CREATE UNIQUE INDEX IF NOT EXISTS owner_registrations_no_duplicate_idx
  ON owner_registrations (facility_id, user_id)
  WHERE status IN ('pending', 'approved');
