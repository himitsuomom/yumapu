-- Wave 2: reports テーブル（コンテンツ通報）
-- app_admins テーブルが先に存在する必要がある（20260430000002 が先）

CREATE TABLE IF NOT EXISTS reports (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  target_type  TEXT NOT NULL
                 CHECK (target_type IN ('review', 'photo', 'user', 'post')),
  target_id    UUID NOT NULL,
  reason       TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending', 'resolved', 'dismissed')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at  TIMESTAMPTZ,
  resolved_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  admin_note   TEXT
);

CREATE INDEX IF NOT EXISTS idx_reports_status     ON reports (status);
CREATE INDEX IF NOT EXISTS idx_reports_target     ON reports (target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_reports_reporter   ON reports (reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports (created_at DESC);

ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- 通報者は自分の通報のみ参照可
CREATE POLICY "reports_select_own" ON reports
  FOR SELECT USING (reporter_id = auth.uid());

-- ログイン済みユーザーは通報を作成可
CREATE POLICY "reports_insert_auth" ON reports
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 管理者は全件参照・更新可
CREATE POLICY "reports_admin_all" ON reports
  FOR ALL USING (
    EXISTS (SELECT 1 FROM app_admins WHERE user_id = auth.uid())
  );
