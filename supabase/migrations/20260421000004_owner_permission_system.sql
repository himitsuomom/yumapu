-- ============================================================
-- オーナー権限システム
-- 2026-04-21
--
-- 1. users テーブルに is_admin フラグを追加
-- 2. owner_registrations の管理者向けポリシーを追加
-- 3. facilities のオーナー更新ポリシーを追加
-- ============================================================

-- ① users テーブルに管理者フラグを追加
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;

-- ② owner_registrations: 管理者が全件閲覧できるポリシー
CREATE POLICY "admins_can_view_all_owner_registrations"
  ON public.owner_registrations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- ③ owner_registrations: 管理者が承認/却下できるポリシー
CREATE POLICY "admins_can_update_owner_registrations"
  ON public.owner_registrations FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- ④ facilities: 承認済みオーナーが自分の施設を更新できるポリシー
CREATE POLICY "approved_owners_can_update_facility"
  ON public.facilities FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.owner_registrations
      WHERE facility_id = facilities.id
        AND user_id = auth.uid()
        AND status = 'approved'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.owner_registrations
      WHERE facility_id = facilities.id
        AND user_id = auth.uid()
        AND status = 'approved'
    )
  );

-- ⑤ facilities の UPDATE 権限を authenticated ロールに付与
GRANT UPDATE ON public.facilities TO authenticated;

-- ⑥ owner_registrations の UPDATE・SELECT 権限を authenticated ロールに付与
GRANT UPDATE, SELECT ON public.owner_registrations TO authenticated;

-- ============================================================
-- 管理者ユーザーの設定方法（初回セットアップ時に手動で実行）
-- Supabase Dashboard の SQL Editor で以下を実行してください:
--
--   UPDATE public.users
--   SET is_admin = true
--   WHERE email = '管理者のメールアドレス';
--
-- ============================================================
