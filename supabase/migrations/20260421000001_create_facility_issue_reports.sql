-- ============================================================
-- 施設情報誤り報告テーブル（facility_issue_reports）
-- 2026-04-21
--
-- ユーザーが「この施設の情報が違う」と報告するためのテーブル。
-- ※ facility_reports はアメニティ数値の報告用（別機能）のため
--   新テーブルとして作成。
-- ログイン不要（ゲストユーザーでも送信可能）
-- ============================================================

CREATE TABLE IF NOT EXISTS public.facility_issue_reports (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id   UUID        NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,

  -- ログイン済みなら保存（任意）
  user_id       UUID        REFERENCES auth.users(id) ON DELETE SET NULL,

  -- 報告種別
  -- 'hours_wrong'   : 営業時間・定休日が違う
  -- 'closed'        : 閉業・閉鎖している
  -- 'address_wrong' : 住所が違う
  -- 'phone_wrong'   : 電話番号が違う
  -- 'price_wrong'   : 料金が違う
  -- 'other'         : その他
  report_type   TEXT        NOT NULL CHECK (
    report_type IN ('hours_wrong', 'closed', 'address_wrong', 'phone_wrong', 'price_wrong', 'other')
  ),

  -- 詳細説明（任意）
  detail        TEXT,

  -- 連絡先（任意）
  contact       TEXT,

  -- 対応ステータス
  -- 'pending'  : 未対応
  -- 'reviewed' : 確認中
  -- 'applied'  : 修正済み
  status        TEXT        NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'reviewed', 'applied')
  ),

  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- インデックス
CREATE INDEX IF NOT EXISTS facility_issue_reports_facility_id_idx
  ON public.facility_issue_reports (facility_id);

CREATE INDEX IF NOT EXISTS facility_issue_reports_status_idx
  ON public.facility_issue_reports (status);

-- ─────────────────────────────────────
-- Row Level Security（RLS）設定
-- ─────────────────────────────────────
ALTER TABLE public.facility_issue_reports ENABLE ROW LEVEL SECURITY;

-- 誰でも（ゲスト・ログイン済み）INSERT可能
-- ただし user_id を送る場合は自分のIDのみ
CREATE POLICY "anyone_can_insert_facility_issue_report"
  ON public.facility_issue_reports FOR INSERT
  WITH CHECK (
    user_id IS NULL OR user_id = auth.uid()
  );

-- ログイン済みユーザーは自分の報告のみ閲覧可能
CREATE POLICY "users_can_view_own_facility_issue_reports"
  ON public.facility_issue_reports FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND user_id = auth.uid()
  );

-- GRANTも付与（PostgRESTがテーブルにアクセスできるようにする）
GRANT SELECT, INSERT ON public.facility_issue_reports TO anon;
GRANT SELECT, INSERT ON public.facility_issue_reports TO authenticated;
