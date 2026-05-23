-- ============================================================
-- W2-GDPR: removal_requests に30日SLA管理を追加
-- ============================================================

ALTER TABLE removal_requests
  ADD COLUMN IF NOT EXISTS erasure_deadline TIMESTAMPTZ
    GENERATED ALWAYS AS (received_at + INTERVAL '30 days') STORED,
  ADD COLUMN IF NOT EXISTS sla_notified_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_removal_requests_deadline
  ON removal_requests (erasure_deadline)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_removal_requests_unnotified
  ON removal_requests (erasure_deadline)
  WHERE status = 'pending' AND sla_notified_at IS NULL;

COMMENT ON COLUMN removal_requests.erasure_deadline IS
  'GDPR 17条 30日SLA期限（received_at + 30日 自動計算）';
COMMENT ON COLUMN removal_requests.sla_notified_at IS
  '管理者にSLA警告通知した時刻。NULL=未通知。';
