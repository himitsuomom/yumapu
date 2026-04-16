-- Migration: users テーブルの INSERT ポリシー追加と SELECT ポリシー追加
--
-- 問題: 初期スキーマには users の UPDATE ポリシーのみ定義されており、
--       新規ユーザーが自分のプロフィール行を作成できなかった。
-- ============================================================

-- 自分のプロフィールのみ作成可（auth.uid() と一致する id のみ）
CREATE POLICY IF NOT EXISTS "Users can create own profile"
  ON users FOR INSERT
  WITH CHECK (auth.uid() = id);

-- 自分のプロフィールは常に参照可
-- 他のユーザーのプロフィールも読める（レビュー表示等で必要）
CREATE POLICY IF NOT EXISTS "User profiles are viewable by everyone"
  ON users FOR SELECT
  USING (true);

-- ============================================================
-- サインアップ後に users 行を自動作成するトリガー
-- ============================================================
-- Supabase の auth.users に新規ユーザーが作成されたとき、
-- public.users テーブルに対応する行を自動生成する。
-- これにより "Users can create own profile" ポリシーを
-- サーバーサイドで安全に実行できる。

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, email, created_at)
  VALUES (
    NEW.id,
    NEW.email,
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

COMMENT ON FUNCTION handle_new_user IS
  '新規 Supabase Auth ユーザー作成時に public.users 行を自動生成する';
