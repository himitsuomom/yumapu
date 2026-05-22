-- calculate-ranking を毎日 AM3:00 に実行するcronスケジュール
-- notify-sla-breach の認証をservice_role_keyからCRON_SECRETに切り替える

-- Vault にCRON_SECRETを登録する手順（CLIで手動実行が必要）:
--   supabase vault set cron_secret=<生成したランダム文字列>
--   supabase vault set calculate_ranking_url=https://<ref>.supabase.co/functions/v1/calculate-ranking

-- calculate-ranking の毎日実行スケジュール
SELECT cron.schedule(
  'calculate-ranking-daily',
  '0 3 * * *',
  $$
  SELECT net.http_post(
    url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'calculate_ranking_url'),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'cron_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);

-- notify-sla-breach の cronスケジュールを更新（CRON_SECRETを使用）
SELECT cron.unschedule('removal-sla-daily-check');

SELECT cron.schedule(
  'removal-sla-daily-check',
  '0 0 * * *',
  $$
  SELECT net.http_post(
    url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'sla_edge_function_url'),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'cron_secret')
    ),
    body := jsonb_build_object('triggered_at', NOW())
  );
  $$
);
