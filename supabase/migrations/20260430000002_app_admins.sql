-- Wave 2: app_admins テーブル（管理者ロール管理）
-- INSERT/UPDATE/DELETE は Supabase ダッシュボードから service_role で直接操作する

CREATE TABLE IF NOT EXISTS app_admins (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  added_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  note       TEXT
);

ALTER TABLE app_admins ENABLE ROW LEVEL SECURITY;

-- 自分がリストに入っているか確認するためのみ SELECT 可
CREATE POLICY "app_admins_select_self" ON app_admins
  FOR SELECT USING (user_id = auth.uid());

-- INSERT/UPDATE/DELETE はポリシーを設けない（service_role のみ操作可）
