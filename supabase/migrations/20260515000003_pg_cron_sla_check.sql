-- ============================================================
-- pg_cron で毎日SLA期限チェック → Edge Function 呼び出し
-- ============================================================
-- 前提: pg_cron / pg_net を Supabase Dashboard の Extensions で有効化すること
-- 前提: Vault に 'sla_edge_function_url' / 'service_role_key' を登録すること
--       supabase vault set sla_edge_function_url=https://<ref>.supabase.co/functions/v1/notify-sla-breach
--       supabase vault set service_role_key=<your-service-role-key>

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION check_removal_sla_breach()
RETURNS TABLE (
  request_id UUID,
  request_type TEXT,
  days_remaining NUMERIC,
  erasure_deadline TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    id,
    request_type,
    EXTRACT(EPOCH FROM (erasure_deadline - NOW())) / 86400.0 AS days_remaining,
    erasure_deadline
  FROM removal_requests
  WHERE status = 'pending'
    AND erasure_deadline <= NOW() + INTERVAL '7 days'
    AND sla_notified_at IS NULL
  ORDER BY erasure_deadline ASC;
$$;

SELECT cron.schedule(
  'removal-sla-daily-check',
  '0 0 * * *',
  $$
  SELECT net.http_post(
    url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'sla_edge_function_url'),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
    ),
    body := jsonb_build_object('triggered_at', NOW())
  );
  $$
);

COMMENT ON FUNCTION check_removal_sla_breach IS
  'GDPR 30日SLA期限7日前の未通知リクエストを返す。Edge Functionから呼ばれる。';
