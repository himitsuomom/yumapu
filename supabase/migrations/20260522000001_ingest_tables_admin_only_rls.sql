-- ingest_sources / ingest_runs / ingest_dead_letters を管理者のみに制限する
-- 従来: authenticated ユーザー全員がSELECT可能
-- 修正: app_admins に登録されたユーザーのみ全操作可能

-- ── ingest_sources ────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "ingest_sources_read" ON ingest_sources;
DROP POLICY IF EXISTS "allow_read_ingest_sources" ON ingest_sources;

CREATE POLICY "ingest_sources_admin_only"
  ON ingest_sources
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM app_admins WHERE user_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM app_admins WHERE user_id = auth.uid())
  );

-- ── ingest_runs ───────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "ingest_runs_read" ON ingest_runs;
DROP POLICY IF EXISTS "allow_read_ingest_runs" ON ingest_runs;

CREATE POLICY "ingest_runs_admin_only"
  ON ingest_runs
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM app_admins WHERE user_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM app_admins WHERE user_id = auth.uid())
  );

-- ── ingest_dead_letters ───────────────────────────────────────────────────────

DROP POLICY IF EXISTS "ingest_dead_letters_read" ON ingest_dead_letters;
DROP POLICY IF EXISTS "allow_read_ingest_dead_letters" ON ingest_dead_letters;

CREATE POLICY "ingest_dead_letters_admin_only"
  ON ingest_dead_letters
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM app_admins WHERE user_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM app_admins WHERE user_id = auth.uid())
  );
