-- audit_logs: セキュリティ監査ログ（管理者のみ閲覧可能）
-- 保持期間: 90日（pg_cronで自動削除）

CREATE TABLE IF NOT EXISTS audit_logs (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  action        text        NOT NULL,         -- 'INSERT' | 'UPDATE' | 'DELETE' | 'LOGIN' | 'FUNCTION_CALL'
  table_name    text,
  record_id     text,
  old_data      jsonb,
  new_data      jsonb,
  ip_address    inet,
  user_agent    text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- 管理者のみ参照可能。直接INSERT/UPDATE/DELETEは不可（トリガー・Edge Function経由のみ）
CREATE POLICY "audit_logs_admin_select"
  ON audit_logs FOR SELECT
  USING (EXISTS (SELECT 1 FROM app_admins WHERE user_id = auth.uid()));

-- service role は全操作可能（トリガーやEdge Function用）
-- RLSはservice roleをバイパスするため明示ポリシー不要

-- インデックス（管理画面でよく使うフィルター）
CREATE INDEX IF NOT EXISTS audit_logs_user_id_idx  ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS audit_logs_created_at_idx ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS audit_logs_table_name_idx ON audit_logs(table_name) WHERE table_name IS NOT NULL;

-- 90日保持: pg_cronで毎日削除
SELECT cron.schedule(
  'audit-logs-retention-90d',
  '30 2 * * *',
  $$DELETE FROM audit_logs WHERE created_at < NOW() - INTERVAL '90 days'$$
);

-- removal_requests への変更をaudit_logsに記録するトリガー
CREATE OR REPLACE FUNCTION audit_removal_requests()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO audit_logs(action, table_name, record_id, old_data, new_data, user_id)
  VALUES (
    TG_OP,
    'removal_requests',
    COALESCE(NEW.id::text, OLD.id::text),
    CASE WHEN TG_OP != 'INSERT' THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP != 'DELETE' THEN to_jsonb(NEW) ELSE NULL END,
    auth.uid()
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_audit_removal_requests
  AFTER INSERT OR UPDATE OR DELETE ON removal_requests
  FOR EACH ROW EXECUTE FUNCTION audit_removal_requests();

-- app_admins への変更をaudit_logsに記録するトリガー
CREATE OR REPLACE FUNCTION audit_app_admins()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO audit_logs(action, table_name, record_id, old_data, new_data, user_id)
  VALUES (
    TG_OP,
    'app_admins',
    COALESCE(NEW.user_id::text, OLD.user_id::text),
    CASE WHEN TG_OP != 'INSERT' THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP != 'DELETE' THEN to_jsonb(NEW) ELSE NULL END,
    auth.uid()
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_audit_app_admins
  AFTER INSERT OR UPDATE OR DELETE ON app_admins
  FOR EACH ROW EXECUTE FUNCTION audit_app_admins();

COMMENT ON TABLE audit_logs IS 'セキュリティ監査ログ。90日保持。管理者のみ参照可能。';
