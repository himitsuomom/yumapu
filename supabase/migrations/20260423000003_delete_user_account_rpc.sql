-- ============================================================
-- アカウント削除 RPC
-- 2026-04-23
--
-- App Store / Google Play の審査要件として、
-- ユーザーが自分のアカウントをアプリ内から削除できる機能が必須。
--
-- 動作:
--   1. auth.uid() で呼び出し元を確認（未ログインは例外）
--   2. auth.users から削除 → ON DELETE CASCADE により以下が連鎖削除される:
--      users → visits, reviews, favorites, user_badges, user_rankings,
--              onsen_plans, posts, post_likes, comments, review_likes,
--              facility_reports, owner_registrations
-- ============================================================

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
-- search_path を明示して、SECURITY DEFINER のセキュリティリスクを軽減する
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- 認証済みユーザーのIDを取得
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated'
      USING ERRCODE = 'P0001';
  END IF;

  -- auth.users から削除するだけで ON DELETE CASCADE により
  -- 全関連データ（public.users 以下のすべて）が自動削除される。
  -- photos は Storage オブジェクトのため DB 削除後に Flutter 側でも削除する。
  DELETE FROM auth.users WHERE id = v_user_id;
END;
$$;

-- 認証済みユーザーがこの関数を呼び出せるよう権限を付与
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
